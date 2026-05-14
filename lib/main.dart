import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_stripe/flutter_stripe.dart';

import 'firebase_options.dart';

import 'core/settings_prefs.dart';
import 'core/settings_controller.dart';
import 'core/location_service.dart';


import 'features/onboarding/onboarding_screen.dart';
import 'features/home/main_shell.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/auth_gate.dart';

import '../../l10n/app_localizations.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SettingsPrefs.init();
  settingsController.loadFromPrefs();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  const stripeKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
  debugPrint('[Stripe] Key present: ${stripeKey.isNotEmpty} (${stripeKey.length} chars)');
  if (stripeKey.isNotEmpty) {
    Stripe.publishableKey = stripeKey;
    await Stripe.instance.applySettings();
    debugPrint('[Stripe] Initialized successfully.');
  } else {
    debugPrint(
      '[Stripe] WARNING: STRIPE_PUBLISHABLE_KEY not set. '
      'Build with: flutter build apk --debug --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...',
    );
  }

  // ❌ REMOVE THIS
  // await LocationService.detectLocation();

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

          // ─────────────────────────────────────────
          // Localization Setup
          // ─────────────────────────────────────────
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          supportedLocales: const [
            Locale('en'),
            Locale('fil'),
          ],

          // ─────────────────────────────────────────
          // Theme
          // ─────────────────────────────────────────
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

          // ─────────────────────────────────────────
          // First screen
          // ─────────────────────────────────────────
          home: const SplashScreen(),
        );
      },
    );
  }
}