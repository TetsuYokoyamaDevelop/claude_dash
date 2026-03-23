import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/project.dart';
import '../services/claude_session.dart';
import '../services/project_store.dart';
import '../widgets/add_project_dialog.dart';
import '../widgets/terminal_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _channel =
      MethodChannel('com.tetsuyokoyama.claudedash/shortcuts');
  final List<Project> _projects = [];
  final Map<String, ClaudeSession> _sessions = {};
  final Map<String, StreamSubscription> _attentionSubs = {};
  int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _channel.setMethodCallHandler(_onShortcut);
  }

  Future<dynamic> _onShortcut(MethodCall call) async {
    switch (call.method) {
      case 'selectTab':
        _selectTab(call.arguments as int);
      case 'nextTab':
        if (_projects.isNotEmpty) {
          _selectTab((_selectedIndex + 1) % _projects.length);
        }
      case 'prevTab':
        if (_projects.isNotEmpty) {
          _selectTab(
              (_selectedIndex - 1 + _projects.length) % _projects.length);
        }
      case 'newTab':
        _addProject();
      case 'closeTab':
        if (_selectedIndex >= 0 && _selectedIndex < _projects.length) {
          _removeProject(_selectedIndex);
        }
    }
  }

  Future<void> _loadProjects() async {
    final projects = await ProjectStore.load();
    setState(() {
      _projects.addAll(projects);
      if (_projects.isNotEmpty) _selectedIndex = 0;
    });
  }

  void _addProject() async {
    final project = await showDialog<Project>(
      context: context,
      builder: (_) => const AddProjectDialog(),
    );
    if (project == null) return;

    setState(() {
      _projects.add(project);
      _selectedIndex = _projects.length - 1;
    });
    await ProjectStore.save(_projects);
    await _ensureSession(project);
  }

  void _removeProject(int index) async {
    final project = _projects[index];
    final key = project.path;

    _attentionSubs[key]?.cancel();
    _attentionSubs.remove(key);
    _sessions[key]?.dispose();
    _sessions.remove(key);

    setState(() {
      _projects.removeAt(index);
      if (_selectedIndex >= _projects.length) {
        _selectedIndex = _projects.length - 1;
      }
    });
    await ProjectStore.save(_projects);
  }

  Future<ClaudeSession> _ensureSession(Project project) async {
    final key = project.path;
    if (!_sessions.containsKey(key)) {
      final session = ClaudeSession(project: project);
      _sessions[key] = session;

      _attentionSubs[key] = session.attentionStream.listen((_) {
        setState(() {});
      });

      await session.start();
    }
    return _sessions[key]!;
  }

  Future<void> _restartSession(Project project) async {
    final key = project.path;
    _sessions[key]?.dispose();
    _sessions.remove(key);
    _attentionSubs[key]?.cancel();
    _attentionSubs.remove(key);
    setState(() {});
    await _ensureSession(project);
    setState(() {});
  }

  @override
  void dispose() {
    for (final sub in _attentionSubs.values) {
      sub.cancel();
    }
    for (final session in _sessions.values) {
      session.dispose();
    }
    super.dispose();
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _projects.length) return;
    setState(() => _selectedIndex = index);
    _sessions[_projects[index].path]?.clearAttention();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(child: _buildTerminalArea()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 44,
      color: const Color(0xFF1A1A1A),
      child: Row(
        children: [
          // Project tabs
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _projects.length,
              itemBuilder: (context, index) {
                final project = _projects[index];
                final isSelected = index == _selectedIndex;
                final session = _sessions[project.path];
                final hasAttention = session?.needsAttention ?? false;

                return GestureDetector(
                  onTap: () => _selectTab(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0F0F0F)
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: hasAttention
                              ? Colors.orangeAccent
                              : isSelected
                                  ? Colors.blueAccent
                                  : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasAttention)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              color: Colors.orangeAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          project.name,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _removeProject(index),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedIndex >= 0 &&
                  _selectedIndex < _projects.length)
                IconButton(
                  onPressed: () => _restartSession(_projects[_selectedIndex]),
                  icon: const Icon(Icons.refresh, size: 18),
                  color: Colors.grey.shade500,
                  tooltip: 'セッション再起動',
                ),
              IconButton(
                onPressed: _addProject,
                icon: const Icon(Icons.add, size: 20),
                color: Colors.grey.shade500,
                tooltip: 'プロジェクトを追加',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalArea() {
    if (_projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal, size: 64, color: Colors.grey.shade700),
            const SizedBox(height: 16),
            Text(
              'プロジェクトを追加して開始',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addProject,
              icon: const Icon(Icons.add),
              label: const Text('プロジェクトを追加'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedIndex < 0 || _selectedIndex >= _projects.length) {
      return const SizedBox.shrink();
    }

    final project = _projects[_selectedIndex];
    final session = _sessions[project.path];

    if (session == null) {
      // Session not yet created, kick off creation
      _ensureSession(project).then((_) {
        if (mounted) setState(() {});
      });
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      );
    }

    return TerminalTab(
      key: ValueKey(project.path),
      session: session,
    );
  }
}
