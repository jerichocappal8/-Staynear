import 'package:flutter/material.dart';
import '../../widgets/main_bottom_nav.dart';
import '../home/home_screen.dart';
import '../home/explore_screen.dart';
import '../booking/bookings_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_list_user_screen.dart';

class UserRootScreen extends StatefulWidget {
  const UserRootScreen({super.key});

  @override
  State<UserRootScreen> createState() => _UserRootScreenState();
}

class _UserRootScreenState extends State<UserRootScreen> {

  int index = 0;

  @override
  Widget build(BuildContext context) {

    final pages = [
      const HomeScreen(),
      const ExploreScreen(),
      const ChatListUserScreen(),
      BookingsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: pages,
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: index,
        onTap: (i) {
          setState(() {
            index = i;
          });
        },
      ),
    );
  }
}