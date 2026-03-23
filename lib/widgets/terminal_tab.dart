import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import '../services/claude_session.dart';

class TerminalTab extends StatefulWidget {
  final ClaudeSession session;

  const TerminalTab({super.key, required this.session});

  @override
  State<TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<TerminalTab> {
  final _terminalController = TerminalController();

  @override
  void initState() {
    super.initState();
    if (!widget.session.isRunning) {
      widget.session.start();
    }
  }


  @override
  void dispose() {
    _terminalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TerminalView(
      widget.session.terminal,
      controller: _terminalController,
      textStyle: const TerminalStyle(
        fontSize: 13,
        fontFamily: 'Menlo',
      ),
      theme: const TerminalTheme(
        cursor: Color(0xFFE0E0E0),
        selection: Color(0x40FFFFFF),
        foreground: Color(0xFFE0E0E0),
        background: Color(0xFF0F0F0F),
        black: Color(0xFF000000),
        white: Color(0xFFE0E0E0),
        red: Color(0xFFCF6A6A),
        green: Color(0xFF6ACF6A),
        yellow: Color(0xFFCFCF6A),
        blue: Color(0xFF6A6ACF),
        magenta: Color(0xFFCF6ACF),
        cyan: Color(0xFF6ACFCF),
        brightBlack: Color(0xFF666666),
        brightRed: Color(0xFFFF8A8A),
        brightGreen: Color(0xFF8AFF8A),
        brightYellow: Color(0xFFFFFF8A),
        brightBlue: Color(0xFF8A8AFF),
        brightMagenta: Color(0xFFFF8AFF),
        brightCyan: Color(0xFF8AFFFF),
        brightWhite: Color(0xFFFFFFFF),
        searchHitBackground: Color(0xFFFFFF00),
        searchHitBackgroundCurrent: Color(0xFFFF6600),
        searchHitForeground: Color(0xFF000000),
      ),
      autofocus: true,
    );
  }
}
