import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/animations/slide_page_route.dart';
import '../auth/auth_screen.dart';
import 'host_bottom_nav.dart';
import '../profile/personal_details_screen.dart';
import '../profile/settings_screen.dart';
import '../profile/payment_details_screen.dart';
import '../profile/faq_screen.dart';
import '../home/home_screen.dart';
import '../user/user_root_screen.dart';

class HostProfileScreen extends StatelessWidget {
  const HostProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),

      bottomNavigationBar: HostBottomNav(
        currentIndex: 2,
        onTap: (index) {},
      ),

      body: SafeArea(
        child: ListView(
          children: [

            const SizedBox(height: 40),

            const CircleAvatar(
              radius: 46,
              child: Icon(Icons.person, size: 40),
            ),

            const SizedBox(height: 12),

            Center(
              child: Text(
                "Host Profile",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
            ),

            const SizedBox(height: 30),

            _menu(context, Icons.person, "Personal details", const PersonalDetailsScreen()),
            _menu(context, Icons.settings, "Settings", const SettingsScreen()),
            _menu(context, Icons.credit_card, "Payment details", const PaymentDetailsScreen()),
            _menu(context, Icons.help_outline, "FAQ", const FAQScreen()),

            _menu(context, Icons.help_outline, "FAQ", const FAQScreen()),

_menu(
  context,
  Icons.swap_horiz_rounded,
  "Switch to User Mode",
    UserRootScreen(),
),
          ],
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, IconData icon, String text, Widget page) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryOrange),
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          SlidePageRoute(page: page),
        );
      },
    );
  }
}