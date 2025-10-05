// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/take_medicine_screen.dart'; // ⬅️ Màn xác nhận đã uống

// Services
import 'services/auth_service.dart';
import 'services/notification_service.dart';

// ⬅️ Key để điều hướng khi bấm thông báo
final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔔 Khởi tạo notifications + truyền navigatorKey để handle click noti
  await NotificationService.instance.init(navigatorKey: _navKey);

  runApp(const MedicineApp());
}

class MedicineApp extends StatelessWidget {
  const MedicineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý thuốc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),

      // ⬅️ GẮN navigatorKey để NotificationService có thể push route
      navigatorKey: _navKey,

      // Màn hình đầu tiên
      initialRoute: AuthService().getCurrentUser() == null ? '/login' : '/home',

      // Khai báo routes
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/take': (context) => const TakeMedicineScreen(), // ⬅️ khi bấm thông báo sẽ mở route này
      },
    );
  }
}
