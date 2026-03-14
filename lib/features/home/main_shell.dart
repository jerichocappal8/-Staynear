import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'explore_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/main_bottom_nav.dart';
import '../booking/bookings_screen.dart';
import '../chat/chat_list_user_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {

  int index = 0;

final List<Widget> pages = const [
  HomeScreen(),
  ExploreScreen(),
  ChatListUserScreen(),
  BookingsScreen(),
  ProfileScreen(),
];

  void _onTabTapped(int i) {
    setState(() {
      index = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // ── Keep pages alive when switching tabs ──
      body: IndexedStack(
        index: index,
        children: pages,
      ),

      // ── Reusable bottom navigation widget ──
      bottomNavigationBar: MainBottomNav(
        currentIndex: index,
        onTap: _onTabTapped,
      ),
    );
  }
}