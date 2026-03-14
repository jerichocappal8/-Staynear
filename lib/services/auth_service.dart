import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // EMAIL REGISTER
  Future<User?> register(String email, String password, String phone, String name) async {
    final existingPhone = await _db
        .collection("users")
        .where("phone", isEqualTo: phone)
        .limit(1)
        .get();

    if (existingPhone.docs.isNotEmpty) {
      throw "Phone number already used";
    }

    final userCred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _db.collection("users").doc(userCred.user!.uid).set({
      "email": email,
      "phone": phone,
      "name": name,
      "provider": "email",
      "createdAt": FieldValue.serverTimestamp(),
    });

    return userCred.user;
  }

  // EMAIL LOGIN
  Future<User?> login(String email, String password) async {
    final userCred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCred.user;
  }

  // GOOGLE LOGIN
  Future<User?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);

    final user = userCred.user;

    if (user != null) {
      await _db.collection("users").doc(user.uid).set({
        "email": user.email,
        "name": user.displayName,
        "photo": user.photoURL,
        "provider": "google",
        "lastLogin": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return user;
  }
// RESET PASSWORD
Future<void> resetPassword(String email) async {

  print("Sending reset email to: $email");

  await _auth.sendPasswordResetEmail(email: email);

  print("Reset email sent.");
}

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  User? get currentUser => _auth.currentUser;
}