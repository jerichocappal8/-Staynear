import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/settings_prefs.dart';
import '../../services/biometric_service.dart';
import '../auth/auth_screen.dart';
import '../home/main_shell.dart';
import '../../core/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {

    await Future.delayed(const Duration(milliseconds: 800));

    final user = FirebaseAuth.instance.currentUser;

    /// not logged in
    if (user == null) {
      _goToLogin();
      return;
    }

    /// check biometric setting
    final biometricEnabled =
        SettingsPrefs.getBool(SettingsPrefs.kSecurityBiometric);

    if (!biometricEnabled) {
      _goToHome();
      return;
    }

    /// authenticate
    final authenticated = await BiometricService.authenticate();

    if (authenticated) {
      _goToHome();
    } else {
      _goToLogin();
    }
  }

void _goToHome() {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const MainShell()),
  );
}

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen(isLogin: true)),
    );
  }

@override
Widget build(BuildContext context) {

  return Scaffold(
    backgroundColor: AppColors.background(context),

    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          Image.asset(
            'assets/images/logo.png',
            width: 120,
          ),

          const SizedBox(height: 20),

          Text(
            "StayNear",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ),
  );
}
}