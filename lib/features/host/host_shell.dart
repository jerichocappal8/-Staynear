// host_shell.dart
// ════════════════════════════════════════════════════════════════════════════
//  HostShell — single Scaffold that owns the bottom nav and holds all
//  3 host tabs in a fade-animated Stack.
//
//  Why Stack + AnimatedOpacity instead of IndexedStack?
//  • AnimatedOpacity gives a 220 ms cross-fade between tabs.
//  • IgnorePointer prevents invisible tabs from receiving input.
//  • All 3 tabs stay in the widget tree → Firestore streams and scroll
//    positions are preserved when switching tabs.
//
//  Back-button behavior:
//  • If on tab 1 or 2, back returns to tab 0 (Dashboard).
//  • If already on tab 0, the system back gesture behaves normally.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_colors.dart';
import 'host_bottom_nav.dart';
import 'host_dashboard_screen.dart';
import '../chat/chat_list_host_screen.dart';
import 'host_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SHELL
// ─────────────────────────────────────────────────────────────────────────────

class HostShell extends StatefulWidget {
  const HostShell({super.key});

  @override
  State<HostShell> createState() => _HostShellState();
}

class _HostShellState extends State<HostShell> {
  int _index = 0;

  void _onTab(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return PopScope(
      // Allow normal pop only when on the Dashboard tab.
      // Tapping back from Chat/Profile returns to Dashboard instead.
      canPop: _index == 0,
      onPopInvoked: (didPop) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _FadeTab(isActive: _index == 0, child: const HostDashboardScreen()),
            _FadeTab(isActive: _index == 1, child: ChatListHostScreen(hostId: uid)),
            _FadeTab(isActive: _index == 2, child: const HostProfileScreen()),
          ],
        ),
        bottomNavigationBar: HostBottomNav(
          currentIndex: _index,
          onTap: _onTab,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FADE TAB  — keeps its child alive and cross-fades on visibility change
// ─────────────────────────────────────────────────────────────────────────────

class _FadeTab extends StatelessWidget {
  final bool   isActive;
  final Widget child;

  const _FadeTab({required this.isActive, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity:  isActive ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 220),
      curve:    Curves.easeOut,
      child: IgnorePointer(
        ignoring: !isActive,
        child: child,
      ),
    );
  }
}
