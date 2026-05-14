import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Shared instance — avoids stale session state between calls.
  // serverClientId (web client ID from google-services.json client_type:3) is
  // required on Android so that googleAuth.idToken is non-null.
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '578999573932-9pm11s6boh55s4pnmo1ckpcestm2ki8a.apps.googleusercontent.com',
  );

  // EMAIL REGISTER
  Future<User?> register(String email, String password, String phone, String name) async {
    final userCred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    try {
      // NOTE: "hostRequest" is intentionally omitted — Firestore rules reject
      // the value "none"; omitting it satisfies ownerUserCreateAllowed.
      await _db.collection("users").doc(userCred.user!.uid).set({
        "email":     email,
        "phone":     phone,
        "name":      name,
        "provider":  "email",
        "role":      "user",
        "isAdmin":   false,
        "isHost":    false,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Firestore write failed — roll back the Firebase Auth account so the
      // user is not left with an orphaned auth record and can retry cleanly.
      debugPrint('[Register] Firestore write failed ($e) — rolling back Firebase Auth user');
      await userCred.user!.delete();
      rethrow;
    }

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
    try {
      // Clear any stale session from a previous attempt or emulator run.
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[Google Login] User cancelled the sign-in picker.');
        return null;
      }

      final googleAuth = await googleUser.authentication;

      debugPrint('[Google Login] accessToken=${googleAuth.accessToken != null ? "present" : "NULL ⚠️"}');
      debugPrint('[Google Login] idToken=${googleAuth.idToken != null ? "present" : "NULL ⚠️"}');

      // idToken is null when SHA fingerprints are missing or OAuth client is
      // not configured in google-services.json / Firebase Console.
      if (googleAuth.idToken == null) {
        debugPrint('[Google Login] idToken is null — add SHA fingerprints in Firebase Console and re-download google-services.json.');
        throw Exception('google-id-token-null');
      }

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
        await _googleSignIn.signOut();
        throw Exception('no-account-found');
      }

      // Refresh display name / photo if the Google profile updated.
      final data = doc.data()!;
      final Map<String, dynamic> updates = {'updatedAt': FieldValue.serverTimestamp()};
      if ((data['name'] ?? '').toString().isEmpty && (user.displayName ?? '').isNotEmpty) {
        updates['name'] = user.displayName!;
      }
      if ((data['photoUrl'] ?? '').toString().isEmpty && (user.photoURL ?? '').isNotEmpty) {
        updates['photoUrl'] = user.photoURL!;
      }
      if (updates.length > 1) {
        await _db.collection('users').doc(user.uid).update(updates);
      }

      debugPrint('[Google Login] Document found for uid=${user.uid}. Proceeding.');
      return user;
    } on PlatformException catch (e, st) {
      debugPrint('[Google Login] PlatformException: code=${e.code}  message=${e.message}');
      debugPrint('[Google Login] Stack: $st');
      rethrow;
    } catch (e, st) {
      debugPrint('[Google Login] Exception (${e.runtimeType}): $e');
      debugPrint('[Google Login] Stack: $st');
      rethrow;
    }
  }

  // GOOGLE SIGNUP — signup screen only. Creates user doc for new accounts.
  Future<User?> signUpWithGoogle() async {
    try {
      // Clear any stale session from a previous attempt or emulator run.
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[Google Signup] User cancelled the sign-in picker.');
        return null;
      }

      final googleAuth = await googleUser.authentication;

      debugPrint('[Google Signup] accessToken=${googleAuth.accessToken != null ? "present" : "NULL ⚠️"}');
      debugPrint('[Google Signup] idToken=${googleAuth.idToken != null ? "present" : "NULL ⚠️"}');

      // idToken is null when SHA fingerprints are missing or OAuth client is
      // not configured in google-services.json / Firebase Console.
      if (googleAuth.idToken == null) {
        debugPrint('[Google Signup] idToken is null — add SHA fingerprints in Firebase Console and re-download google-services.json.');
        throw Exception('google-id-token-null');
      }

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
        debugPrint('[Google Signup] users/${user.uid} already exists — signing out.');
        await _auth.signOut();
        await _googleSignIn.signOut();
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
        'phone':     '',
        'photoUrl':  user.photoURL ?? '',
        'provider':  'google',
        'role':      'user',
        'isAdmin':   false,
        'isHost':    false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[Google Signup] Document created. Signing out so user logs in explicitly.');
      await _auth.signOut();
      await _googleSignIn.signOut();
      return user;
    } on PlatformException catch (e, st) {
      debugPrint('[Google Signup] PlatformException: code=${e.code}  message=${e.message}');
      debugPrint('[Google Signup] Stack: $st');
      rethrow;
    } catch (e, st) {
      debugPrint('[Google Signup] Exception (${e.runtimeType}): $e');
      debugPrint('[Google Signup] Stack: $st');
      rethrow;
    }
  }

  // RESET PASSWORD
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  User? get currentUser => _auth.currentUser;
}