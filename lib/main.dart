import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/settings_prefs.dart';
import 'core/settings_controller.dart';

import 'features/onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SettingsPrefs.init();

  settingsController.loadFromPrefs();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const StayNearApp());
}

class StayNearApp extends StatelessWidget {
  const StayNearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settingsController,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          theme: ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFFF5A623),
  scaffoldBackgroundColor: const Color(0xFFF8F7F5),
  cardColor: Colors.white,
),

darkTheme: ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFFF5A623),
  scaffoldBackgroundColor: const Color(0xFF121212),
  cardColor: const Color(0xFF1E1E1E),
),

          themeMode: settingsController.themeMode,

          home: const OnboardingScreen(),
        );
      },
    );
  }
}