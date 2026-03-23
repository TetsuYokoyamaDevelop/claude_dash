import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:claude_dash/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getAutoSwitch defaults to true', () async {
      final value = await SettingsService.getAutoSwitch();
      expect(value, true);
    });

    test('setAutoSwitch persists false', () async {
      await SettingsService.setAutoSwitch(false);
      final value = await SettingsService.getAutoSwitch();
      expect(value, false);
    });

    test('setAutoSwitch persists true after false', () async {
      await SettingsService.setAutoSwitch(false);
      await SettingsService.setAutoSwitch(true);
      final value = await SettingsService.getAutoSwitch();
      expect(value, true);
    });
  });
}
