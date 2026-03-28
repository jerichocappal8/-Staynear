import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:base32/base32.dart';
import 'dart:math';
import 'dart:typed_data';

import 'package:staynear/core/app_colors.dart';
import 'package:staynear/core/auth_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'verify_2fa_screen.dart';

class Setup2FAScreen extends StatefulWidget {
  const Setup2FAScreen({super.key});

  @override
  State<Setup2FAScreen> createState() => _Setup2FAScreenState();
}

class _Setup2FAScreenState extends State<Setup2FAScreen>
    with TickerProviderStateMixin {
  String? secret;
  late Future<bool> _twoFAFuture;
  bool _secretCopied = false;

  // Animation controllers
  late AnimationController _pageCtrl;
  late AnimationController _qrCtrl;
  late AnimationController _btnCtrl;
  late AnimationController _disableCtrl;

  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _qrScale;
  late Animation<double> _qrFade;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();
    secret = _generateSecret();
    _twoFAFuture = check2FA();
    _initAnimations();
  }

  void _initAnimations() {
    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _qrCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _disableCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _pageCtrl,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
          parent: _pageCtrl,
          curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic)),
    );
    _qrScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _qrCtrl, curve: Curves.elasticOut),
    );
    _qrFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _qrCtrl,
          curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _pageCtrl,
          curve: const Interval(0.45, 0.85, curve: Curves.easeOut)),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
          parent: _pageCtrl,
          curve: const Interval(0.45, 0.9, curve: Curves.easeOutCubic)),
    );
    _btnScale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut),
    );

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        _pageCtrl.forward();
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) _qrCtrl.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _qrCtrl.dispose();
    _btnCtrl.dispose();
    _disableCtrl.dispose();
    super.dispose();
  }

  String _generateSecret() {
    final rand = Random.secure();
    final bytes =
        Uint8List.fromList(List.generate(20, (_) => rand.nextInt(256)));
    return base32.encode(bytes);
  }

  Future<bool> check2FA() async {
    final uid = AuthHelper.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data()?['twoFAEnabled'] ?? false;
  }

  Future<void> disable2FA() async {
    HapticFeedback.mediumImpact();
    final uid = AuthHelper.uid;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
      "twoFAEnabled": false,
      "twoFASecret": FieldValue.delete(),
      "twoFABackupCodes": FieldValue.delete(),
    });
    setState(() {});
  }

  Future<void> _copySecret() async {
    if (secret == null) return;
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: secret!));
    setState(() => _secretCopied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _secretCopied = false);
  }

  // ─── Enabled State ──────────────────────────────────────────────────────────

  Widget _buildEnabledScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: _buildAppBar(context, '2FA Settings'),
      body: FadeTransition(
        opacity: _pageCtrl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const Spacer(),

                // Shield icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryOrange.withOpacity(0.12),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    size: 44,
                    color: AppColors.primaryOrange,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Two-Factor Authentication',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                    letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Your account is protected with an extra\nlayer of security.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMid,
                    height: 1.55,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 16, color: Color(0xFF22C55E)),
                      SizedBox(width: 7),
                      Text(
                        'Active & Enabled',
                        style: TextStyle(
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.07)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.smartphone_rounded,
                            size: 20, color: AppColors.primaryOrange),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Authenticator App',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.text(context),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'TOTP codes refresh every 30s',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMid,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Disable button
                GestureDetector(
                  onTapDown: (_) => _btnCtrl.forward(),
                  onTapUp: (_) {
                    _btnCtrl.reverse();
                    _showDisableConfirm(context);
                  },
                  onTapCancel: () => _btnCtrl.reverse(),
                  child: AnimatedBuilder(
                    animation: _btnScale,
                    builder: (_, child) => Transform.scale(
                      scale: _btnScale.value,
                      child: child,
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.danger.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 18, color: AppColors.danger),
                          SizedBox(width: 9),
                          Text(
                            'Disable 2FA',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDisableConfirm(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DisableConfirmSheet(onConfirm: disable2FA),
    );
  }

  // ─── Setup Screen ────────────────────────────────────────────────────────────

  Widget _buildSetupScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uri =
        "otpauth://totp/Staynear?secret=$secret&issuer=Staynear&algorithm=SHA1&digits=6&period=30";

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: _buildAppBar(context, 'Setup 2FA'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // ── Header ──────────────────────────────────────────────────────
              SlideTransition(
                position: _headerSlide,
                child: FadeTransition(
                  opacity: _headerFade,
                  child: Column(
                    children: [
                      // Step indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final active = i == 0;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin:
                                const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primaryOrange
                                  : AppColors.primaryOrange.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Scan QR Code',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text(context),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Open your authenticator app and\nscan this code to link your account.',
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

              const SizedBox(height: 32),

              // ── QR Card ──────────────────────────────────────────────────────
              FadeTransition(
                opacity: _qrFade,
                child: ScaleTransition(
                  scale: _qrScale,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : AppColors.border,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // QR outer glow ring
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.03)
                                : const Color(0xFFFAF9F7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primaryOrange.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: QrImageView(
                            data: uri,
                            size: 200,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF1A1A2E),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Timer hint
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.timer_outlined,
                                size: 14, color: AppColors.textLight),
                            const SizedBox(width: 5),
                            Text(
                              'Code refreshes every 30 seconds',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Secret Key Card ──────────────────────────────────────────────
              SlideTransition(
                position: _cardSlide,
                child: FadeTransition(
                  opacity: _cardFade,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.07)
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.primaryOrange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.key_rounded,
                                  size: 16, color: AppColors.primaryOrange),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Manual Setup Key',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.text(context),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Can\'t scan?',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkBackground
                                : const Color(0xFFF3F2EF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SelectableText(
                            secret ?? '',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text(context),
                              letterSpacing: 1.5,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _copySecret,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: double.infinity,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _secretCopied
                                  ? const Color(0xFF22C55E).withOpacity(0.12)
                                  : AppColors.primaryOrange.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _secretCopied
                                    ? const Color(0xFF22C55E).withOpacity(0.3)
                                    : AppColors.primaryOrange.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _secretCopied
                                      ? Icons.check_rounded
                                      : Icons.copy_rounded,
                                  size: 15,
                                  color: _secretCopied
                                      ? const Color(0xFF22C55E)
                                      : AppColors.primaryOrange,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  _secretCopied ? 'Copied!' : 'Copy Key',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _secretCopied
                                        ? const Color(0xFF22C55E)
                                        : AppColors.primaryOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Supported Apps ───────────────────────────────────────────────
              SlideTransition(
                position: _cardSlide,
                child: FadeTransition(
                  opacity: _cardFade,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primaryOrange.withOpacity(0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 18, color: AppColors.primaryOrange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Works with Google Authenticator, Authy, and 1Password.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryOrange
                                  .withOpacity(0.85),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── CTA Button ───────────────────────────────────────────────────
              SlideTransition(
                position: _cardSlide,
                child: FadeTransition(
                  opacity: _cardFade,
                  child: _GradientButton(
                    label: 'Continue to Verify',
                    icon: Icons.arrow_forward_rounded,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, animation, __) =>
                              Verify2FAScreen(secret: secret!),
                          transitionsBuilder: (_, animation, __, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.06, 0),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic)),
                                child: child,
                              ),
                            );
                          },
                          transitionDuration:
                              const Duration(milliseconds: 380),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Shared AppBar ───────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: AppColors.background(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : AppColors.border,
            ),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: AppColors.text(context),
          ),
        ),
      ),
      title: Text(
        title,
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

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _twoFAFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: AppColors.background(context),
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryOrange,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        if (snapshot.data!) {
          return _buildEnabledScreen(context);
        }

        if (secret == null) {
          return Scaffold(
            backgroundColor: AppColors.background(context),
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryOrange,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        return _buildSetupScreen(context);
      },
    );
  }
}

// ─── Gradient CTA Button ──────────────────────────────────────────────────────

class _GradientButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8C00), AppColors.primaryOrange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withOpacity(0.38),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(width: 8),
              Icon(widget.icon, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Disable Confirm Sheet ────────────────────────────────────────────────────

class _DisableConfirmSheet extends StatelessWidget {
  final VoidCallback onConfirm;
  const _DisableConfirmSheet({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : AppColors.border,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textLight.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.danger.withOpacity(0.1),
            ),
            child: const Icon(Icons.gpp_bad_rounded,
                size: 30, color: AppColors.danger),
          ),
          const SizedBox(height: 18),

          Text(
            'Disable 2FA?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Removing two-factor authentication\nwill make your account less secure.',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMid,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : const Color(0xFFF3F2EF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.text(context),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onConfirm();
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.danger.withOpacity(0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Yes, Disable',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}