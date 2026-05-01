import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/auth_helper.dart';
import 'host_application_screen.dart';
import 'host_status_screen.dart';

class HostGateScreen extends StatelessWidget {
  const HostGateScreen({super.key});

  Future<bool> hasApplication() async {
    final uid = AuthHelper.uid;

    final doc = await FirebaseFirestore.instance
        .collection('host_requests')
        .doc(uid)
        .get();

    return doc.exists;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: hasApplication(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          return const HostStatusScreen();
        } else {
          return const HostApplicationScreen();
        }
      },
    );
  }
}
