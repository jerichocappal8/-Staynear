import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'host_dashboard_screen.dart';
import 'host_profile_screen.dart';
import '../chat/chat_list_host_screen.dart';
import 'host_bottom_nav.dart';

class HostMainShell extends StatefulWidget {
  const HostMainShell({super.key});

  @override
  State<HostMainShell> createState() => _HostMainShellState();
}

class _HostMainShellState extends State<HostMainShell> {

  final PageController _pageController = PageController();
  int _currentIndex = 0;

  void _onNavTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),

        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },

        children: [

          /// DASHBOARD
          const HostDashboardScreen(),

          /// MESSAGES
          ChatListHostScreen(
            hostId: FirebaseAuth.instance.currentUser!.uid,
          ),

          /// PROFILE
          const HostProfileScreen(),
        ],
      ),

      bottomNavigationBar: HostBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}