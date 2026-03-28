import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/app_colors.dart';
import 'package:staynear/core/auth_helper.dart';

class BackupCodesPage extends StatefulWidget {
  const BackupCodesPage({super.key});

  @override
  State<BackupCodesPage> createState() => _BackupCodesPageState();
}

class _BackupCodesPageState extends State<BackupCodesPage>
    with TickerProviderStateMixin {

  // ── State ────────────────────────────────────
  List<String> codes   = [];
  bool loading         = true;
  int? _copiedIndex;
  bool _allCopied      = false;

  // ── Animations ───────────────────────────────
  late AnimationController _fadeSlideCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  final List<AnimationController> _cardCtrls = [];

  @override
  void initState() {
    super.initState();

    _fadeSlideCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _fadeAnim  = CurvedAnimation(parent: _fadeSlideCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeSlideCtrl, curve: Curves.easeOut));

    _loadCodes();
  }

  @override
  void dispose() {
    _fadeSlideCtrl.dispose();
    for (final c in _cardCtrls) c.dispose();
    super.dispose();
  }

  // ── Data loading (original logic – untouched) ──
  Future<void> _loadCodes() async {
    final uid = AuthHelper.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    codes = List<String>.from(doc.data()?['twoFABackupCodes'] ?? []);
    setState(() => loading = false);

    // Build per-card stagger controllers
    for (int i = 0; i < codes.length; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      _cardCtrls.add(ctrl);
      Future.delayed(Duration(milliseconds: 80 + i * 60), () {
        if (mounted) ctrl.forward();
      });
    }

    _fadeSlideCtrl.forward();
  }

  // ── Actions ──────────────────────────────────
  void _copyCode(int index) {
    Clipboard.setData(ClipboardData(text: codes[index]));
    HapticFeedback.selectionClick();
    setState(() => _copiedIndex = index);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedIndex = null);
    });
  }

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: codes.join('\n')));
    HapticFeedback.mediumImpact();
    setState(() => _allCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _allCopied = false);
    });
  }

  void _downloadCodes() {
    // UI-only placeholder — wire up file-save logic here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: const Row(
          children: [
            Icon(Icons.download_done_rounded, color: AppColors.primaryOrange, size: 18),
            SizedBox(width: 10),
            Text("Download feature coming soon",
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: _buildAppBar(context, dark),
      body: loading
          ? _buildLoader()
          : codes.isEmpty
              ? _buildEmpty(context)
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _buildContent(context, dark),
                  ),
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
            size: 16, color: AppColors.text(context),
          ),
        ),
      ),
      title: Text(
        "Backup Codes",
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

  Widget _buildLoader() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primaryOrange, strokeWidth: 2.5,
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.key_off_rounded,
              size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          Text("No backup codes available",
              style: TextStyle(color: AppColors.textMid, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool dark) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              children: [
                _buildWarningBanner(context, dark),
                const SizedBox(height: 24),
                _buildSectionHeader(context),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _buildCodeCard(context, dark, i),
              childCount: codes.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            child: _buildActions(context, dark),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBanner(BuildContext context, bool dark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange.withOpacity(dark ? 0.12 : 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryOrange.withOpacity(0.28),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryOrange.withOpacity(0.18),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.primaryOrange, size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Save these codes now",
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Each code can only be used once. Store them in a secure place — you'll need them if you lose access to your authenticator app.",
                  style: TextStyle(
                    color: AppColors.textMid,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    return Row(
      children: [
        Text(
          "${codes.length} Recovery Codes",
          style: TextStyle(
            color: AppColors.text(context),
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        Text(
          "Tap to copy",
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCodeCard(BuildContext context, bool dark, int index) {
    final isCopied = _copiedIndex == index;

    Widget card = GestureDetector(
      onTap: () => _copyCode(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isCopied
              ? AppColors.primaryOrange.withOpacity(dark ? 0.18 : 0.10)
              : AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCopied
                ? AppColors.primaryOrange.withOpacity(0.45)
                : (dark ? AppColors.darkCardSoft : AppColors.border),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.2 : 0.05),
              blurRadius: 12, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                codes[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: isCopied
                      ? AppColors.primaryOrange
                      : AppColors.text(context),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isCopied
                  ? const Icon(Icons.check_circle_rounded,
                      key: ValueKey('check'),
                      color: AppColors.primaryOrange, size: 16)
                  : Icon(Icons.copy_rounded,
                      key: const ValueKey('copy'),
                      color: AppColors.textLight, size: 14),
            ),
          ],
        ),
      ),
    );

    if (index < _cardCtrls.length) {
      final ctrl = _cardCtrls[index];
      return FadeTransition(
        opacity: CurvedAnimation(parent: ctrl, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12), end: Offset.zero,
          ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut)),
          child: card,
        ),
      );
    }

    return card;
  }

  Widget _buildActions(BuildContext context, bool dark) {
    return Column(
      children: [
        // Copy All
        GestureDetector(
          onTap: _copyAll,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _allCopied
                    ? [const Color(0xFF34C759), const Color(0xFF2DA44E)]
                    : [const Color(0xFFF5A623), const Color(0xFFE8920A)],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_allCopied
                      ? const Color(0xFF34C759)
                      : AppColors.primaryOrange).withOpacity(0.35),
                  blurRadius: 18, offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _allCopied
                        ? Icons.check_rounded
                        : Icons.copy_all_rounded,
                    key: ValueKey(_allCopied),
                    color: Colors.white, size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _allCopied ? "Copied!" : "Copy All Codes",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Download / Save
        GestureDetector(
          onTap: _downloadCodes,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.card(context),
              border: Border.all(
                color: dark ? AppColors.darkCardSoft : AppColors.border,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(dark ? 0.2 : 0.05),
                  blurRadius: 12, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_rounded,
                  color: AppColors.text(context), size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  "Download Codes",
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        Text(
          "Once used, a backup code cannot be reused.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}