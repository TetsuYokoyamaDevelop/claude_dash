import 'dart:io';
import 'package:flutter/material.dart';
import '../models/project.dart';

class AddProjectDialog extends StatefulWidget {
  const AddProjectDialog({super.key});

  @override
  State<AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<AddProjectDialog> {
  final _nameController = TextEditingController();
  final _pathController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final path = _pathController.text.trim();

    if (name.isEmpty || path.isEmpty) {
      setState(() => _error = '名前とパスを入力してください');
      return;
    }

    if (!Directory(path).existsSync()) {
      setState(() => _error = 'ディレクトリが存在しません');
      return;
    }

    Navigator.of(context).pop(Project(name: name, path: path));
  }

  Future<void> _pickDirectory() async {
    // Use a simple approach: run `osascript` to open a folder picker
    final result = await Process.run('osascript', [
      '-e',
      'set theFolder to POSIX path of (choose folder with prompt "プロジェクトフォルダを選択")',
    ]);

    if (result.exitCode == 0) {
      final path = (result.stdout as String).trim();
      _pathController.text = path;
      if (_nameController.text.isEmpty) {
        // Auto-fill name from folder name
        _nameController.text = path.split('/').where((s) => s.isNotEmpty).last;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text(
        'プロジェクトを追加',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'プロジェクト名',
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'パス',
                      labelStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade700),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _pickDirectory,
                  icon: const Icon(Icons.folder_open, color: Colors.grey),
                  tooltip: 'フォルダを選択',
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
          ),
          child: const Text('追加'),
        ),
      ],
    );
  }
}
