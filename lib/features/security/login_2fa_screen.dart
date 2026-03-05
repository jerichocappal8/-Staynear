import 'package:flutter/material.dart';
import 'package:otp/otp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../home/main_shell.dart';
import '../../admin/admin_dashboard.dart';

class Login2FAScreen extends StatefulWidget {

  final String secret;

  const Login2FAScreen({super.key, required this.secret});

  @override
  State<Login2FAScreen> createState() => _Login2FAScreenState();
}

class _Login2FAScreenState extends State<Login2FAScreen> {

  final TextEditingController controller = TextEditingController();

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

    final code = controller.text.trim();

    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    List backupCodes =
        doc.data()?['twoFABackupCodes'] ?? [];

    bool validOTP = code == current || code == previous;
    bool validBackup = backupCodes.contains(code);

    if (validOTP || validBackup) {

      // Remove backup code if used
      if (validBackup) {

        backupCodes.remove(code);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({
          "twoFABackupCodes": backupCodes
        });
      }

      await goHome();

    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid code")),
      );

    }

  }

  Future<void> goHome() async {

    final uid = FirebaseAuth.instance.currentUser!.uid;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final role = userDoc.data()?['role'] ?? 'user';

    if (!mounted) return;

    if (role == 'admin') {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );

    } else {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );

    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Two-Factor Authentication"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          children: [

            const Text(
              "Enter your authentication code",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "123456 or backup code",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: verify,
              child: const Text("Verify"),
            ),

            const SizedBox(height: 10),

            const Text(
              "You can also use a backup code.",
              style: TextStyle(color: Colors.grey),
            ),

          ],
        ),
      ),
    );
  }
}