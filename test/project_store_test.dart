import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:claude_dash/models/project.dart';
import 'package:claude_dash/services/project_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProjectStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns empty list when no data', () async {
      final projects = await ProjectStore.load();
      expect(projects, isEmpty);
    });

    test('save then load round-trips correctly', () async {
      final projects = [
        Project(name: 'A', path: '/path/a'),
        Project(name: 'B', path: '/path/b'),
      ];
      await ProjectStore.save(projects);
      final loaded = await ProjectStore.load();
      expect(loaded.length, 2);
      expect(loaded[0].name, 'A');
      expect(loaded[0].path, '/path/a');
      expect(loaded[1].name, 'B');
      expect(loaded[1].path, '/path/b');
    });

    test('save overwrites previous data', () async {
      await ProjectStore.save([Project(name: 'Old', path: '/old')]);
      await ProjectStore.save([Project(name: 'New', path: '/new')]);
      final loaded = await ProjectStore.load();
      expect(loaded.length, 1);
      expect(loaded[0].name, 'New');
    });

    test('save empty list clears data', () async {
      await ProjectStore.save([Project(name: 'X', path: '/x')]);
      await ProjectStore.save([]);
      final loaded = await ProjectStore.load();
      expect(loaded, isEmpty);
    });

    test('handles special characters in name and path', () async {
      final projects = [
        Project(name: 'プロジェクト', path: '/tmp/日本語/パス'),
      ];
      await ProjectStore.save(projects);
      final loaded = await ProjectStore.load();
      expect(loaded[0].name, 'プロジェクト');
      expect(loaded[0].path, '/tmp/日本語/パス');
    });
  });
}
