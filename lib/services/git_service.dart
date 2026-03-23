import 'dart:io';

class GitService {
  /// Get the current branch name for a given directory.
  static Future<String?> currentBranch(String workingDirectory) async {
    try {
      final result = await Process.run(
        'git',
        ['rev-parse', '--abbrev-ref', 'HEAD'],
        workingDirectory: workingDirectory,
      ).timeout(const Duration(seconds: 5));
      final branch = (result.stdout as String).trim();
      return branch.isNotEmpty ? branch : null;
    } catch (_) {
      return null;
    }
  }

  /// List local branches for a given directory.
  static Future<List<String>> listBranches(String workingDirectory) async {
    try {
      final result = await Process.run(
        'git',
        ['branch', '--format=%(refname:short)'],
        workingDirectory: workingDirectory,
      ).timeout(const Duration(seconds: 5));
      final output = (result.stdout as String).trim();
      if (output.isEmpty) return [];
      return output.split('\n').map((b) => b.trim()).where((b) => b.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// Checkout a branch in the given directory.
  static Future<bool> checkout(String workingDirectory, String branch) async {
    try {
      final result = await Process.run(
        'git',
        ['checkout', branch],
        workingDirectory: workingDirectory,
      ).timeout(const Duration(seconds: 10));
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
