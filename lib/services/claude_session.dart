import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform, Process, stderr;
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';
import '../models/project.dart';
import 'notification_service.dart';

void debugLog(String msg) {
  final ts = DateTime.now().toIso8601String().substring(11, 23);
  final line = '[$ts] $msg';
  stderr.writeln(line);
  developer.log(line, name: 'ClaudeDash');
}

/// Manages a single Claude CLI session for a project.
class ClaudeSession {
  final Project project;
  final Terminal terminal;
  Pty? _pty;
  bool _needsAttention = false;
  final _attentionController = StreamController<bool>.broadcast();

  /// Direct callback for attention changes — more reliable than stream alone.
  void Function(bool needsAttention)? onAttentionChanged;

  Stream<bool> get attentionStream => _attentionController.stream;
  bool get needsAttention => _needsAttention;
  bool get isRunning => _pty != null;

  // Buffer for detecting permission prompts across chunks
  String _outputBuffer = '';
  static const _bufferMaxLen = 2000;

  // Patterns that indicate Claude is asking for permission or waiting for input.
  // Sourced from Claude Code v2.1.81 cli.js.
  static final _permissionPatterns = [
    // Tool permission system
    RegExp(r'requires\s+approval', caseSensitive: false),
    RegExp(r'awaiting\s+approval', caseSensitive: false),
    // English confirmation questions (covers all variants)
    RegExp(r'Do\s+you\s+want\s+to\s+\w+', caseSensitive: false),
    RegExp(r'Would\s+you\s+like\s+to\s+\w+', caseSensitive: false),
    RegExp(r'Are\s+you\s+sure', caseSensitive: false),
    // Interactive confirmation UI
    RegExp(r'Enter\s+to\s+confirm', caseSensitive: false),
    RegExp(r'waiting\s+for\s+your\s+input', caseSensitive: false),
    // Plan mode
    RegExp(r'Enter\s+plan\s+mode\?', caseSensitive: false),
    // Legacy / generic
    RegExp(r'Allow|Deny', caseSensitive: true),
    RegExp(r'yes/no', caseSensitive: false),
    RegExp(r'\(Y/n\)|\(y/N\)|\[Y/n\]|\[y/N\]', caseSensitive: false),
    // Japanese confirmation prompts
    RegExp(r'ますか[？?]'),
    RegExp(r'ですか[？?]'),
  ];

  // Strip ALL terminal escape sequences (CSI, OSC, DCS, private modes, etc.)
  static final _ansiEscape = RegExp(
    r'\x1B\[[\x20-\x3F]*[\x40-\x7E]'  // CSI sequences (includes ?-prefixed like ESC[?2026l)
    r'|\x1B\][^\x07]*\x07'              // OSC sequences
    r'|\x1B[()][A-Z0-9]'                // Character set selection
    r'|\x1B[>=<#]'                       // Other ESC sequences
    r'|\x1B\[\?[0-9;]*[a-zA-Z]'         // Private mode set/reset
  );

  ClaudeSession({required this.project})
      : terminal = Terminal(maxLines: 10000);

  /// Find the directory containing the `claude` binary and ensure its
  /// node version is used (fixes nodebrew/nvm PATH ordering issues).
  static String? _cachedClaudeDir;
  static bool _claudeDirSearched = false;
  static Future<String?> _findClaudeDir() async {
    if (_claudeDirSearched) return _cachedClaudeDir;
    try {
      final result = await Process.run(
        '/bin/zsh',
        ['-l', '-c', 'which claude'],
      ).timeout(const Duration(seconds: 10));
      final claudePath = (result.stdout as String).trim();
      if (claudePath.isNotEmpty && claudePath.contains('/')) {
        final dir = claudePath.substring(0, claudePath.lastIndexOf('/'));
        _cachedClaudeDir = dir;
      }
    } catch (_) {
      // Timeout or error — proceed without custom PATH
    }
    _claudeDirSearched = true;
    return _cachedClaudeDir;
  }

  bool _starting = false;

  Future<void> start() async {
    if (_pty != null || _starting) return;
    _starting = true;

    try {
      await _startInternal();
    } catch (e) {
      terminal.write('\r\n[Failed to start session: $e]\r\n');
      _pty = null;
    } finally {
      _starting = false;
    }
  }

  Future<void> _startInternal() async {
    final shell = _resolveShell();
    final claudeDir = await _findClaudeDir();

    final env = Map<String, String>.from(Platform.environment);
    env['TERM'] = 'xterm-256color';
    env['LANG'] = 'en_US.UTF-8';
    env['LC_ALL'] = 'en_US.UTF-8';

    // Put claude's directory first in PATH so the correct node is used
    if (claudeDir != null) {
      final currentPath = env['PATH'] ?? '';
      env['PATH'] = '$claudeDir:$currentPath';
    }

    _pty = Pty.start(
      shell,
      arguments: ['-c', 'claude'],
      workingDirectory: project.path,
      columns: terminal.viewWidth,
      rows: terminal.viewHeight,
      environment: env,
    );

    // Use streaming UTF-8 decoder to correctly handle multi-byte characters
    // (box-drawing chars, CJK, etc.) that may be split across chunks.
    final decoder = utf8.decoder.startChunkedConversion(
      _Utf8Sink((text) {
        terminal.write(text);
        _detectPermissionPromptFromText(text);
      }),
    );

    _pty!.output.listen((data) {
      decoder.add(data);
    });

    _pty!.exitCode.then((_) {
      terminal.write('\r\n[Session ended]\r\n');
      _pty = null;
    });

    terminal.onOutput = (data) {
      _pty?.write(utf8.encode(data));
    };

    terminal.onResize = (w, h, _, __) {
      _pty?.resize(h, w);
    };
  }

  bool get isStarting => _starting;

  void _detectPermissionPromptFromText(String text) {
    _outputBuffer += text;
    if (_outputBuffer.length > _bufferMaxLen) {
      _outputBuffer =
          _outputBuffer.substring(_outputBuffer.length - _bufferMaxLen);
    }

    // Replace ANSI escape sequences with spaces (Claude Code uses cursor
    // movement ESC[1C between words, so stripping to empty joins words)
    final cleanBuffer = _outputBuffer
        .replaceAll(_ansiEscape, ' ')
        .replaceAll(RegExp(r' {2,}'), ' ');

    for (final pattern in _permissionPatterns) {
      if (pattern.hasMatch(cleanBuffer)) {
        if (!_needsAttention) {
          _needsAttention = true;
          _attentionController.add(true);
          final cb = onAttentionChanged;
          debugLog('[ATTENTION] project=${project.name} matched=${pattern.pattern} callback=${cb != null}');
          cb?.call(true);
          NotificationService.showPermissionRequest(project.name);
        }
        _outputBuffer = '';
        return;
      }
    }
  }

  void clearAttention() {
    _needsAttention = false;
    _attentionController.add(false);
    onAttentionChanged?.call(false);
  }

  void stop() {
    _pty?.kill();
    _pty = null;
  }

  void dispose() {
    stop();
    _attentionController.close();
  }

  String _resolveShell() {
    final env = String.fromEnvironment('SHELL', defaultValue: '');
    if (env.isNotEmpty) return env;
    return '/bin/zsh';
  }
}

/// Simple StringConversionSink that calls a callback for each decoded chunk.
class _Utf8Sink extends StringConversionSinkBase {
  final void Function(String) _onData;
  _Utf8Sink(this._onData);

  @override
  void addSlice(String str, int start, int end, bool isLast) {
    _onData(str.substring(start, end));
  }

  @override
  void close() {}
}
