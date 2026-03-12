import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'core/settings_prefs.dart';
import 'core/settings_controller.dart';
import 'core/location_service.dart';

import 'features/onboarding/onboarding_screen.dart';
import 'features/home/main_shell.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/auth_gate.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────
  // Initialize settings
  // ─────────────────────────────────────────
  await SettingsPrefs.init();
  settingsController.loadFromPrefs();

  // ─────────────────────────────────────────
  // Initialize Firebase
  // ─────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ─────────────────────────────────────────
  // Initialize Stripe
  // ─────────────────────────────────────────
  Stripe.publishableKey = "pk_test_51TA7mDEF3hIooLTXxM34PAOAsfUUukr2zuHNzvbmdnmuomGC6dPpxXTuujpWuVz23CCwhsdm982edsFr9BMyqCMc00EkZZ4hvO";
  await Stripe.instance.applySettings();

  // ─────────────────────────────────────────
  // Detect location ONCE for the entire app
  // ─────────────────────────────────────────
  await LocationService.detectLocation();

  // ─────────────────────────────────────────
  // Run app
  // ─────────────────────────────────────────
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

          home: const SplashScreen(),
        );
      },
    );
  }
}