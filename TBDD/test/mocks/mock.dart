import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:mocktail/mocktail.dart';

// ======================================================================
// MOCK FIREBASE - PHIÊN BẢN CHUẨN CHO TEST
// ======================================================================

class MockFirebasePlatform extends Mock
    with MockPlatformInterfaceMixin
    implements FirebasePlatform {}

class MockFirebaseAppPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements FirebaseAppPlatform {}

Future<void> setupFirebaseMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockPlatform = MockFirebasePlatform();
  final mockApp = MockFirebaseAppPlatform();

  Firebase.delegatePackingProperty = mockPlatform;

  // Dạy mock cách phản hồi khi gọi initializeApp
  when(() => mockPlatform.initializeApp(
    name: any(named: 'name'),
    options: any(named: 'options'),
  )).thenAnswer((_) async => mockApp);

  // Dạy mock cách phản hồi khi gọi app() và apps
  when(() => mockPlatform.app(any())).thenAnswer((_) => mockApp);
  when(() => mockPlatform.apps).thenReturn([mockApp]);

  // 🔹🔹🔹 CHÌA KHÓA GIẢI QUYẾT LỖI CUỐI CÙNG 🔹🔹🔹
  // Dạy cho app giả cách trả về một cái tên hợp lệ
  when(() => mockApp.name).thenReturn('[DEFAULT]');
  // Dạy cho app giả cách trả về các options hợp lệ (phòng ngừa lỗi tương lai)
  when(() => mockApp.options).thenReturn(const FirebaseOptions(
    apiKey: 'mock_api_key',
    appId: 'mock_app_id',
    messagingSenderId: 'mock_sender_id',
    projectId: 'mock_project_id',
  ));
}
