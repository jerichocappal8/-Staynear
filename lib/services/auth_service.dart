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

  // GOOGLE LOGIN — login screen only. Blocks unregistered accounts.
  Future<User?> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      debugPrint('[Google Login] User cancelled the sign-in picker.');
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
      debugPrint('[Google Login] Firebase credential returned null user.');
      return null;
    }

    debugPrint('[Google Login] Firebase auth succeeded — uid=${user.uid}, email=${user.email}');

    final doc = await _db.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      debugPrint('[Google Login] No users/${user.uid} document — not registered. Signing out.');
      await _auth.signOut();
      await googleSignIn.signOut();
      throw Exception('no-account-found');
    }

    debugPrint('[Google Login] Document found for uid=${user.uid}. Proceeding.');
    return user;
  }

  // GOOGLE SIGNUP — signup screen only. Creates user doc for new accounts.
  Future<User?> signUpWithGoogle() async {
    final googleSignIn = GoogleSignIn();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      debugPrint('[Google Signup] User cancelled the sign-in picker.');
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
      debugPrint('[Google Signup] Firebase credential returned null user.');
      return null;
    }

    debugPrint('[Google Signup] Firebase auth succeeded — uid=${user.uid}, email=${user.email}');

    final doc = await _db.collection('users').doc(user.uid).get();

    if (doc.exists) {
      debugPrint('[Google Signup] users/${user.uid} already exists — account already registered. Signing out.');
      await _auth.signOut();
      await googleSignIn.signOut();
      throw Exception('account-already-exists');
    }

    debugPrint('[Google Signup] Creating users/${user.uid} document.');
    // Fields must satisfy ownerUserCreateAllowed:
    // - all keys must be in ownerUserCreateFields()
    // - role must be 'user', isAdmin false, isHost false
    // - hostRequest omitted (rules only allow 'pending' if present; 'none' is rejected)
    await _db.collection('users').doc(user.uid).set({
      'email':     user.email ?? '',
      'name':      user.displayName ?? '',
      'photoUrl':  user.photoURL ?? '',
      'provider':  'google',
      'role':      'user',
      'isAdmin':   false,
      'isHost':    false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[Google Signup] Document created. Signing out so user logs in explicitly.');
    await _auth.signOut();
    await googleSignIn.signOut();
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