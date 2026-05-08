import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'host_status_screen.dart';
import '../host/host_shell.dart';
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
      SlidePageRoute(page: const HostShell()),
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
            _ProfileHeader(
              name:   name,
              email:  email,
              photo:  photo,
              isDark: Theme.of(context).brightness == Brightness.dark,
            ),

            const SizedBox(height: 8),

            // ── Account ─────────────────────────────────────────────────
            _sectionLabel('Account'),
            _menu(Icons.person_outline_rounded, 'Personal details', const PersonalDetailsScreen()),
            _menu(Icons.tune_rounded,           'Settings',         const SettingsScreen()),

            // ── Support ─────────────────────────────────────────────────
            _sectionLabel('Support'),
            _menu(Icons.help_outline_rounded,   'FAQ',              const FAQScreen()),

            // ── Hosting ─────────────────────────────────────────────────
            _sectionLabel('Hosting'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Container(
                decoration: BoxDecoration(
                  color:        AppColors.card(context),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color:      Colors.black.withOpacity(
                        Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.05,
                      ),
                      blurRadius: 12,
                      offset:     const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:        AppColors.primaryOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.home_work_rounded,
                      color: AppColors.primaryOrange,
                      size:  22,
                    ),
                  ),
                  title: Text(
                    hostingText,
                    style: TextStyle(
                      color:      AppColors.text(context),
                      fontWeight: FontWeight.w600,
                      fontSize:   15,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMid),
                  onTap: _handleHosting,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Logout ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color:        AppColors.card(context),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color:      Colors.black.withOpacity(
                        Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.05,
                      ),
                      blurRadius: 12,
                      offset:     const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:        Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color:      Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize:   15,
                    ),
                  ),
                  onTap: _logout,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  Widget _menu(IconData icon, String text, Widget page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        decoration: BoxDecoration(
          color:        AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.05,
              ),
              blurRadius: 12,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        AppColors.primaryOrange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryOrange, size: 22),
          ),
          title: Text(
            text,
            style: TextStyle(
              color:      AppColors.text(context),
              fontWeight: FontWeight.w600,
              fontSize:   15,
            ),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMid),
          onTap: () => Navigator.push(context, SlidePageRoute(page: page)),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize:      11,
          fontWeight:    FontWeight.w700,
          color:         AppColors.textLight,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ─── Profile header ───────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String  name;
  final String  email;
  final dynamic photo;
  final bool    isDark;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.photo,
    required this.isDark,
  });

  static String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final hasPhoto = photo != null && photo.toString().startsWith('http');

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: isDark
              ? [AppColors.darkBackground, AppColors.darkCard]
              : [AppColors.primaryOrange, const Color(0xFFFFB347)],
        ),
      ),
      child: Column(
        children: [
          // Avatar circle
          Container(
            width:  82,
            height: 82,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  Colors.white.withOpacity(0.2),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2.5,
              ),
            ),
            child: ClipOval(
              child: hasPhoto
                  ? Image.network(
                      photo.toString(),
                      fit:          BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initialsWidget(initials),
                    )
                  : _initialsWidget(initials),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            name,
            style: const TextStyle(
              fontSize:      22,
              fontWeight:    FontWeight.w800,
              color:         Colors.white,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            email,
            style: TextStyle(
              fontSize: 13,
              color:    Colors.white.withOpacity(0.82),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _initialsWidget(String initials) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color:         Colors.white,
          fontSize:      30,
          fontWeight:    FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}