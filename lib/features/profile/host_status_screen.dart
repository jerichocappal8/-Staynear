import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:staynear/core/auth_helper.dart';

class HostStatusScreen extends StatelessWidget {
  const HostStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthHelper.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Host Application Status")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('host_requests')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
  if (!snapshot.hasData) {
    return const Center(child: CircularProgressIndicator());
  }

  if (!snapshot.data!.exists) {
    return const Center(
      child: Text("No application found"),
    );
  }

  final data = snapshot.data!.data() as Map<String, dynamic>;
  final status = data['status'];

  String message;
  IconData icon;
  Color color;

  if (status == 'pending') {
    message = "Your application is under review";
    icon = Icons.hourglass_top;
    color = Colors.orange;
  } else if (status == 'approved') {
    message = "Your application is approved!";
    icon = Icons.check_circle;
    color = Colors.green;
  } else {
    message = "Your application was rejected";
    icon = Icons.cancel;
    color = Colors.red;
  }

  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 80, color: color),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(fontSize: 18),
        ),
      ],
    ),
  );
},
      ),
    );
  }
}