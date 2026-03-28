import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/animations/slide_page_route.dart';
import '../auth/auth_screen.dart';
import '../profile/personal_details_screen.dart';
import '../profile/settings_screen.dart';
import '../profile/payment_details_screen.dart';
import '../profile/faq_screen.dart';
import '../home/home_screen.dart';
import '../user/user_root_screen.dart';
import '../host/host_bottom_nav.dart';
import '../host/host_dashboard_screen.dart';
import '../chat/chat_list_host_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HostProfileScreen extends StatefulWidget {
  const HostProfileScreen({super.key});

  @override
  State<HostProfileScreen> createState() => _HostProfileScreenState();
}

class _HostProfileScreenState extends State<HostProfileScreen>
    with SingleTickerProviderStateMixin {
  // ── Entrance animation ──────────────────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ── Host data ───────────────────────────────────────────────────────────────
  Map<String, dynamic>? userData;
  bool loading = true;
  bool loggingOut = false;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
    );

    _loadUser();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────
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

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;
    setState(() {
      userData = doc.data();
      loading = false;
    });

    _entranceCtrl.forward();
  }

  // ── Logout ──────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    if (loggingOut) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: AppColors.card(context),
        title: Text(
          "Log out",
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          "Are you sure you want to log out?",
          style: TextStyle(color: AppColors.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "Cancel",
              style: TextStyle(color: AppColors.textMid),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Logout",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
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
      MaterialPageRoute(builder: (_) => const AuthScreen(isLogin: true)),
      (route) => false,
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (loading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryOrange),
        ),
      );
    }

    final name = userData?['name'] ?? "Host";
    final email = userData?['email'] ?? "";
    final photo = userData?['photo'];

    return GestureDetector(
      // ── Keep original swipe gesture ─────────────────────────────────────────
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          Navigator.pushReplacement(
            context,
            SlidePageRoute(
              page: ChatListHostScreen(
                hostId: FirebaseAuth.instance.currentUser!.uid,
              ),
            ),
          );
        }
      },

      child: Scaffold(
        backgroundColor: AppColors.background(context),

        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 28),

                  // ── Profile header ────────────────────────────────────────
                  _buildProfileHeader(context, name, email, photo, isDark),

                  const SizedBox(height: 5),

                  // ── Host badge ────────────────────────────────────────────
                  _buildHostBadge(context, isDark),

                  const SizedBox(height: 8),

                  // ── Menu items ────────────────────────────────────────────
                  _menu(
                    context,
                    Icons.person_outline_rounded,
                    "Personal Details",
                    const PersonalDetailsScreen(),
                  ),
                  _menu(
                    context,
                    Icons.settings_outlined,
                    "Settings",
                    const SettingsScreen(),
                  ),
                  _menu(
                    context,
                    Icons.help_outline_rounded,
                    "FAQ",
                    const FAQScreen(),
                  ),

                  // ── Switch to User Mode ───────────────────────────────────
                  _buildSwitchModeCard(context, isDark),

                  // ── Logout ────────────────────────────────────────────────
                  _buildLogoutCard(context, isDark),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),

        // ── Keep original bottom nav ────────────────────────────────────────
        bottomNavigationBar: HostBottomNav(
          currentIndex: 2,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                SlidePageRoute(page: const HostDashboardScreen()),
              );
            }
            if (index == 1) {
              Navigator.pushReplacement(
                context,
                SlidePageRoute(
                  page: ChatListHostScreen(
                    hostId: FirebaseAuth.instance.currentUser!.uid,
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  // ── Profile header widget ───────────────────────────────────────────────────
  Widget _buildProfileHeader(
    BuildContext context,
    String name,
    String email,
    dynamic photo,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          // Avatar with orange ring
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryOrange, Color(0xFFFFCA6C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: AppColors.primaryOrange.withOpacity(0.15),
                  child: ClipOval(
                    child: (photo != null &&
                            photo.toString().startsWith('http'))
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
              ),
              // Host verified badge
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.background(context),
                    width: 2.5,
                  ),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.text(context),
              letterSpacing: -0.3,
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
    );
  }

  // ── Host badge strip ────────────────────────────────────────────────────────
  Widget _buildHostBadge(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryOrange, Color(0xFFFFCA6C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.home_work_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Host Account",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  "You're currently in host mode",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.verified_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ── Switch to User Mode card ────────────────────────────────────────────────
  Widget _buildSwitchModeCard(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
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
              Icons.swap_horiz_rounded,
              color: AppColors.primaryOrange,
            ),
          ),
          title: Text(
            "Switch to User Mode",
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
              SlidePageRoute(page: UserRootScreen()),
            );
          },
        ),
      ),
    );
  }

  // ── Logout card ─────────────────────────────────────────────────────────────
  Widget _buildLogoutCard(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
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
            child: const Icon(Icons.logout_rounded, color: Colors.red),
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
    );
  }

  // ── Generic menu item ───────────────────────────────────────────────────────
  Widget _menu(
    BuildContext context,
    IconData icon,
    String text,
    Widget page,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
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
            child: Icon(icon, color: AppColors.primaryOrange),
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
            Navigator.push(context, SlidePageRoute(page: page));
          },
        ),
      ),
    );
  }
}