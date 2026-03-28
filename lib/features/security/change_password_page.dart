import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:staynear/core/app_colors.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage>
    with TickerProviderStateMixin {
  final oldCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  bool loading = false;
  bool _oldVisible = false;
  bool _newVisible = false;
  bool _confirmVisible = false;

  // Focus nodes for animated field borders
  final _oldFocus = FocusNode();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  // Password strength
  double _strength = 0;
  String _strengthLabel = '';
  Color _strengthColor = Colors.transparent;

  // Animations
  late AnimationController _pageCtrl;
  late AnimationController _btnCtrl;

  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _oldFocus.addListener(() => setState(() {}));
    _newFocus.addListener(() => setState(() {}));
    _confirmFocus.addListener(() => setState(() {}));
    newCtrl.addListener(_evalStrength);
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

    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _pageCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _pageCtrl,
        curve: const Interval(0.3, 0.85, curve: Curves.easeOut),
      ),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageCtrl,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    _btnScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageCtrl.forward();
    });
  }

  void _evalStrength() {
    final p = newCtrl.text;
    double s = 0;
    if (p.length >= 8) s += 0.25;
    if (p.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (p.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) s += 0.25;

    String label;
    Color color;
    if (s <= 0.25) {
      label = 'Weak';
      color = AppColors.danger;
    } else if (s <= 0.5) {
      label = 'Fair';
      color = const Color(0xFFF59E0B);
    } else if (s <= 0.75) {
      label = 'Good';
      color = const Color(0xFF3B82F6);
    } else {
      label = 'Strong';
      color = const Color(0xFF22C55E);
    }

    setState(() {
      _strength = s;
      _strengthLabel = p.isEmpty ? '' : label;
      _strengthColor = color;
    });
  }

  @override
  void dispose() {
    oldCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
    _oldFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    _pageCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  // ── Firebase logic — unchanged ──────────────────────────────────────────────
  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email!;
    final oldPass = oldCtrl.text.trim();
    final newPass = newCtrl.text.trim();

    if (newPass != confirmCtrl.text.trim()) {
      _showErrorSnack('Passwords do not match');
      return;
    }

    try {
      setState(() => loading = true);

      final credential = EmailAuthProvider.credential(
        email: email,
        password: oldPass,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPass);

      if (mounted) _showSuccessSnack();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showErrorSnack('Error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ── Snackbars ────────────────────────────────────────────────────────────────
  void _showSuccessSnack() {
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
            color: const Color(0xFF22C55E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Password updated successfully',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  // ── Build ────────────────────────────────────────────────────────────────────
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Header ──────────────────────────────────────────────────────
              SlideTransition(
                position: _headerSlide,
                child: FadeTransition(
                  opacity: _headerFade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: AppColors.primaryOrange,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text(context),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose a strong password to keep\nyour account safe.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMid,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Fields Card ──────────────────────────────────────────────────
              SlideTransition(
                position: _cardSlide,
                child: FadeTransition(
                  opacity: _cardFade,
                  child: Container(
                    padding: const EdgeInsets.all(20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current password
                        _FieldLabel('Current Password'),
                        const SizedBox(height: 8),
                        _PasswordField(
                          controller: oldCtrl,
                          focusNode: _oldFocus,
                          hint: 'Enter current password',
                          visible: _oldVisible,
                          isDark: isDark,
                          onToggle: () =>
                              setState(() => _oldVisible = !_oldVisible),
                        ),
                        const SizedBox(height: 20),

                        // New password
                        _FieldLabel('New Password'),
                        const SizedBox(height: 8),
                        _PasswordField(
                          controller: newCtrl,
                          focusNode: _newFocus,
                          hint: 'Enter new password',
                          visible: _newVisible,
                          isDark: isDark,
                          onToggle: () =>
                              setState(() => _newVisible = !_newVisible),
                        ),

                        // Strength bar
                        if (newCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _StrengthBar(
                            strength: _strength,
                            label: _strengthLabel,
                            color: _strengthColor,
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Confirm password
                        _FieldLabel('Confirm Password'),
                        const SizedBox(height: 8),
                        _PasswordField(
                          controller: confirmCtrl,
                          focusNode: _confirmFocus,
                          hint: 'Re-enter new password',
                          visible: _confirmVisible,
                          isDark: isDark,
                          onToggle: () => setState(
                              () => _confirmVisible = !_confirmVisible),
                          // Live match indicator
                          suffixExtra: confirmCtrl.text.isNotEmpty
                              ? Icon(
                                  confirmCtrl.text == newCtrl.text
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  size: 18,
                                  color: confirmCtrl.text == newCtrl.text
                                      ? const Color(0xFF22C55E)
                                      : AppColors.danger,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Tips Card ────────────────────────────────────────────────────
              SlideTransition(
                position: _cardSlide,
                child: FadeTransition(
                  opacity: _cardFade,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primaryOrange.withOpacity(0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tips_and_updates_rounded,
                                size: 15, color: AppColors.primaryOrange),
                            const SizedBox(width: 7),
                            Text(
                              'Password tips',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryOrange.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._tips.map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primaryOrange
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primaryOrange
                                          .withOpacity(0.75),
                                      height: 1.5,
                                    ),
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

              const SizedBox(height: 32),

              // ── Update Button ────────────────────────────────────────────────
              SlideTransition(
                position: _cardSlide,
                child: FadeTransition(
                  opacity: _cardFade,
                  child: GestureDetector(
                    onTapDown: (_) {
                      if (!loading) _btnCtrl.forward();
                    },
                    onTapUp: (_) {
                      _btnCtrl.reverse();
                      if (!loading) {
                        HapticFeedback.mediumImpact();
                        _changePassword();
                      }
                    },
                    onTapCancel: () => _btnCtrl.reverse(),
                    child: AnimatedBuilder(
                      animation: _btnScale,
                      builder: (_, child) =>
                          Transform.scale(scale: _btnScale.value, child: child),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: loading
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFFFF8C00),
                                    AppColors.primaryOrange,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: loading
                              ? AppColors.primaryOrange.withOpacity(0.5)
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: loading
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
                        child: loading
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
                                  Icon(Icons.lock_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 9),
                                  Text(
                                    'Update Password',
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

  static const _tips = [
    'At least 8 characters long',
    'Mix uppercase and lowercase letters',
    'Include numbers and special characters',
    'Avoid using personal information',
  ];

  // ── AppBar ───────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
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
        'Security',
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

// ── Field Label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textMid,
        letterSpacing: 0.1,
      ),
    );
  }
}

// ── Password Field ────────────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool visible;
  final bool isDark;
  final VoidCallback onToggle;
  final Widget? suffixExtra;

  const _PasswordField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.visible,
    required this.isDark,
    required this.onToggle,
    this.suffixExtra,
  });

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;

    return AnimatedContainer(
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
        focusNode: focusNode,
        obscureText: !visible,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.text(context),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.textLight,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: focused ? AppColors.primaryOrange : AppColors.textLight,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (suffixExtra != null) ...[
                suffixExtra!,
                const SizedBox(width: 4),
              ],
              GestureDetector(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Strength Bar ──────────────────────────────────────────────────────────────

class _StrengthBar extends StatelessWidget {
  final double strength;
  final String label;
  final Color color;

  const _StrengthBar({
    required this.strength,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: strength,
                  minHeight: 4,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}