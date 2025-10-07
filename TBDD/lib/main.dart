// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'services/language_service.dart'; // ⬅️ THÊM

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.init(navigatorKey: _navKey);

  // ⬅️ nạp theme & ngôn ngữ đã lưu
  await ThemeService.instance.init();
  await LanguageService.instance.init();

  runApp(const MedicineApp());
}

class MedicineApp extends StatelessWidget {
  const MedicineApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe THAY ĐỔI CẢ 2: theme + ngôn ngữ
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.mode,
      builder: (_, mode, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: LanguageService.instance.isVietnamese,
          builder: (_, __isVi, ___) {
            return MaterialApp(
              title: 'Quản lý thuốc',
              debugShowCheckedModeBanner: false,
              navigatorKey: _navKey,

              // Material 3 + 2 bộ theme
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
              themeMode: mode,

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
