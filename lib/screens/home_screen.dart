import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/project.dart';
import '../services/claude_session.dart';
import '../services/project_store.dart';
import '../services/git_service.dart';
import '../services/settings_service.dart';
import '../widgets/add_project_dialog.dart';
import '../widgets/terminal_tab.dart';

// Re-export debugLog from claude_session
export '../services/claude_session.dart' show debugLog;

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
  final Map<String, String> _branches = {};
  int _selectedIndex = -1;
  bool _autoSwitchEnabled = true;
  Timer? _branchPollTimer;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _loadSettings();
    _channel.setMethodCallHandler(_onShortcut);
    _branchPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshBranches(),
    );
  }

  Future<void> _loadSettings() async {
    final value = await SettingsService.getAutoSwitch();
    setState(() => _autoSwitchEnabled = value);
  }

  void _toggleAutoSwitch() {
    setState(() => _autoSwitchEnabled = !_autoSwitchEnabled);
    SettingsService.setAutoSwitch(_autoSwitchEnabled);
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
    // Start sessions eagerly and fetch branches for loaded projects
    for (final project in projects) {
      _ensureSession(project);
    }
    _refreshBranches();
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

      // Direct callback — fires synchronously from the session when attention changes
      session.onAttentionChanged = (needsAttention) {
        debugLog('[CALLBACK] needsAttention=$needsAttention autoSwitch=$_autoSwitchEnabled mounted=$mounted project=${project.name} selectedIndex=$_selectedIndex');
        if (!mounted) return;
        if (needsAttention && _autoSwitchEnabled) {
          final index =
              _projects.indexWhere((p) => p.path == project.path);
          debugLog('[CALLBACK] found index=$index for ${project.name}');
          if (index >= 0 && index != _selectedIndex) {
            debugLog('[CALLBACK] switching to tab $index');
            _selectTab(index);
            return;
          }
        }
        setState(() {});
      };

      // Stream listener as fallback for UI updates (e.g. attention dot)
      _attentionSubs[key] = session.attentionStream.listen((_) {
        if (mounted) setState(() {});
      });

      await session.start();
      if (mounted) setState(() {});
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

  Future<void> _refreshBranches() async {
    bool changed = false;
    for (final project in _projects) {
      final branch = await GitService.currentBranch(project.path);
      if (branch != null && _branches[project.path] != branch) {
        _branches[project.path] = branch;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _showBranchPicker(Project project) async {
    final branches = await GitService.listBranches(project.path);
    if (branches.isEmpty || !mounted) return;
    final current = _branches[project.path];

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 300,
        44,
        0,
        0,
      ),
      color: const Color(0xFF252525),
      items: branches.map((b) {
        final isCurrent = b == current;
        return PopupMenuItem<String>(
          value: b,
          child: Row(
            children: [
              Icon(
                isCurrent ? Icons.check : Icons.circle_outlined,
                size: 14,
                color: isCurrent ? Colors.blueAccent : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                b,
                style: TextStyle(
                  color: isCurrent ? Colors.blueAccent : Colors.white,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );

    if (selected != null && selected != current) {
      final ok = await GitService.checkout(project.path, selected);
      if (ok) {
        _branches[project.path] = selected;
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _branchPollTimer?.cancel();
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
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade500,
                                fontSize: 13,
                              ),
                            ),
                            if (_branches[project.path] != null)
                              Text(
                                _branches[project.path]!,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              ),
                          ],
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
              Tooltip(
                message: _autoSwitchEnabled
                    ? '自動タブ切替: ON'
                    : '自動タブ切替: OFF',
                child: IconButton(
                  onPressed: _toggleAutoSwitch,
                  icon: Icon(
                    _autoSwitchEnabled
                        ? Icons.swap_horiz
                        : Icons.swap_horiz,
                    size: 18,
                  ),
                  color: _autoSwitchEnabled
                      ? Colors.orangeAccent
                      : Colors.grey.shade600,
                ),
              ),
              if (_selectedIndex >= 0 &&
                  _selectedIndex < _projects.length) ...[
                Tooltip(
                  message: _branches[_projects[_selectedIndex].path] ?? '',
                  child: InkWell(
                    onTap: () => _showBranchPicker(_projects[_selectedIndex]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade700),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_tree, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            _branches[_projects[_selectedIndex].path] ?? '...',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _restartSession(_projects[_selectedIndex]),
                  icon: const Icon(Icons.refresh, size: 18),
                  color: Colors.grey.shade500,
                  tooltip: 'セッション再起動',
                ),
              ],
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
      _ensureSession(project);
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      );
    }

    if (session.isStarting && !session.isRunning) {
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
