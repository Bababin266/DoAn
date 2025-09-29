import 'dart:io' show Platform;
import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ExactAlarmHelper {
  static Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    final pkg = (await PackageInfo.fromPlatform()).packageName;

    if (sdk >= 31) {
      await AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        data: 'package:$pkg',
      ).launch();
    } else {
      await AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:$pkg',
      ).launch();
    }
  }
}
