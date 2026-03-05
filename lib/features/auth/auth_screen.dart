import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../security/login_2fa_screen.dart';
import '../../services/auth_service.dart';
import '../home/main_shell.dart';
import '../../admin/admin_dashboard.dart';

class AuthScreen extends StatefulWidget {
  final bool isLogin;

  const AuthScreen({super.key, required this.isLogin});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  final auth = AuthService();

  late bool isLogin;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    isLogin = widget.isLogin;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLogin ? "Welcome Back!" : "Let’s explore together!",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isLogin
                  ? "Log in to your StayNear account."
                  : "Create your StayNear account.",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            _inputField("Email", controller: emailCtrl),
            _inputField("Password", isPassword: true, controller: passCtrl),

            if (!isLogin)
              _inputField("Phone number", controller: phoneCtrl),

            const SizedBox(height: 20),

            _mainButton(
              loading
                  ? "Please wait..."
                  : isLogin
                      ? "Log in"
                      : "Create Account",
            ),

            if (isLogin)
              TextButton(
                onPressed: _resetPassword,
                child: const Text("Forgot password?"),
              ),

            const SizedBox(height: 10),

            Row(
              children: const [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text("OR"),
                ),
                Expanded(child: Divider()),
              ],
            ),

            const SizedBox(height: 16),

            _googleButton(),

            const SizedBox(height: 20),

            Center(
              child: TextButton(
                onPressed: () {
                  setState(() => isLogin = !isLogin);
                },
                child: Text(
                  isLogin
                      ? "Create new account"
                      : "Already have an account?",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================
  // EMAIL AUTH HANDLER
  // ======================
Future<void> _handleAuth() async {
  try {
    setState(() => loading = true);

    if (isLogin) {

      final user = await auth.login(
        emailCtrl.text.trim(),
        passCtrl.text.trim(),
      );

      if (user != null) {

        final uid = FirebaseAuth.instance.currentUser!.uid;

final doc = await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .get();

bool twoFAEnabled = doc.data()?['twoFAEnabled'] ?? false;
String? secret = doc.data()?['twoFASecret'];

if (twoFAEnabled && secret != null) {

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => Login2FAScreen(secret: secret),
    ),
  );

  return;
}

        await _goHome();
      }

    } else {

      final user = await auth.register(
        emailCtrl.text.trim(),
        passCtrl.text.trim(),
        phoneCtrl.text.trim(),
      );

      if (user != null) {
        await _goHome();
      }

    }

  } catch (e) {

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.toString())));

  } finally {

    setState(() => loading = false);

  }
}

// ======================
// GOOGLE SIGN IN
// ======================
Widget _googleButton() {
  return GestureDetector(
    onTap: loading
        ? null
        : () async {
            try {
              setState(() => loading = true);

              final user = await auth.signInWithGoogle();

              if (user != null) {

                final uid = FirebaseAuth.instance.currentUser!.uid;

                final doc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get();

                bool twoFAEnabled = doc.data()?['twoFAEnabled'] ?? false;
                String? secret = doc.data()?['twoFASecret'];

                if (twoFAEnabled && secret != null) {

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Login2FAScreen(secret: secret),
                    ),
                  );

                  return;
                }

                await _goHome();
              }
            } catch (e) {

              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(e.toString())));

            } finally {

              setState(() => loading = false);

            }
          },
    child: Container(
      height: 55,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.g_mobiledata, size: 32),
          SizedBox(width: 8),
          Text("Sign in with Google"),
        ],
      ),
    ),
  );
}
  // ======================
  // ROLE BASED ROUTING
  // ======================
  Future<void> _goHome() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final role = userDoc.data()?['role'] ?? 'user';

    if (!mounted) return;

    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  // ======================
  // RESET PASSWORD
  // ======================
  Future<void> _resetPassword() async {
    if (emailCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter your email first")),
      );
      return;
    }

    try {
      await auth.resetPassword(emailCtrl.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password reset link sent to your email"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // ======================
  // INPUT FIELD
  // ======================
  Widget _inputField(
    String hint, {
    bool isPassword = false,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ======================
  // MAIN BUTTON
  // ======================
  Widget _mainButton(String text) {
    return GestureDetector(
      onTap: loading ? null : _handleAuth,
      child: Container(
        height: 55,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xffFF8A00), Color(0xffFFB347)],
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}