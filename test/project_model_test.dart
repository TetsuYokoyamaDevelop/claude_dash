import 'package:flutter_test/flutter_test.dart';
import 'package:claude_dash/models/project.dart';

void main() {
  group('Project model', () {
    test('constructor sets name and path', () {
      final p = Project(name: 'foo', path: '/tmp/foo');
      expect(p.name, 'foo');
      expect(p.path, '/tmp/foo');
    });

    test('toJson returns correct map', () {
      final p = Project(name: 'bar', path: '/home/bar');
      final json = p.toJson();
      expect(json, {'name': 'bar', 'path': '/home/bar'});
    });

    test('fromJson constructs correctly', () {
      final p = Project.fromJson({'name': 'baz', 'path': '/opt/baz'});
      expect(p.name, 'baz');
      expect(p.path, '/opt/baz');
    });

    test('round-trip toJson -> fromJson preserves data', () {
      final original = Project(name: 'test', path: '/a/b/c');
      final restored = Project.fromJson(original.toJson());
      expect(restored.name, original.name);
      expect(restored.path, original.path);
    });

    test('fromJson handles extra fields gracefully', () {
      final p = Project.fromJson({
        'name': 'x',
        'path': '/x',
        'extra': 'ignored',
      });
      expect(p.name, 'x');
      expect(p.path, '/x');
    });
  });
}
