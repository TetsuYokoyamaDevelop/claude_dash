import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:claude_dash/services/git_service.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('git_service_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<void> initGitRepo(String path) async {
    await Process.run('git', ['init'], workingDirectory: path);
    await Process.run('git', ['config', 'user.email', 'test@test.com'],
        workingDirectory: path);
    await Process.run('git', ['config', 'user.name', 'Test'],
        workingDirectory: path);
    File('$path/readme.txt').writeAsStringSync('hello');
    await Process.run('git', ['add', '.'], workingDirectory: path);
    await Process.run('git', ['commit', '-m', 'init'],
        workingDirectory: path);
  }

  group('GitService', () {
    test('currentBranch returns main/master for fresh repo', () async {
      await initGitRepo(tempDir.path);
      final branch = await GitService.currentBranch(tempDir.path);
      expect(branch, isNotNull);
      expect(['main', 'master'].contains(branch), true);
    });

    test('currentBranch returns null for non-git directory', () async {
      final branch = await GitService.currentBranch(tempDir.path);
      expect(branch, isNull);
    });

    test('listBranches returns at least one branch', () async {
      await initGitRepo(tempDir.path);
      final branches = await GitService.listBranches(tempDir.path);
      expect(branches, isNotEmpty);
    });

    test('listBranches returns empty for non-git directory', () async {
      final branches = await GitService.listBranches(tempDir.path);
      expect(branches, isEmpty);
    });

    test('checkout switches branch', () async {
      await initGitRepo(tempDir.path);
      await Process.run('git', ['branch', 'feature-x'],
          workingDirectory: tempDir.path);

      final ok = await GitService.checkout(tempDir.path, 'feature-x');
      expect(ok, true);

      final branch = await GitService.currentBranch(tempDir.path);
      expect(branch, 'feature-x');
    });

    test('checkout returns false for non-existent branch', () async {
      await initGitRepo(tempDir.path);
      final ok = await GitService.checkout(tempDir.path, 'does-not-exist');
      expect(ok, false);
    });

    test('listBranches includes created branch', () async {
      await initGitRepo(tempDir.path);
      await Process.run('git', ['branch', 'dev'],
          workingDirectory: tempDir.path);
      final branches = await GitService.listBranches(tempDir.path);
      expect(branches.contains('dev'), true);
    });
  });
}
