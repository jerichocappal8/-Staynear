import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:otp/otp.dart';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staynear/core/auth_helper.dart';
import 'package:staynear/core/app_colors.dart';

import 'backup_codes_page.dart';

// ─────────────────────────────────────────────
//  AppColors (inline – remove if already imported)
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────
class Verify2FAScreen extends StatefulWidget {
  final String secret;
  const Verify2FAScreen({super.key, required this.secret});

  @override
  State<Verify2FAScreen> createState() => _Verify2FAScreenState();
}

class _Verify2FAScreenState extends State<Verify2FAScreen>
    with TickerProviderStateMixin {

  // ── OTP state ────────────────────────────────
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading    = false;
  bool _isSuccess    = false;
  String? _errorText;

  // ── Animation controllers ─────────────────────
  late AnimationController _fadeSlideCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _successCtrl;
  late AnimationController _buttonPulseCtrl;

  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _shakeAnim;
  late Animation<double>   _successScale;
  late Animation<double>   _successOpacity;
  late Animation<double>   _buttonScale;

  @override
  void initState() {
    super.initState();

    // Fade + slide in
    _fadeSlideCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    );
    _fadeAnim  = CurvedAnimation(parent: _fadeSlideCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeSlideCtrl, curve: Curves.easeOut));

    // Shake
    _shakeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(_shakeCtrl);

    // Success overlay
    _successCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _successScale   = CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut)
        as Animation<double>;
    // work around type: use Tween
    _successScale   = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut));
    _successOpacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _successCtrl, curve: Curves.easeIn));

    // Button pulse while loading
    _buttonPulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _buttonScale = Tween<double>(begin: 1.0, end: 1.03)
        .animate(CurvedAnimation(parent: _buttonPulseCtrl, curve: Curves.easeInOut));

    _fadeSlideCtrl.forward();

    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _fadeSlideCtrl.dispose();
    _shakeCtrl.dispose();
    _successCtrl.dispose();
    _buttonPulseCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────
  String get _otpCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      if (digits.length >= 6) {
        _focusNodes[5].requestFocus();
        _verify();
      } else {
        final next = digits.length < 6 ? digits.length : 5;
        _focusNodes[next].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verify();
      }
    }
    setState(() => _errorText = null);
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _shakeError(String message) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _errorText = message;
      for (final c in _controllers) c.clear();
    });
    await _shakeCtrl.forward();
    _shakeCtrl.reset();
    _focusNodes[0].requestFocus();
  }

  // ── OTP Verification (original logic – untouched) ──
  List<String> generateBackupCodes() {
    final rand = Random.secure();
    return List.generate(8, (_) {
      int num = rand.nextInt(90000000) + 10000000;
      return num.toString();
    });
  }

  Future<void> _verify() async {
    if (_otpCode.length < 6 || _isLoading) return;
    setState(() { _isLoading = true; _errorText = null; });

    int now = DateTime.now().millisecondsSinceEpoch;
    String current = OTP.generateTOTPCodeString(
      widget.secret, now,
      interval: 30, algorithm: Algorithm.SHA1, isGoogle: true,
    );
    String previous = OTP.generateTOTPCodeString(
      widget.secret, now - 30000,
      interval: 30, algorithm: Algorithm.SHA1, isGoogle: true,
    );

    if (_otpCode == current || _otpCode == previous) {
      final uid = AuthHelper.uid;
      List<String> codes = generateBackupCodes();

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        "twoFAEnabled": true,
        "twoFASecret": widget.secret,
        "twoFABackupCodes": codes,
      }, SetOptions(merge: true));

      setState(() { _isSuccess = true; _isLoading = false; });
      HapticFeedback.lightImpact();
      await _successCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 900));

      if (!mounted) return;
      // Route to BackupCodesPage which loads codes from Firestore, so codes
      // remain viewable even if the user closes the app after this point.
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => const BackupCodesPage(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation, child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      setState(() => _isLoading = false);
      await _shakeError("Invalid code. Please try again.");
    }
  }

  // ── Build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: _buildAppBar(context, dark),
      body: Stack(
        children: [
          _buildBackground(dark),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _buildBody(context, dark),
              ),
            ),
          ),
          if (_isSuccess) _buildSuccessOverlay(context, dark),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool dark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: dark ? AppColors.darkCardSoft : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.3 : 0.06),
                blurRadius: 8, offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: AppColors.text(context),
          ),
        ),
      ),
      title: Text(
        "2-Step Verification",
        style: TextStyle(
          color: AppColors.text(context),
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildBackground(bool dark) {
    return Positioned(
      top: -80, right: -60,
      child: Container(
        width: 260, height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            AppColors.primaryOrange.withOpacity(dark ? 0.12 : 0.10),
            Colors.transparent,
          ]),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool dark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildIconBadge(dark),
          const SizedBox(height: 28),
          _buildHeadline(context, dark),
          const SizedBox(height: 36),
          _buildCard(context, dark),
          const SizedBox(height: 24),
          _buildVerifyButton(context, dark),
          const SizedBox(height: 20),
          _buildHelpText(context),
        ],
      ),
    );
  }

  Widget _buildIconBadge(bool dark) {
    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryOrange,
            AppColors.primaryOrange.withOpacity(0.75),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.35),
            blurRadius: 20, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.shield_rounded,
        color: Colors.white,
        size: 34,
      ),
    );
  }

  Widget _buildHeadline(BuildContext context, bool dark) {
    return Column(
      children: [
        Text(
          "Enter your code",
          style: TextStyle(
            color: AppColors.text(context),
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter the 6-digit code from\nGoogle Authenticator",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textMid,
            fontSize: 14.5,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, bool dark) {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        final offset = _shakeAnim.value > 0
            ? Offset(8 * (0.5 - (_shakeAnim.value % 0.25) * 4).abs() * (_shakeAnim.value < 0.5 ? 1 : -1), 0)
            : Offset.zero;
        return Transform.translate(offset: offset, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _errorText != null
                ? AppColors.danger.withOpacity(0.4)
                : (dark ? AppColors.darkCardSoft.withOpacity(0.6) : AppColors.border),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.25 : 0.07),
              blurRadius: 24, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildOtpRow(context, dark),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: _errorText != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.danger, size: 15),
                          const SizedBox(width: 6),
                          Text(
                            _errorText!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpRow(BuildContext context, bool dark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) => _buildOtpBox(context, dark, i)),
    );
  }

  Widget _buildOtpBox(BuildContext context, bool dark, int index) {
    return SizedBox(
      width: 46, height: 56,
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) {
          if (event is RawKeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            _onBackspace(index);
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: index == 0 ? 6 : 1,  // first box accepts paste of all 6
          autofocus: index == 0,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.text(context),
            letterSpacing: 0,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: _errorText != null
                ? AppColors.danger.withOpacity(0.06)
                : (dark
                    ? AppColors.darkCardSoft.withOpacity(0.5)
                    : AppColors.bgLight),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: dark ? AppColors.darkCardSoft : AppColors.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _errorText != null
                    ? AppColors.danger.withOpacity(0.4)
                    : (dark ? AppColors.darkCardSoft : AppColors.border),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.primaryOrange,
                width: 2,
              ),
            ),
          ),
          onChanged: (value) => _onDigitChanged(index, value),
        ),
      ),
    );
  }

  Widget _buildVerifyButton(BuildContext context, bool dark) {
    return AnimatedBuilder(
      animation: _buttonScale,
      builder: (_, child) => Transform.scale(
        scale: _isLoading ? _buttonScale.value : 1.0,
        child: child,
      ),
      child: GestureDetector(
        onTap: _isLoading ? null : _verify,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: _isLoading
                ? LinearGradient(colors: [
                    AppColors.primaryOrange.withOpacity(0.7),
                    AppColors.primaryOrange.withOpacity(0.5),
                  ])
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF5A623),
                      Color(0xFFE8920A),
                    ],
                  ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withOpacity(0.38),
                blurRadius: 20, offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white,
                    ),
                  )
                : const Text(
                    "Verify Code",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelpText(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(color: AppColors.textLight, fontSize: 13, height: 1.5),
        children: const [
          TextSpan(text: "Open "),
          TextSpan(
            text: "Google Authenticator",
            style: TextStyle(
              color: AppColors.primaryOrange,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: " and enter the\n6-digit code shown for this account."),
        ],
      ),
    );
  }

  Widget _buildSuccessOverlay(BuildContext context, bool dark) {
    return Positioned.fill(
      child: FadeTransition(
        opacity: _successOpacity,
        child: Container(
          color: AppColors.background(context).withOpacity(0.92),
          child: Center(
            child: ScaleTransition(
              scale: _successScale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF5A623), Color(0xFFE8920A)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryOrange.withOpacity(0.4),
                          blurRadius: 30, offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white, size: 44,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Verified!",
                    style: TextStyle(
                      color: AppColors.text(context),
                      fontSize: 26, fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "2FA has been enabled successfully",
                    style: TextStyle(color: AppColors.textMid, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}