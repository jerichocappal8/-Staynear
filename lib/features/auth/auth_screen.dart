import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../security/login_2fa_screen.dart';
import '../../services/auth_service.dart';
import '../home/main_shell.dart';
import '../../admin/admin_dashboard.dart';
import '../../services/biometric_service.dart';
import '../../core/settings_prefs.dart';
import '../../core/app_colors.dart';

// ─── AppColors ───────────────────────────────────────────────────────────────

// ─── AuthScreen ──────────────────────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  final bool isLogin;

  const AuthScreen({super.key, required this.isLogin});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final emailCtrl = TextEditingController();
  final passCtrl  = TextEditingController();
  final phoneCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

  final auth = AuthService();

  late bool isLogin;
  bool loading       = false;
  bool obscurePass   = true;

  late final AnimationController _fadeCtrl;
late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    isLogin = widget.isLogin;

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    phoneCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Switch between login / register with fade ──────────────────────────────
  void _toggle() {
    _fadeCtrl.reset();
    setState(() => isLogin = !isLogin);
    _fadeCtrl.forward();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bg       = AppColors.background(context);
    final cardCol  = AppColors.card(context);
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // ── Hero header ───────────────────────────────────────────────
              _HeroHeader(isLogin: isLogin, isDark: isDark),

              // ── Form card ─────────────────────────────────────────────────
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardCol,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Heading
                        Text(
                          isLogin ? 'Welcome back' : "Let's get started",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text(context),
                            letterSpacing: -0.5,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          isLogin
                              ? 'Log in to continue your stay.'
                              : 'Create your free StayNear account.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textMid,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Fields ──────────────────────────────────────────
                        _AuthField(
                          hint:       'Email address',
                          controller: emailCtrl,
                          icon:       Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 14),

                        _PasswordField(
                          controller: passCtrl,
                          obscure:    obscurePass,
                          onToggle: () =>
                              setState(() => obscurePass = !obscurePass),
                        ),

                        if (!isLogin) ...[
  const SizedBox(height: 14),

  _AuthField(
    hint: 'Full name',
    controller: nameCtrl,
    icon: Icons.person_outline,
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z '\-]")),
    ],
  ),

  const SizedBox(height: 14),

  _AuthField(
    hint: 'Phone number (09XXXXXXXXX)',
    controller: phoneCtrl,
    icon: Icons.phone_outlined,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(11),
    ],
  ),
],

                        if (isLogin) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: _resetPassword,
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primaryOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),

                        // ── Primary button ──────────────────────────────────
                        _PrimaryButton(
                          loading: loading,
                          label:   isLogin ? 'Log in' : 'Create Account',
                          onTap:   loading ? null : _handleAuth,
                        ),

                        const SizedBox(height: 24),

                        // ── Divider ─────────────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: isDark
                                    ? AppColors.darkCardSoft
                                    : AppColors.border,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textLight,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: isDark
                                    ? AppColors.darkCardSoft
                                    : AppColors.border,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Google button ───────────────────────────────────
                        _GoogleButton(
                          loading: loading,
                          onTap:   loading
                              ? null
                              : (isLogin
                                  ? _handleGoogleLogin
                                  : _handleGoogleSignup),
                          isDark:  isDark,
                        ),

                        const SizedBox(height: 28),

                        // ── Toggle ──────────────────────────────────────────
                        Center(
                          child: GestureDetector(
                            onTap: loading ? null : _toggle,
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textMid,
                                ),
                                children: [
                                  TextSpan(
                                    text: isLogin
                                        ? "Don't have an account? "
                                        : 'Already have an account? ',
                                  ),
                                  TextSpan(
                                    text: isLogin ? 'Sign up' : 'Log in',
                                    style: const TextStyle(
                                      color: AppColors.primaryOrange,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /*
  =========================
  EMAIL LOGIN / REGISTER
  =========================
  */

Future<void> _handleAuth() async {
  // ── VALIDATE INPUT FIRST ──
  if (emailCtrl.text.trim().isEmpty &&
      passCtrl.text.trim().isEmpty) {
    _showError("Please enter your email and password.");
    return;
  }

  if (emailCtrl.text.trim().isEmpty) {
    _showError("Please enter your email address.");
    return;
  }

  if (passCtrl.text.trim().isEmpty) {
    _showError("Please enter your password.");
    return;
  }

  try {
    if (!mounted) return;
    setState(() => loading = true);

    if (isLogin) {
      bool biometricEnabled = SettingsPrefs.getBool(
        SettingsPrefs.kSecurityBiometric,
        defaultValue: false,
      );

      debugPrint('[Biometric] enabled=$biometricEnabled');

      if (biometricEnabled) {
        bool authenticated = await BiometricService.authenticate();
        debugPrint('[Biometric] result=$authenticated');
        // Biometric failure is non-fatal — fall through to normal login.
      }

      final loginUser = await auth.login(
        emailCtrl.text.trim(),
        passCtrl.text.trim(),
      );

      if (loginUser != null) {
        await _check2FA();
      }
    } else {
      // Validate name
      if (nameCtrl.text.trim().isEmpty) {
        _showError("Please enter your full name.");
        setState(() => loading = false);
        return;
      }
      final namePattern = RegExp(r"^[a-zA-Z '\-]+$");
      if (!namePattern.hasMatch(nameCtrl.text.trim())) {
        _showError("Name must contain letters, spaces, hyphens, or apostrophes only.");
        setState(() => loading = false);
        return;
      }
      // Validate phone
      final phone = phoneCtrl.text.trim();
      if (phone.isEmpty) {
        _showError("Please enter your phone number.");
        setState(() => loading = false);
        return;
      }
      if (!RegExp(r'^(09)\d{9}$').hasMatch(phone)) {
        _showError("Enter a valid PH phone number (09XXXXXXXXX).");
        setState(() => loading = false);
        return;
      }

      final registerUser = await auth.register(
        emailCtrl.text.trim(),
        passCtrl.text.trim(),
        phone,
        nameCtrl.text.trim(),
      );

      if (registerUser != null && mounted) {
        // Sign out so user must log in manually (issue 14)
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _showSignupSuccess();
      }
    }
  } catch (e) {
    if (!mounted) return;

    final message = _authErrorMessage(
      e,
      fallback: isLogin
          ? "Login failed. Please try again."
          : "Sign up failed. Please try again.",
    );

    print("SIGNUP/LOGIN ERROR: $e");

    _showError(message);
  } finally {
    if (mounted) setState(() => loading = false);
  }
}
  /*
  =========================
  CHECK 2FA
  =========================
  */

  Future<void> _check2FA() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('[AdminRoute] _check2FA: currentUser is null — aborting');
      return;
    }

    final uid = currentUser.uid;
    debugPrint('[AdminRoute] _check2FA: uid=$uid');

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    debugPrint('[AdminRoute] _check2FA: doc.exists=${doc.exists}');

    final data    = doc.data();
    final role    = (data?['role'] ?? 'user').toString().trim();
    final isAdmin = data?['isAdmin'] == true;
    final enabled = data?['twoFAEnabled'] as bool? ?? false;
    final secret  = data?['twoFASecret'] as String?;

    debugPrint('[AdminRoute] _check2FA: role="$role"  isAdmin=$isAdmin  twoFAEnabled=$enabled');

    if (enabled && secret != null) {
      if (!mounted) return;
      debugPrint('[AdminRoute] → Login2FAScreen (2FA required)');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Login2FAScreen(secret: secret)),
      );
      return;
    }

    // Pass already-fetched role/isAdmin so _goHome() skips a second Firestore read.
    await _goHome(cachedRole: role, cachedIsAdmin: isAdmin);
  }

  /*
  =========================
  GOOGLE SIGN IN
  =========================
  */

  // Called when on the login screen (isLogin == true).
  Future<void> _handleGoogleLogin() async {
    try {
      if (!mounted) return;
      setState(() => loading = true);

      final googleUser = await auth.signInWithGoogle();

      if (googleUser != null) {
        await _check2FA();
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('[AuthScreen] _handleGoogleLogin error (${e.runtimeType}): $e');
      final msg = e.toString();
      if (msg.contains('no-account-found')) {
        _showError('No account found for this Google email. Please create an account first.');
      } else if (msg.contains('google-id-token-null')) {
        _showError('Google sign-in is not configured correctly. Please contact support.');
      } else {
        _showError(_authErrorMessage(e, fallback: 'Google sign-in failed. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Called when on the signup screen (isLogin == false).
  Future<void> _handleGoogleSignup() async {
    try {
      if (!mounted) return;
      setState(() => loading = true);

      final googleUser = await auth.signUpWithGoogle();

      if (googleUser != null && mounted) {
        _showSignupSuccess();
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('[AuthScreen] _handleGoogleSignup error (${e.runtimeType}): $e');
      final msg = e.toString();
      if (msg.contains('account-already-exists')) {
        _showError('An account already exists for this Google email. Please log in instead.');
      } else if (msg.contains('google-id-token-null')) {
        _showError('Google sign-up is not configured correctly. Please contact support.');
      } else {
        _showError(_authErrorMessage(e, fallback: 'Google sign-up failed. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /*
  =========================
  ROLE BASED ROUTING
  =========================
  */

  Future<void> _goHome({String? cachedRole, bool? cachedIsAdmin}) async {
    String role;
    bool   isAdmin;

    if (cachedRole != null) {
      // Use data already fetched in _check2FA — no second Firestore read.
      role    = cachedRole;
      isAdmin = cachedIsAdmin ?? false;
      debugPrint('[AdminRoute] _goHome: using cached role="$role"  isAdmin=$isAdmin');
    } else {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('[AdminRoute] _goHome: currentUser is null — aborting');
        return;
      }
      final uid = currentUser.uid;
      debugPrint('[AdminRoute] _goHome: fetching users/$uid');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      debugPrint('[AdminRoute] _goHome: doc.exists=${userDoc.exists}');
      final data = userDoc.data();
      role    = (data?['role'] ?? 'user').toString().trim();
      isAdmin = data?['isAdmin'] == true;
      debugPrint('[AdminRoute] _goHome: role="$role"  isAdmin=$isAdmin');
    }

    debugPrint('[AdminRoute] _goHome: mounted=$mounted');
    if (!mounted) {
      debugPrint('[AdminRoute] _goHome: widget unmounted — navigation aborted');
      return;
    }

    final goAdmin = role == 'admin' || isAdmin;
    debugPrint('[AdminRoute] → ${goAdmin ? "AdminDashboard" : "MainShell"}');

    if (goAdmin) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  /*
  =========================
  RESET PASSWORD
  =========================
  */

  Future<void> _resetPassword() async {
    if (emailCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first')),
      );
      return;
    }

    try {
      await auth.resetPassword(emailCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password reset link sent to your email')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _authErrorMessage(
              e,
              fallback: "Could not send reset email. Please try again.",
            ),
          ),
        ),
      );
    }
  }

  String _authErrorMessage(
    Object error, {
    String fallback = "Something went wrong. Please try again.",
  }) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return "An account already exists with this email.";
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          return "Incorrect email or password.";
        case 'invalid-email':
          return "Enter a valid email address.";
        case 'user-disabled':
          return "This account has been disabled.";
        case 'too-many-requests':
          return "Too many attempts. Please try again later.";
        case 'network-request-failed':
          return "No internet connection. Please check your network.";
        case 'weak-password':
          return "Use a stronger password before signing up.";
        case 'operation-not-allowed':
          return "This sign-in method is not enabled.";
        default:
          return fallback;
      }
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return "Your account is signed in, but this action is not allowed.";
        case 'unavailable':
        case 'deadline-exceeded':
          return "Firebase is temporarily unavailable. Please try again.";
        default:
          return fallback;
      }
    }

    // PlatformException is thrown by google_sign_in on real devices.
    // code 'sign_in_failed' with ApiException: 10 = DEVELOPER_ERROR (SHA mismatch).
    if (error is PlatformException) {
      final code = error.code;
      final message = error.message ?? '';
      debugPrint('[AuthScreen] PlatformException code=$code message=$message');
      if (message.contains('ApiException: 10') || message.contains('DEVELOPER_ERROR')) {
        return "Google sign-in setup error. SHA fingerprints may be missing in Firebase.";
      }
      if (message.contains('ApiException: 7') || message.contains('NETWORK_ERROR')) {
        return "No internet connection. Please check your network.";
      }
      if (code == 'sign_in_cancelled' || message.contains('12501')) {
        return fallback;
      }
      return fallback;
    }

    return fallback;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSignupSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Account Created!',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Your account has been created successfully. Please log in to continue.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              setState(() {
                isLogin = true;
                emailCtrl.clear();
                passCtrl.clear();
                nameCtrl.clear();
                phoneCtrl.clear();
              });
            },
            child: const Text('Go to Login',
                style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

}


// ─── Hero header widget ───────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final bool isLogin;
  final bool isDark;

  const _HeroHeader({required this.isLogin, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.darkBackground, AppColors.darkCard]
              : [AppColors.primaryOrange, const Color(0xFFFFB347)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back / brand row
          Row(
            children: [
              if (Navigator.canPop(context))
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'StayNear',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Icon badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(
                isLogin ? Icons.vpn_key_rounded : Icons.home_work_rounded,
                size: 26,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 14),

          Text(
            isLogin ? 'Sign in' : 'Create account',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            isLogin
                ? 'Find your perfect stay anywhere.'
                : 'Explore unique stays around the world.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Auth text field ──────────────────────────────────────────────────────────

class _AuthField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _AuthField({
    required this.hint,
    required this.controller,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller:      controller,
      keyboardType:    keyboardType,
      inputFormatters: inputFormatters,
      style: TextStyle(
        color:    AppColors.text(context),
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),

        prefixIcon: Icon(icon, size: 20, color: AppColors.textMid),

        filled:    true,
        fillColor: isDark
            ? AppColors.darkCardSoft.withOpacity(0.5)
            : AppColors.bgLight,

        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkCardSoft : AppColors.border,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primaryOrange,
            width: 1.8,
          ),
        ),
      ),
    );
  }
}

// ─── Password field ───────────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller:  controller,
      obscureText: obscure,
      style: TextStyle(
        color:    AppColors.text(context),
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText:  'Password',
        hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),

        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 20,
          color: AppColors.textMid,
        ),

        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: AppColors.textMid,
          ),
        ),

        filled:    true,
        fillColor: isDark
            ? AppColors.darkCardSoft.withOpacity(0.5)
            : AppColors.bgLight,

        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkCardSoft : AppColors.border,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primaryOrange,
            width: 1.8,
          ),
        ),
      ),
    );
  }
}

// ─── Primary button ───────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.loading,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: loading
              ? const LinearGradient(
                  colors: [Color(0xFFDBAA5C), Color(0xFFDBAA5C)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                  colors: [
                    AppColors.primaryOrange,
                    Color(0xFFFFB347),
                  ],
                ),
          boxShadow: loading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.38),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  height: 22,
                  width:  22,
                  child:  CircularProgressIndicator(
                    color:       Colors.white,
                    strokeWidth: 2.4,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color:       Colors.white,
                    fontSize:    16,
                    fontWeight:  FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
 
  }
}

// ─── Google button ────────────────────────────────────────────────────────────

class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;
  final bool isDark;

  const _GoogleButton({
    required this.loading,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        width:  double.infinity,
        decoration: BoxDecoration(
          color:         isDark ? AppColors.darkCardSoft : Colors.white,
          borderRadius:  BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkCard : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color:      Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset:     const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google "G" logo via coloured icon (no external assets needed)
            Container(
              width:  28,
              height: 28,
              decoration: BoxDecoration(
                color:        AppColors.orangeLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'G',
                  style: TextStyle(
                    color:      AppColors.primaryOrange,
                    fontSize:   16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: TextStyle(
                fontSize:    15,
                fontWeight:  FontWeight.w600,
                color:       AppColors.text(context),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
