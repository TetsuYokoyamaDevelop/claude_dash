/// Tests the tab reorder logic extracted from HomeScreen._reorderProject.
import 'package:flutter_test/flutter_test.dart';

class ReorderSimulator {
  List<String> projects;
  int selectedIndex;

  ReorderSimulator({required this.projects, required this.selectedIndex});

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final project = projects.removeAt(oldIndex);
    projects.insert(newIndex, project);

    if (selectedIndex == oldIndex) {
      selectedIndex = newIndex;
    } else if (oldIndex < selectedIndex && newIndex >= selectedIndex) {
      selectedIndex--;
    } else if (oldIndex > selectedIndex && newIndex <= selectedIndex) {
      selectedIndex++;
    }
  }
}

void main() {
  group('Tab reorder logic', () {
    test('move selected tab forward', () {
      // [A*, B, C] → move A to after C → [B, C, A*]
      final sim = ReorderSimulator(
        projects: ['A', 'B', 'C'],
        selectedIndex: 0,
      );
      sim.reorder(0, 3); // Flutter gives newIndex=3 for "after C"
      expect(sim.projects, ['B', 'C', 'A']);
      expect(sim.selectedIndex, 2); // A is now at index 2
    });

    test('move selected tab backward', () {
      // [A, B, C*] → move C to before A → [C*, A, B]
      final sim = ReorderSimulator(
        projects: ['A', 'B', 'C'],
        selectedIndex: 2,
      );
      sim.reorder(2, 0);
      expect(sim.projects, ['C', 'A', 'B']);
      expect(sim.selectedIndex, 0);
    });

    test('move non-selected tab from before selected to after', () {
      // [A, B*, C] → move A to after C → [B*, C, A]
      final sim = ReorderSimulator(
        projects: ['A', 'B', 'C'],
        selectedIndex: 1,
      );
      sim.reorder(0, 3);
      expect(sim.projects, ['B', 'C', 'A']);
      expect(sim.selectedIndex, 0); // B shifted left
    });

    test('move non-selected tab from after selected to before', () {
      // [A, B*, C] → move C to before A → [C, A, B*]
      final sim = ReorderSimulator(
        projects: ['A', 'B', 'C'],
        selectedIndex: 1,
      );
      sim.reorder(2, 0);
      expect(sim.projects, ['C', 'A', 'B']);
      expect(sim.selectedIndex, 2); // B shifted right
    });

    test('move adjacent tabs', () {
      // [A*, B] → swap → [B, A*]
      final sim = ReorderSimulator(
        projects: ['A', 'B'],
        selectedIndex: 0,
      );
      sim.reorder(0, 2);
      expect(sim.projects, ['B', 'A']);
      expect(sim.selectedIndex, 1);
    });

    test('no-op: move to same position', () {
      final sim = ReorderSimulator(
        projects: ['A', 'B', 'C'],
        selectedIndex: 1,
      );
      sim.reorder(1, 1);
      expect(sim.projects, ['A', 'B', 'C']);
      expect(sim.selectedIndex, 1);
    });

    test('four items: move middle selected to end', () {
      // [A, B*, C, D] → move B to end → [A, C, D, B*]
      final sim = ReorderSimulator(
        projects: ['A', 'B', 'C', 'D'],
        selectedIndex: 1,
      );
      sim.reorder(1, 4);
      expect(sim.projects, ['A', 'C', 'D', 'B']);
      expect(sim.selectedIndex, 3);
    });
  });
}
