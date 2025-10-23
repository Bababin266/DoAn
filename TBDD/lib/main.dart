import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/take_medicine_screen.dart';

// Services
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/language_service.dart';

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await ThemeService.instance.init();

  // ✅ Lấy locale của thiết bị để làm ngôn ngữ mặc định lần đầu
  final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
  await LanguageService.instance.init(deviceLocale: deviceLocale);

  // ✅ Khởi tạo định dạng ngày giờ theo locale hiện tại
  final initialTag = LanguageService.instance.langCode.value;
  Intl.defaultLocale = initialTag;
  await initializeDateFormatting(Intl.defaultLocale);

  // ===== Notification =====
  final plugin = FlutterLocalNotificationsPlugin();
  final launchDetails = await plugin.getNotificationAppLaunchDetails();
  await NotificationService.instance.init(navigatorKey: _navKey);

  if ((launchDetails?.didNotificationLaunchApp ?? false) &&
      launchDetails?.notificationResponse != null &&
      launchDetails!.notificationResponse!.actionId == 'mark_taken') {
    Future.delayed(const Duration(milliseconds: 500), () {
      NotificationService.instance
          .handleTapFromTerminatedState(launchDetails.notificationResponse);
    });
  }

  runApp(const MedicineApp());
}

class MedicineApp extends StatelessWidget {
  const MedicineApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.mode,
      builder: (_, mode, __) {
        // ✅ Lắng nghe thay đổi ngôn ngữ để rebuild toàn bộ MaterialApp
        return ValueListenableBuilder<String>(
          valueListenable: lang.langCode,
          builder: (_, currentCode, ___) {
            final supportedLocales = lang.supportedLocales();

            // Locale hiện tại
            final currentLocale = supportedLocales.firstWhere(
                  (l) =>
              l.toLanguageTag() == currentCode ||
                  l.languageCode == currentCode.split('-').first,
              orElse: () => const Locale('vi'),
            );

            Intl.defaultLocale = currentLocale.toLanguageTag();
            initializeDateFormatting(Intl.defaultLocale);

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              navigatorKey: _navKey,
              title: lang.tr('app.name', fallback: 'Medicine Reminder'),

              // ✅ Đa ngôn ngữ
              locale: currentLocale,
              supportedLocales: supportedLocales,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              localeListResolutionCallback: (_, __) => currentLocale,

              // Theme
              themeMode: mode,
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
                brightness: Brightness.light,
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.teal,
                  brightness: Brightness.dark,
                ),
                brightness: Brightness.dark,
              ),

              // Routes
              initialRoute:
              AuthService().getCurrentUser() == null ? '/login' : '/home',
              routes: {
                '/login': (_) => const LoginScreen(),
                '/register': (_) => const RegisterScreen(),
                '/home': (_) => const HomeScreen(),
                '/take': (_) => const TakeMedicineScreen(),
              },
            );
          },
        );
      },
    );
  }
}
