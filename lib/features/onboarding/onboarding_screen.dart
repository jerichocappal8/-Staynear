import 'package:flutter/material.dart';
import '../auth/auth_screen.dart';
import '../../core/settings_prefs.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  final List<String> images = const [
    "assets/images/onboarding/house1.jpeg",
    "assets/images/onboarding/house2.jpeg",
    "assets/images/onboarding/house3.jpeg",
    "assets/images/onboarding/house4.jpeg",
    "assets/images/onboarding/house5.jpeg",
    "assets/images/onboarding/house6.jpeg",
    "assets/images/onboarding/house7.jpeg",
    "assets/images/onboarding/house8.jpeg",
    "assets/images/onboarding/house9.jpeg",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [

            /// IMAGE GRID AREA
            Expanded(
              flex: 6,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: images.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            images[index],
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),

                  /// FADE EFFECT
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0),
                            Colors.white,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// TEXT SECTION
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    "New Place, New Home!",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Are you ready to uproot and start over in a new area? StayNear will help you on your journey!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            /// LOGIN BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () async {

  await SettingsPrefs.setBool("seenOnboarding", true);

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AuthScreen(isLogin: true),
    ),
  );
},
                child: Container(
                  height: 55,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: [Color(0xffFF8A00), Color(0xffFFB347)],
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      "Log in",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            /// SIGN UP BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () async {

  await SettingsPrefs.setBool("seenOnboarding", true);

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AuthScreen(isLogin: false),
    ),
  );
},
                child: Container(
                  height: 55,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.orange, width: 1.4),
                  ),
                  child: const Center(
                    child: Text(
                      "Sign up",
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}