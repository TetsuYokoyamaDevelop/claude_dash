import 'package:flutter_test/flutter_test.dart';

void main() {
  // Same regex as claude_session.dart
  final ansiEscape = RegExp(
    r'\x1B\[[\x20-\x3F]*[\x40-\x7E]'
    r'|\x1B\][^\x07]*\x07'
    r'|\x1B[()][A-Z0-9]'
    r'|\x1B[>=<#]'
    r'|\x1B\[\?[0-9;]*[a-zA-Z]',
  );

  String clean(String input) =>
      input.replaceAll(ansiEscape, ' ').replaceAll(RegExp(r' {2,}'), ' ');

  group('ANSI escape stripping', () {
    test('strips CSI color codes', () {
      expect(clean('\x1B[32mhello\x1B[0m'), ' hello ');
    });

    test('strips cursor movement and preserves word spacing', () {
      // ESC[1C = cursor forward 1 — should become a space
      expect(clean('Do\x1B[1Cyou\x1B[1Cwant'), 'Do you want');
    });

    test('strips SGR bold/underline', () {
      expect(clean('\x1B[1m\x1B[4mbold underline\x1B[0m'), ' bold underline ');
    });

    test('strips private mode set/reset', () {
      expect(clean('\x1B[?2026lhello\x1B[?2026h'), ' hello ');
    });

    test('strips OSC sequences', () {
      expect(clean('\x1B]0;window title\x07text'), ' text');
    });

    test('strips character set selection', () {
      expect(clean('\x1B(Btext'), ' text');
    });

    test('strips cursor position ESC[row;colH', () {
      expect(clean('\x1B[10;20Hplaced'), ' placed');
    });

    test('strips 256-color and RGB sequences', () {
      expect(clean('\x1B[38;2;255;100;50mcolored\x1B[39m'), ' colored ');
    });

    test('strips background color', () {
      expect(clean('\x1B[48;2;55;55;55mtext\x1B[49m'), ' text ');
    });

    test('handles mixed ANSI + text with Japanese', () {
      expect(
        clean('\x1B[32m実行し\x1B[1Cますか？\x1B[0m'),
        ' 実行し ますか？ ',
      );
    });

    test('collapses multiple spaces after stripping', () {
      // Three escape sequences in a row → three spaces → collapsed to one
      expect(clean('\x1B[0m\x1B[0m\x1B[0mtext'), ' text');
    });

    test('passes through plain text unchanged', () {
      expect(clean('hello world'), 'hello world');
    });

    test('handles real Claude Code permission output', () {
      // Simulated raw output from Claude Code
      final raw = '\x1B[?2026h\r\x1B[2C\x1B[6A'
          'This\x1B[1Ccommand\x1B[1Crequires\x1B[1Capproval'
          '\r\n\r\nDo\x1B[1Cyou\x1B[1Cwant\x1B[1Cto\x1B[1Cproceed?';
      final cleaned = clean(raw);
      expect(cleaned.contains('requires approval'), true);
      expect(cleaned.contains('Do you want to proceed?'), true);
    });

    test('handles real Claude Code Yes/No menu', () {
      final raw = '\x1B[38;2;177;185;249m❯\x1B[1C'
          '\x1B[38;2;153;153;153m1.\x1B[1C'
          '\x1B[38;2;177;185;249mYes\x1B[39m';
      final cleaned = clean(raw);
      expect(cleaned.contains('Yes'), true);
    });
  });
}
