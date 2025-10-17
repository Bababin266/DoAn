import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? getCurrentUser() => _auth.currentUser;

  Future<User?> signIn(String email, String password) async {
    final res = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return res.user;
  }

  Future<User?> signUp(String email, String password) async {
    final res = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return res.user;
  }

  Future<void> logout() async => _auth.signOut();

  /// Gửi email khôi phục mật khẩu đến địa chỉ email được cung cấp.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
