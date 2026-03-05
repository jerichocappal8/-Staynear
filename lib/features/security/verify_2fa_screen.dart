import 'package:flutter/material.dart';
import 'package:otp/otp.dart';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'backup_codes_screen.dart';

class Verify2FAScreen extends StatefulWidget {
  final String secret;

  const Verify2FAScreen({super.key, required this.secret});

  @override
  State<Verify2FAScreen> createState() => _Verify2FAScreenState();
}

class _Verify2FAScreenState extends State<Verify2FAScreen> {

  final TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // Generate 8 backup codes
  List<String> generateBackupCodes() {
    final rand = Random.secure();

    return List.generate(8, (_) {
      int num = rand.nextInt(90000000) + 10000000;
      return num.toString();
    });
  }

  Future<void> verify() async {

    int now = DateTime.now().millisecondsSinceEpoch;

    String current = OTP.generateTOTPCodeString(
      widget.secret,
      now,
      interval: 30,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );

    String previous = OTP.generateTOTPCodeString(
      widget.secret,
      now - 30000,
      interval: 30,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );

    if (controller.text.trim() == current ||
        controller.text.trim() == previous) {

      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Generate backup codes
      List<String> codes = generateBackupCodes();

      // Save 2FA settings to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        "twoFAEnabled": true,
        "twoFASecret": widget.secret,
        "twoFABackupCodes": codes,
      }, SetOptions(merge: true));

      // Navigate to backup codes screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BackupCodesScreen(codes: codes),
        ),
      );

    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid code")),
      );

    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Verify Code")),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          children: [

            const Text(
              "Enter the code from Google Authenticator",
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "123456",
              ),
              onChanged: (value) {
                if (value.length == 6) {
                  verify();
                }
              },
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: verify,
              child: const Text("Verify"),
            ),

          ],
        ),
      ),
    );
  }
}