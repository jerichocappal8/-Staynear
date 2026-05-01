import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'host_status_screen.dart';
import '../host/host_dashboard_screen.dart';
import 'host_application_screen.dart';
import 'personal_details_screen.dart';
import 'settings_screen.dart';
import 'payment_details_screen.dart';
import 'package:staynear/core/auth_helper.dart';
import 'faq_screen.dart';
import '../../core/app_colors.dart';
import '../auth/auth_screen.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../core/animations/slide_page_route.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool loading = true;
  bool loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

Future<void> _loadUser() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    if (!mounted) return;
    setState(() {
      loading = false;
      userData = null;
    });
    return;
  }

  final uid = user.uid;

  final doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

  if (!mounted) return;

  setState(() {
    userData = doc.data();
    loading = false;
  });
}

Future<void> _logout() async {
  if (loggingOut) return;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Log out"),
      content: const Text("Are you sure you want to log out?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            "Logout",
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  setState(() => loggingOut = true);

  await FirebaseAuth.instance.signOut();

  if (!mounted) return;

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => const AuthScreen(isLogin: true),
    ),
    (route) => false,
  );
}


Future<void> _handleHosting() async {
  if (userData == null) return;

  final uid = AuthHelper.uid;

  final hostDoc = await FirebaseFirestore.instance
      .collection('host_requests')
      .doc(uid)
      .get();

  if (userData!['isHost'] == true) {
    Navigator.push(
      context,
      SlidePageRoute(page: const HostDashboardScreen()),
    );
    return;
  }

  if (hostDoc.exists) {
    Navigator.push(
      context,
      SlidePageRoute(page: const HostStatusScreen()),
    );
    return;
  }

  await Navigator.push(
    context,
    SlidePageRoute(page: const HostApplicationScreen()),
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

    final firstName = (userData?['firstName'] ?? '').toString().trim();
    final lastName  = (userData?['lastName']  ?? '').toString().trim();
    final name = (firstName.isNotEmpty || lastName.isNotEmpty)
        ? '$firstName $lastName'.trim()
        : (userData?['name'] ?? 'User').toString();
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
  backgroundColor: AppColors.background(context),


  body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 28),

Container(
  padding: const EdgeInsets.symmetric(vertical: 32),
  child: Column(
    children: [

      CircleAvatar(
        radius: 46,
        backgroundColor: AppColors.primaryOrange.withOpacity(0.15),
        child: ClipOval(
          child: (photo != null && photo.toString().startsWith('http'))
              ? Image.network(
                  photo,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                )
              : Icon(
                  Icons.person,
                  size: 42,
                  color: AppColors.primaryOrange,
                ),
        ),
      ),

      const SizedBox(height: 14),

      Text(
        name,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.text(context),
        ),
      ),

      const SizedBox(height: 4),

      Text(
        email,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textMid,
        ),
      ),

    ],
  ),
),

const SizedBox(height: 5),

_menu(Icons.person, "Personal details", const PersonalDetailsScreen()),
_menu(Icons.settings, "Settings", const SettingsScreen()),
_menu(Icons.help_outline, "FAQ", const FAQScreen()),

Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  child: Container(
decoration: BoxDecoration(
  color: AppColors.card(context),
  borderRadius: BorderRadius.circular(14),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(
        Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.05,
      ),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
  color: AppColors.primaryOrange.withOpacity(0.15),
  borderRadius: BorderRadius.circular(10),
),
        child: const Icon(
          Icons.home_work_outlined,
          color: Color(0xFFF5A623),
        ),
      ),
      title: Text(
        hostingText,
        style: TextStyle(
          color: AppColors.text(context),
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
  Icons.chevron_right_rounded,
  color: AppColors.textMid,
),
      onTap: _handleHosting,
    ),
  ),
),

Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  child: Container(
decoration: BoxDecoration(
  color: AppColors.card(context),
  borderRadius: BorderRadius.circular(14),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(
        Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.05,
      ),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.logout, color: Colors.red),
      ),
      title: const Text(
        "Logout",
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: _logout,
    ),
  ),
),
          ],
        ),
      ),
    );
  }
Widget _menu(IconData icon, String text, Widget page) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Container(
decoration: BoxDecoration(
  color: AppColors.card(context),
  borderRadius: BorderRadius.circular(14),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(
        Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.05,
      ),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFF5A623)),
        ),
        title: Text(
          text,
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
  Icons.chevron_right_rounded,
  color: AppColors.textMid,
),
        onTap: () {
          Navigator.push(
            context,
            SlidePageRoute(page: page),
          );
        },
      ),
    ),
  );
}
}