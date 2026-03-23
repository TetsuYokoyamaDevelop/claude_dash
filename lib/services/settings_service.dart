import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _autoSwitchKey = 'auto_switch_on_attention';

  static Future<bool> getAutoSwitch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSwitchKey) ?? true;
  }

  static Future<void> setAutoSwitch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSwitchKey, value);
  }
}
