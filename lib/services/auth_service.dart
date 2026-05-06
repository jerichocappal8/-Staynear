import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // EMAIL REGISTER
Future<User?> register(String email, String password, String phone, String name) async {

  final userCred = await _auth.createUserWithEmailAndPassword(

    email: email,

    password: password,

  );

  await _db.collection("users").doc(userCred.user!.uid).set({

    "email": email,

    "phone": phone,

    "name": name,

    "provider": "email",

    "role": "user",

    "isAdmin": false,

    "isHost": false,

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
    final googleSignIn = GoogleSignIn();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      debugPrint('[Google Sign-In] User cancelled the sign-in picker.');
      return null;
    }

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    final user = userCred.user;

    if (user == null) {
      debugPrint('[Google Sign-In] Firebase credential returned null user.');
      return null;
    }

    debugPrint('[Google Sign-In] Firebase auth succeeded — uid=${user.uid}, email=${user.email}');

    final doc = await _db.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      debugPrint('[Google Sign-In] No Firestore document at users/${user.uid} — account not registered. Signing out.');
      await _auth.signOut();
      await googleSignIn.signOut();
      throw Exception('no-account-found');
    }

    debugPrint('[Google Sign-In] Firestore document found for uid=${user.uid}. Login proceeding.');
    return user;
  }
// RESET PASSWORD
Future<void> resetPassword(String email) async {

  await _auth.sendPasswordResetEmail(email: email);
}

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  User? get currentUser => _auth.currentUser;
}