import 'package:firebase_auth/firebase_auth.dart';

class AuthHelper {
  static String get uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }

  static String? get uidOrNull {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  static bool get isLoggedIn {
    return FirebaseAuth.instance.currentUser != null;
  }
}