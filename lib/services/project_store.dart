import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project.dart';

class ProjectStore {
  static const _key = 'projects';

  static Future<List<Project>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => Project.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> save(List<Project> projects) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = projects.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_key, raw);
  }
}
