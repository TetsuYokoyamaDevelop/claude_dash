import 'package:local_notifier/local_notifier.dart';

class NotificationService {
  static Future<void> init() async {
    await localNotifier.setup(appName: 'Claude Dash');
  }

  static Future<void> showPermissionRequest(String projectName) async {
    final notification = LocalNotification(
      title: 'Claude Dash',
      body: '[$projectName] 許可待ちのコマンドがあります',
    );
    await notification.show();
  }
}
