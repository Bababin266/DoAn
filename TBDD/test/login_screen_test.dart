import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tbdd/main.dart'; // Import ứng dụng chính
import 'mocks/mock.dart'; // 🔹 Import mock Firebase

void main() {
  // Thiết lập môi trường Firebase giả lập 1 lần trước khi test
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('Login Screen Tests', () {
    testWidgets('Renders Login Screen UI correctly', (tester) async {
      await tester.pumpWidget(const MedicineApp());
      await tester.pumpAndSettle();

      expect(find.text('Chào mừng trở lại!'), findsOneWidget);
      expect(find.text('Đăng nhập để tiếp tục'), findsOneWidget);
      expect(find.byKey(const Key('email_field')), findsOneWidget);
      expect(find.byKey(const Key('password_field')), findsOneWidget);
      expect(find.byKey(const Key('login_button')), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
    });

    testWidgets('Shows validation errors for empty fields', (tester) async {
      await tester.pumpWidget(const MedicineApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pump();

      expect(find.text('Vui lòng nhập email'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    });

    testWidgets('Shows validation error for invalid email', (tester) async {
      await tester.pumpWidget(const MedicineApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('email_field')), 'invalid-email');
      await tester.enterText(find.byKey(const Key('password_field')), '123456');
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pump();

      expect(find.text('Email không hợp lệ'), findsOneWidget);
    });

    testWidgets('Login button shows loading indicator when pressed', (tester) async {
      await tester.pumpWidget(const MedicineApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('email_field')), 'test@example.com');
      await tester.enterText(find.byKey(const Key('password_field')), 'password123');

      await tester.tap(find.byKey(const Key('login_button')));

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final ElevatedButton button = tester.widget(find.byKey(const Key('login_button')));
      expect(button.onPressed, isNull);
    });
  });
}
