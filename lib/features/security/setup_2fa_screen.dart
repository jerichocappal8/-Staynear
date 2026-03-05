import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:base32/base32.dart';
import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'verify_2fa_screen.dart';

class Setup2FAScreen extends StatefulWidget {
  const Setup2FAScreen({super.key});

  @override
  State<Setup2FAScreen> createState() => _Setup2FAScreenState();
}

class _Setup2FAScreenState extends State<Setup2FAScreen> {

  String? secret;
  late Future<bool> _twoFAFuture;

@override
void initState() {
  super.initState();
  secret = _generateSecret();
  _twoFAFuture = check2FA();
}

  // Generate random Base32 secret
  String _generateSecret() {

    final rand = Random.secure();

    final bytes = Uint8List.fromList(
      List.generate(20, (_) => rand.nextInt(256)),
    );

    return base32.encode(bytes);
  }

  Future<bool> check2FA() async {

    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    return doc.data()?['twoFAEnabled'] ?? false;
  }

  Future<void> disable2FA() async {

    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
          "twoFAEnabled": false,
          "twoFASecret": FieldValue.delete(),
          "twoFABackupCodes": FieldValue.delete(),
        });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<bool>(
  future: _twoFAFuture,
      builder: (context, snapshot) {

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        bool enabled = snapshot.data!;

        // 2FA already enabled
        if (enabled) {

          return Scaffold(
            appBar: AppBar(title: const Text("2FA Enabled")),

            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  const Text(
                    "Two-Factor Authentication is enabled.",
                    style: TextStyle(fontSize: 16),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: disable2FA,
                    child: const Text("Disable 2FA"),
                  ),

                ],
              ),
            ),
          );
        }

        // Setup Screen


if (secret == null) {
  return const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

String uri =
    "otpauth://totp/Staynear?secret=$secret&issuer=Staynear&algorithm=SHA1&digits=6&period=30";

return Scaffold(
  appBar: AppBar(title: const Text("Setup 2FA")),

  body: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [

        const Text(
          "Scan this QR code with Google Authenticator",
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 20),

        QrImageView(
          data: uri,
          size: 220,
        ),

        const SizedBox(height: 20),

        SelectableText(
          "Manual key:\n$secret",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14),
        ),

        const SizedBox(height: 30),

        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Verify2FAScreen(secret: secret!),
              ),
            );
          },
          child: const Text("Continue"),
        ),

      ],
    ),
  ),
);
      },
    );
  }
}