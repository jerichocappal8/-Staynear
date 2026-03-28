import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:otp/otp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:staynear/core/auth_helper.dart';
import 'package:staynear/core/app_colors.dart';

import '../home/main_shell.dart';
import '../../admin/admin_dashboard.dart';

class Login2FAScreen extends StatefulWidget {
  final String secret;
  const Login2FAScreen({super.key, required this.secret});

  @override
  State<Login2FAScreen> createState() => _Login2FAScreenState();
}

class _Login2FAScreenState extends State<Login2FAScreen>
    with TickerProviderStateMixin {
  final TextEditingController controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _loading = false;
  bool _useBackup = false;

  // Six individual OTP digit controllers + focus nodes
  final List<TextEditingController> _digitCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _digitFocus = List.generate(6, (_) => FocusNode());

  // Animations
  late AnimationController _pageCtrl;
  late AnimationController _btnCtrl;
  late AnimationController _shakeCtrl;

  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _btnScale;
  late Animation<double> _shakeFade;
  late Animation<Offset> _shakeOffset;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _focusNode.addListener(() => setState(() {}));
    for (final f in _digitFocus) {
      f.addListener(() => setState(() {}));
    }
    controller.addListener(() => setState(() {}));
  }

  void _initAnimations() {
    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _pageCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageCtrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    ));
    _cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _pageCtrl,
        curve: const Interval(0.3, 0.85, curve: Curves.easeOut),
      ),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageCtrl,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
    ));
    _btnScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut),
    );
    _shakeFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _shakeCtrl,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _shakeOffset = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: const Offset(-0.03, 0)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(
              begin: const Offset(-0.03, 0), end: const Offset(0.03, 0)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(
              begin: const Offset(0.03, 0), end: const Offset(-0.02, 0)),
          weight: 2),
      TweenSequenceItem(
          tween:
              Tween(begin: const Offset(-0.02, 0), end: Offset.zero),
          weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeCtrl,
      curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageCtrl.forward();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    _focusNode.dispose();
    for (final c in _digitCtrl) c.dispose();
    for (final f in _digitFocus) f.dispose();
    _pageCtrl.dispose();
    _btnCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String get _otpCode =>
      _digitCtrl.map((c) => c.text).join();

  void _onDigitChanged(String value, int index) {
    if (value.length > 1) {
      // Handle paste — distribute across boxes
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _digitCtrl[i].text = digits[i];
      }
      final next = (digits.length < 6 ? digits.length : 5);
      _digitFocus[next].requestFocus();
      setState(() {});
      return;
    }
    if (value.isNotEmpty && index < 5) {
      _digitFocus[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _onDigitBackspace(int index) {
    if (_digitCtrl[index].text.isEmpty && index > 0) {
      _digitFocus[index - 1].requestFocus();
      _digitCtrl[index - 1].clear();
      setState(() {});
    }
  }

  // ── Firebase logic — unchanged ────────────────────────────────────────────────

  Future<void> verify() async {
    final code = _useBackup
        ? controller.text.trim()
        : _otpCode;

    if (code.isEmpty) return;

    setState(() => _loading = true);

    try {
      int now = DateTime.now().millisecondsSinceEpoch;

      String current = OTP.generateTOTPCodeString(
        widget.secret,
        now,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      String previous = OTP.generateTOTPCodeString(
        widget.secret,
        now - 30000,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );

      final uid = AuthHelper.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      List backupCodes = doc.data()?['twoFABackupCodes'] ?? [];

      bool validOTP = code == current || code == previous;
      bool validBackup = backupCodes.contains(code);

      if (validOTP || validBackup) {
        if (validBackup) {
          backupCodes.remove(code);
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .update({"twoFABackupCodes": backupCodes});
        }
        await goHome();
      } else {
        HapticFeedback.mediumImpact();
        _shakeCtrl.forward(from: 0);
        _showErrorSnack('Invalid code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> goHome() async {
    final uid = AuthHelper.uid;
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

  // ── Snackbars ────────────────────────────────────────────────────────────────

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.error_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: _buildAppBar(context, isDark),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // ── Header ────────────────────────────────────────────────────
              SlideTransition(
                position: _headerSlide,
                child: FadeTransition(
                  opacity: _headerFade,
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryOrange.withOpacity(0.12),
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: AppColors.primaryOrange,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Verify Your Identity',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text(context),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _useBackup
                            ? 'Enter one of your saved backup codes\nto access your account.'
                            : 'Enter the 6-digit code from your\nauthenticator app.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMid,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── Input Card ────────────────────────────────────────────────
              SlideTransition(
                position: _cardSlide,
                child: FadeTransition(
                  opacity: _cardFade,
                  child: SlideTransition(
                    position: _shakeOffset,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.07)
                              : AppColors.border,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.25)
                                : Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.06),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _useBackup
                            ? _buildBackupInput(context, isDark)
                            : _buildOtpBoxes(context, isDark),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Toggle backup / OTP ───────────────────────────────────────
              SlideTransition(
                position: _cardSlide,
                child: FadeTransition(
                  opacity: _cardFade,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _useBackup = !_useBackup;
                        controller.clear();
                        for (final c in _digitCtrl) c.clear();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 13),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primaryOrange.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _useBackup
                                ? Icons.pin_outlined
                                : Icons.key_rounded,
                            size: 16,
                            color: AppColors.primaryOrange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _useBackup
                                ? 'Use authenticator code instead'
                                : 'Use a backup code instead',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Info card ────────────────────────────────────────────────
              SlideTransition(
                position: _cardSlide,
                child: FadeTransition(
                  opacity: _cardFade,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : const Color(0xFFF3F2EF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: AppColors.textLight),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _useBackup
                                ? 'Each backup code can only be used once. Keep your remaining codes safe.'
                                : 'Open Google Authenticator, Authy, or 1Password to find your 6-digit code.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMid,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Verify button ─────────────────────────────────────────────
              SlideTransition(
                position: _cardSlide,
                child: FadeTransition(
                  opacity: _cardFade,
                  child: GestureDetector(
                    onTapDown: (_) {
                      if (!_loading) _btnCtrl.forward();
                    },
                    onTapUp: (_) {
                      _btnCtrl.reverse();
                      if (!_loading) {
                        HapticFeedback.mediumImpact();
                        verify();
                      }
                    },
                    onTapCancel: () => _btnCtrl.reverse(),
                    child: AnimatedBuilder(
                      animation: _btnScale,
                      builder: (_, child) => Transform.scale(
                          scale: _btnScale.value, child: child),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: _loading
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFFFF8C00),
                                    AppColors.primaryOrange,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: _loading
                              ? AppColors.primaryOrange.withOpacity(0.5)
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _loading
                              ? []
                              : [
                                  BoxShadow(
                                    color: AppColors.primaryOrange
                                        .withOpacity(0.38),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: _loading
                            ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.verified_user_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 9),
                                  Text(
                                    'Verify Code',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  // ── OTP Boxes ─────────────────────────────────────────────────────────────────

  Widget _buildOtpBoxes(BuildContext context, bool isDark) {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Authentication Code',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMid,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            final focused = _digitFocus[i].hasFocus;
            final filled = _digitCtrl[i].text.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 46,
              height: 56,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBackground
                    : const Color(0xFFF3F2EF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: focused
                      ? AppColors.primaryOrange
                      : filled
                          ? AppColors.primaryOrange.withOpacity(0.4)
                          : isDark
                              ? Colors.white.withOpacity(0.08)
                              : AppColors.border,
                  width: focused ? 1.8 : 1,
                ),
                boxShadow: focused
                    ? [
                        BoxShadow(
                          color: AppColors.primaryOrange.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: RawKeyboardListener(
                focusNode: FocusNode(),
                onKey: (event) {
                  if (event is RawKeyDownEvent &&
                      event.logicalKey ==
                          LogicalKeyboardKey.backspace) {
                    _onDigitBackspace(i);
                  }
                },
                child: TextField(
                  controller: _digitCtrl[i],
                  focusNode: _digitFocus[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6, // allow paste
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => _onDigitChanged(v, i),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        // Completion indicator
        AnimatedOpacity(
          opacity: _otpCode.length == 6 ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 14, color: Color(0xFF22C55E)),
              const SizedBox(width: 6),
              Text(
                'Code complete — ready to verify',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF22C55E).withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Backup Input ──────────────────────────────────────────────────────────────

  Widget _buildBackupInput(BuildContext context, bool isDark) {
    final focused = _focusNode.hasFocus;
    return Column(
      key: const ValueKey('backup'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Backup Code',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMid,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkBackground
                : const Color(0xFFF3F2EF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: focused
                  ? AppColors.primaryOrange
                  : isDark
                      ? Colors.white.withOpacity(0.08)
                      : AppColors.border,
              width: focused ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.text,
            maxLength: 12,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'e.g. AB12-CD34',
              hintStyle: TextStyle(
                color: AppColors.textLight,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
                fontFamily: 'monospace',
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16),
              prefixIcon: Icon(
                Icons.key_rounded,
                size: 18,
                color: focused
                    ? AppColors.primaryOrange
                    : AppColors.textLight,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      backgroundColor: AppColors.background(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        'Verification',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.text(context),
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: true,
    );
  }
}