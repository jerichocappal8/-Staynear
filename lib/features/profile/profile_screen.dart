import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'host_status_screen.dart';
import '../host/host_dashboard_screen.dart';
import 'host_application_screen.dart';
import 'personal_details_screen.dart';
import 'settings_screen.dart';
import 'payment_details_screen.dart';
import 'faq_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (!mounted) return;

    setState(() {
      userData = doc.data();
      loading = false;
    });
  }

  Future<void> _handleHosting() async {
    if (userData == null) return;

    if (userData!['isHost'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HostDashboardScreen()),
      );
      return;
    }

    if (userData!['hostRequest'] == 'pending') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HostStatusScreen()),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HostApplicationScreen()),
    );

    _loadUser();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final name = userData?['name'] ?? "User";
    final email = userData?['email'] ?? "";
    final photo = userData?['photo'];
    final isHost = userData?['isHost'] ?? false;
    final requestStatus = userData?['hostRequest'] ?? "none";

    String hostingText;

    if (isHost) {
      hostingText = "Go to Host Dashboard";
    } else if (requestStatus == "pending") {
      hostingText = "Host Request Pending";
    } else {
      hostingText = "Become a Host";
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 20),

            CircleAvatar(
  radius: 45,
  backgroundColor: Colors.grey.shade200,
  backgroundImage:
      (photo != null && photo.toString().startsWith('http'))
          ? null
          : null,
  child: ClipOval(
    child: (photo != null && photo.toString().startsWith('http'))
        ? Image.network(
            photo,
            width: 90,
            height: 90,
            fit: BoxFit.cover, // change to contain if still too zoomed
          )
        : const Icon(Icons.person, size: 40),
  ),
),

            const SizedBox(height: 12),

            Center(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 4),

            Center(
              child: Text(
                email,
                style: const TextStyle(color: Colors.grey),
              ),
            ),

            const SizedBox(height: 30),
            const Divider(),

            _menu(Icons.person, "Personal details",
                const PersonalDetailsScreen()),
            _menu(Icons.settings, "Settings", const SettingsScreen()),
            _menu(Icons.credit_card, "Payment details",
                const PaymentDetailsScreen()),
            _menu(Icons.help_outline, "FAQ", const FAQScreen()),

            const Divider(),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.swap_horiz),
              ),
              title: Text(hostingText),
              trailing: const Icon(Icons.chevron_right),
              onTap: _handleHosting,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(IconData icon, String text, Widget page) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon),
      ),
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
    );
  }
}