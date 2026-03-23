import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, Process;
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';
import '../models/project.dart';
import 'notification_service.dart';

/// Manages a single Claude CLI session for a project.
class ClaudeSession {
  final Project project;
  final Terminal terminal;
  Pty? _pty;
  bool _needsAttention = false;
  final _attentionController = StreamController<bool>.broadcast();

  Stream<bool> get attentionStream => _attentionController.stream;
  bool get needsAttention => _needsAttention;
  bool get isRunning => _pty != null;

  // Buffer for detecting permission prompts across chunks
  String _outputBuffer = '';
  static const _bufferMaxLen = 2000;

  // Patterns that indicate Claude is asking for permission
  static final _permissionPatterns = [
    RegExp(r'Allow|Deny', caseSensitive: true),
    RegExp(r'Do you want to proceed', caseSensitive: false),
    RegExp(r'yes/no', caseSensitive: false),
    RegExp(r'\(Y/n\)|\(y/N\)|\[Y/n\]|\[y/N\]', caseSensitive: false),
  ];

  ClaudeSession({required this.project})
      : terminal = Terminal(maxLines: 10000);

  /// Find the directory containing the `claude` binary and ensure its
  /// node version is used (fixes nodebrew/nvm PATH ordering issues).
  static String? _cachedClaudeDir;
  static Future<String?> _findClaudeDir() async {
    if (_cachedClaudeDir != null) return _cachedClaudeDir;
    final result = await Process.run(
      '/bin/zsh',
      ['-l', '-c', 'which claude'],
    );
    final claudePath = (result.stdout as String).trim();
    if (claudePath.isNotEmpty) {
      // e.g. /Users/x/.nodebrew/current/bin/claude → .../bin
      final dir = claudePath.substring(0, claudePath.lastIndexOf('/'));
      _cachedClaudeDir = dir;
    }
    return _cachedClaudeDir;
  }

  Future<void> start() async {
    if (_pty != null) return;

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

  void _detectPermissionPromptFromText(String text) {
    _outputBuffer += text;
    if (_outputBuffer.length > _bufferMaxLen) {
      _outputBuffer =
          _outputBuffer.substring(_outputBuffer.length - _bufferMaxLen);
    }

    for (final pattern in _permissionPatterns) {
      if (pattern.hasMatch(_outputBuffer)) {
        if (!_needsAttention) {
          _needsAttention = true;
          _attentionController.add(true);
          NotificationService.showPermissionRequest(project.name);
        }
        // Clear buffer after detection to avoid repeated triggers
        _outputBuffer = '';
        return;
      }
    }
  }

  void clearAttention() {
    _needsAttention = false;
    _attentionController.add(false);
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
