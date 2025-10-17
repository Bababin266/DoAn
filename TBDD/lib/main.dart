// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// ✅ Thêm gói localizations của Flutter
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
  // Khởi tạo Firebase, theme, language, noti
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await ThemeService.instance.init();
  await LanguageService.instance.init(); // đọc ngôn ngữ đã lưu / thiết bị

  // Chuẩn bị Dev/Date symbols cho ngôn ngữ hiện tại (nếu dùng DateFormat không kèm locale)
  await initializeDateFormatting();

  // Lấy launch details TRƯỚC khi init NotificationService
  final plugin = FlutterLocalNotificationsPlugin();
  final NotificationAppLaunchDetails? launchDetails =
  await plugin.getNotificationAppLaunchDetails();

  await NotificationService.instance.init(navigatorKey: _navKey);

  // Nếu app được mở từ thông báo
  if (launchDetails?.didNotificationLaunchApp ?? false) {
    final response = launchDetails!.notificationResponse;
    if (response?.actionId == 'mark_taken') {
      Future.delayed(const Duration(milliseconds: 500), () {
        NotificationService.instance.handleTapFromTerminatedState(response);
      });
    }
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
        // ✅ Lắng nghe thay đổi ngôn ngữ để rebuild TOÀN BỘ MaterialApp
        return ValueListenableBuilder<String>(
          valueListenable: lang.langCode, // <— quan trọng
          builder: (_, currentCode, ___) {
            // Tạo danh sách Locale hỗ trợ từ LanguageService (ví dụ: ['vi','en','ja',...])
            final supportedLocales = lang.supportedLocales();

            // Locale hiện tại tương ứng với mã đang chọn
            final currentLocale = supportedLocales.firstWhere(
                  (l) =>
              l.toLanguageTag() == currentCode ||
                  l.languageCode == currentCode,
              orElse: () => const Locale('vi'),
            );

            // Cho Intl biết locale mặc định (ảnh hưởng DateFormat khi bạn không truyền 'locale')
            Intl.defaultLocale = currentLocale.toLanguageTag();

            // Nếu bạn muốn chắc kèo cho date symbols: (an toàn, không bắt buộc)
            // await initializeDateFormatting(currentLocale.toLanguageTag());

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              navigatorKey: _navKey,
              // Dịch tiêu đề app
              title: lang.tr('app.name'),

              // ✅ Cài đặt đa ngôn ngữ cho toàn app
              locale: currentLocale,
              supportedLocales: supportedLocales,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],

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
