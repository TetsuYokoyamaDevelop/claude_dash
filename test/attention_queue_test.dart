/// Tests the attention queue logic (tab switching priority).
/// This tests the pure logic extracted from _HomeScreenState.
import 'package:flutter_test/flutter_test.dart';

/// Minimal simulation of the attention queue behavior in HomeScreen.
class AttentionQueueSimulator {
  final List<String> projects;
  final Map<String, bool> attention = {};
  int selectedIndex;
  bool autoSwitchEnabled;

  AttentionQueueSimulator({
    required this.projects,
    this.selectedIndex = 0,
    this.autoSwitchEnabled = true,
  }) {
    for (final p in projects) {
      attention[p] = false;
    }
  }

  /// Simulate a session requesting attention.
  void triggerAttention(String project) {
    attention[project] = true;
    _onAttentionChanged(project, true);
  }

  /// Simulate attention being cleared (user handled it).
  void clearAttention(String project) {
    attention[project] = false;
    _onAttentionChanged(project, false);
  }

  void _onAttentionChanged(String project, bool needsAttention) {
    if (needsAttention && autoSwitchEnabled) {
      final index = projects.indexOf(project);
      if (index >= 0 && index != selectedIndex) {
        final currentProject = projects[selectedIndex];
        if (attention[currentProject] != true) {
          _selectTab(index);
          return;
        }
      }
    } else if (!needsAttention && autoSwitchEnabled) {
      _switchToNextAttentionTab();
    }
  }

  void _selectTab(int index) {
    final prevIndex = selectedIndex;
    selectedIndex = index;
    attention[projects[index]] = false; // clearAttention

    if (prevIndex != index && autoSwitchEnabled) {
      _switchToNextAttentionTab();
    }
  }

  void _switchToNextAttentionTab() {
    final currentProject = projects[selectedIndex];
    if (attention[currentProject] == true) return;

    for (int i = 0; i < projects.length; i++) {
      if (i == selectedIndex) continue;
      if (attention[projects[i]] == true) {
        _selectTab(i);
        return;
      }
    }
  }

  void manualSelect(int index) {
    _selectTab(index);
  }
}

void main() {
  group('Attention queue logic', () {
    test('single attention triggers tab switch', () {
      final sim = AttentionQueueSimulator(
        projects: ['A', 'B', 'C'],
        selectedIndex: 0,
      );
      sim.triggerAttention('B');
      expect(sim.selectedIndex, 1);
    });

    test('does not switch to self', () {
      final sim = AttentionQueueSimulator(
        projects: ['A', 'B'],
        selectedIndex: 0,
      );
      sim.triggerAttention('A');
      expect(sim.selectedIndex, 0);
    });

    test('queued: switches to first, then second after clear', () {
      final sim = AttentionQueueSimulator(
        projects: ['A', 'B', 'C'],
        selectedIndex: 0,
      );

      // Both B and C need attention while on A
      sim.triggerAttention('B');
      // Now on B, C still needs attention
      expect(sim.selectedIndex, 1);

      sim.triggerAttention('C');
      // Already moved to B, so C is queued
      // B's attention was cleared when we switched to it
      // But C triggered while on B, so it should switch to C
      expect(sim.selectedIndex, 2);
    });

    test('does not switch when current tab also needs attention', () {
      final sim = AttentionQueueSimulator(
        projects: ['A', 'B', 'C'],
        selectedIndex: 0,
      );

      // Mark A (current) as needing attention
      sim.attention['A'] = true;
      // Now B triggers — should NOT switch because A needs attention
      sim.triggerAttention('B');
      expect(sim.selectedIndex, 0);
    });

    test('after clearing current attention, switches to queued tab', () {
      final sim = AttentionQueueSimulator(
        projects: ['A', 'B', 'C'],
        selectedIndex: 0,
      );

      // A needs attention (user is on A)
      sim.attention['A'] = true;
      // B also needs attention but can't switch
      sim.triggerAttention('B');
      expect(sim.selectedIndex, 0);

      // User handles A's prompt — clear A's attention
      sim.clearAttention('A');
      // Should now switch to B
      expect(sim.selectedIndex, 1);
    });

    test('does not switch when autoSwitch is disabled', () {
      final sim = AttentionQueueSimulator(
        projects: ['A', 'B'],
        selectedIndex: 0,
        autoSwitchEnabled: false,
      );
      sim.triggerAttention('B');
      expect(sim.selectedIndex, 0);
    });

    test('manual tab select clears attention on target', () {
      final sim = AttentionQueueSimulator(
        projects: ['A', 'B'],
        selectedIndex: 0,
      );
      sim.attention['B'] = true;
      sim.manualSelect(1);
      expect(sim.selectedIndex, 1);
      expect(sim.attention['B'], false);
    });

    test('three tabs queued: processes in order after current clears', () {
      final sim = AttentionQueueSimulator(
        projects: ['A', 'B', 'C', 'D'],
        selectedIndex: 0,
      );

      // A has attention (current tab)
      sim.attention['A'] = true;
      // B, C, D all trigger while user is handling A
      sim.triggerAttention('B');
      sim.triggerAttention('C');
      sim.triggerAttention('D');
      // Should stay on A because A needs attention
      expect(sim.selectedIndex, 0);
      // B, C, D should all still be marked
      expect(sim.attention['B'], true);
      expect(sim.attention['C'], true);
      expect(sim.attention['D'], true);

      // User handles A → clear A → should auto-switch to B (first pending)
      sim.clearAttention('A');
      // selectTab(B) clears B, then switchToNext finds C
      // selectTab(C) clears C, then switchToNext finds D
      // selectTab(D) clears D, then switchToNext finds nothing
      expect(sim.selectedIndex, 3); // Ended on D
      expect(sim.attention['B'], false);
      expect(sim.attention['C'], false);
      expect(sim.attention['D'], false);
    });
  });
}
