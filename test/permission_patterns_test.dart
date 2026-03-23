/// Tests all _permissionPatterns from claude_session.dart
/// Run with: dart test test/permission_patterns_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Exact copy of _permissionPatterns from claude_session.dart
  final permissionPatterns = [
    RegExp(r'requires\s+approval', caseSensitive: false),
    RegExp(r'awaiting\s+approval', caseSensitive: false),
    RegExp(r'Do\s+you\s+want\s+to\s+\w+', caseSensitive: false),
    RegExp(r'Would\s+you\s+like\s+to\s+\w+', caseSensitive: false),
    RegExp(r'Are\s+you\s+sure', caseSensitive: false),
    RegExp(r'Enter\s+to\s+confirm', caseSensitive: false),
    RegExp(r'waiting\s+for\s+your\s+input', caseSensitive: false),
    RegExp(r'Enter\s+plan\s+mode\?', caseSensitive: false),
    RegExp(r'Allow|Deny', caseSensitive: true),
    RegExp(r'yes/no', caseSensitive: false),
    RegExp(r'\(Y/n\)|\(y/N\)|\[Y/n\]|\[y/N\]', caseSensitive: false),
    RegExp(r'ますか[？?]'),
    RegExp(r'ですか[？?]'),
  ];

  // ANSI escape stripper (same as claude_session.dart)
  final ansiEscape = RegExp(
    r'\x1B\[[\x20-\x3F]*[\x40-\x7E]'
    r'|\x1B\][^\x07]*\x07'
    r'|\x1B[()][A-Z0-9]'
    r'|\x1B[>=<#]'
    r'|\x1B\[\?[0-9;]*[a-zA-Z]',
  );

  String clean(String input) =>
      input.replaceAll(ansiEscape, ' ').replaceAll(RegExp(r' {2,}'), ' ');

  bool matchesAny(String text) {
    final cleaned = clean(text);
    for (final p in permissionPatterns) {
      if (p.hasMatch(cleaned)) return true;
    }
    return false;
  }

  int matchedIndex(String text) {
    final cleaned = clean(text);
    for (int i = 0; i < permissionPatterns.length; i++) {
      if (permissionPatterns[i].hasMatch(cleaned)) return i;
    }
    return -1;
  }

  group('Pattern 0: requires approval', () {
    test('basic', () => expect(matchesAny('This action requires approval'), true));
    test('multiword spacing', () => expect(matchesAny('requires  approval'), true));
    test('case insensitive', () => expect(matchesAny('Requires Approval'), true));
    test('no match with word in between', () => expect(matchesAny('requires no approval'), false));
  });

  group('Pattern 1: awaiting approval', () {
    test('basic', () => expect(matchesAny('Tool is awaiting approval'), true));
    test('case insensitive', () => expect(matchesAny('AWAITING APPROVAL'), true));
  });

  group('Pattern 2: Do you want to ...', () {
    test('proceed', () => expect(matchesAny('Do you want to proceed?'), true));
    test('continue', () => expect(matchesAny('Do you want to continue?'), true));
    test('allow', () => expect(matchesAny('Do you want to allow this?'), true));
    test('delete', () => expect(matchesAny('Do you want to delete this file?'), true));
    test('with ANSI', () {
      expect(matchesAny('Do\x1B[1C you\x1B[1C want\x1B[1C to\x1B[1C proceed'), true);
    });
  });

  group('Pattern 3: Would you like to ...', () {
    test('proceed', () => expect(matchesAny('Would you like to proceed?'), true));
    test('continue', () => expect(matchesAny('Would you like to continue?'), true));
    test('review', () => expect(matchesAny('Would you like to review the changes?'), true));
  });

  group('Pattern 4: Are you sure', () {
    test('basic', () => expect(matchesAny('Are you sure?'), true));
    test('with context', () => expect(matchesAny('Are you sure you want to delete?'), true));
    test('case insensitive', () => expect(matchesAny('are you sure'), true));
  });

  group('Pattern 5: Enter to confirm', () {
    test('basic', () => expect(matchesAny('Press Enter to confirm'), true));
    test('standalone', () => expect(matchesAny('Enter to confirm'), true));
  });

  group('Pattern 6: waiting for your input', () {
    test('basic', () => expect(matchesAny('Claude is waiting for your input'), true));
    test('case insensitive', () => expect(matchesAny('Waiting For Your Input'), true));
  });

  group('Pattern 7: Enter plan mode?', () {
    test('basic', () => expect(matchesAny('Enter plan mode?'), true));
    test('case insensitive', () => expect(matchesAny('enter plan mode?'), true));
  });

  group('Pattern 8: Allow|Deny', () {
    test('Allow', () => expect(matchesAny('Allow'), true));
    test('Deny', () => expect(matchesAny('Deny'), true));
    test('in context', () => expect(matchesAny('[Allow] [Deny]'), true));
    test('case sensitive - lowercase fails', () {
      // 'allow' alone should NOT match (case-sensitive)
      final idx = matchedIndex('allow this');
      // It should not match pattern 8 specifically
      expect(idx != 8, true);
    });
  });

  group('Pattern 9: yes/no', () {
    test('basic', () => expect(matchesAny('yes/no'), true));
    test('in context', () => expect(matchesAny('Please select (yes/no):'), true));
    test('case insensitive', () => expect(matchesAny('Yes/No'), true));
  });

  group('Pattern 10: (Y/n) variants', () {
    test('(Y/n)', () => expect(matchesAny('Continue? (Y/n)'), true));
    test('(y/N)', () => expect(matchesAny('Continue? (y/N)'), true));
    test('[Y/n]', () => expect(matchesAny('Continue? [Y/n]'), true));
    test('[y/N]', () => expect(matchesAny('Continue? [y/N]'), true));
  });

  group('Pattern 11: ますか？', () {
    test('full-width ?', () => expect(matchesAny('実行しますか？'), true));
    test('half-width ?', () => expect(matchesAny('実行しますか?'), true));
    test('続けますか', () => expect(matchesAny('処理を続けますか？'), true));
    test('許可しますか', () => expect(matchesAny('このファイルを編集しますか？'), true));
  });

  group('Pattern 12: ですか？', () {
    test('full-width ?', () => expect(matchesAny('よろしいですか？'), true));
    test('half-width ?', () => expect(matchesAny('よろしいですか?'), true));
    test('in context', () => expect(matchesAny('この変更でよろしいですか？'), true));
  });

  group('Negative cases (should NOT match)', () {
    test('normal output', () => expect(matchesAny('Building project...'), false));
    test('code output', () => expect(matchesAny('const x = 42;'), false));
    test('file path', () => expect(matchesAny('/Users/foo/bar/main.dart'), false));
    test('git log', () => expect(matchesAny('commit abc123 fix: update readme'), false));
    test('partial match without keyword', () => expect(matchesAny('The process completed successfully'), false));
  });

  group('ANSI escape stripping', () {
    test('CSI sequence', () {
      final input = '\x1B[32mDo you want to proceed?\x1B[0m';
      expect(matchesAny(input), true);
    });
    test('OSC sequence', () {
      final input = '\x1B]0;title\x07Are you sure?';
      expect(matchesAny(input), true);
    });
    test('Private mode', () {
      final input = '\x1B[?2026lAllow';
      expect(matchesAny(input), true);
    });
    test('Multiple escapes between words', () {
      final input = 'Do\x1B[1Cyou\x1B[1Cwant\x1B[1Cto\x1B[1Cproceed';
      expect(matchesAny(input), true);
    });
  });
}
