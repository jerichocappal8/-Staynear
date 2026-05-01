import 'package:flutter/material.dart';
import 'package:staynear/core/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── App Colors (your existing theme) ────────────────────────────────────────
// ─── FAQ Data Model ───────────────────────────────────────────────────────────

class FAQItem {
  final String question;
  final String answer;
  final IconData icon;

  const FAQItem({
    required this.question,
    required this.answer,
    required this.icon,
  });
}

// ─── FAQ Screen ───────────────────────────────────────────────────────────────

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  int? _expandedIndex;

  static const _faqs = [
    FAQItem(
      question: 'How do I book a stay?',
      answer:
          'Browse properties on the home screen, select one you love, choose your check-in and check-out dates, then tap "Book Now." You\'ll receive a confirmation email once your booking is confirmed by the host.',
      icon: Icons.calendar_today_rounded,
    ),
    FAQItem(
      question: 'What payment methods are accepted?',
      answer:
          'We accept all major credit and debit cards (Visa, Mastercard, Amex), GCash, PayMaya, and bank transfers. All transactions are secured with 256-bit SSL encryption.',
      icon: Icons.credit_card_rounded,
    ),
    FAQItem(
      question: 'Can I cancel or modify my booking?',
      answer:
          'Yes! Go to "My Bookings," select the reservation, and tap "Manage Booking." Cancellation policies vary by host — free cancellation is available if you cancel at least 48 hours before check-in for most properties.',
      icon: Icons.edit_calendar_rounded,
    ),
    FAQItem(
      question: 'How do I contact my host?',
      answer:
          'Once your booking is confirmed, a chat button will appear on your booking details screen. You can message your host directly through the StayNear in-app chat — available 24/7.',
      icon: Icons.chat_bubble_outline_rounded,
    ),
    FAQItem(
      question: 'Is my personal information safe?',
      answer:
          'Absolutely. StayNear uses bank-level encryption to protect your data. We never sell your personal information to third parties. You can review our full privacy policy under Settings → Privacy.',
      icon: Icons.shield_outlined,
    ),
    FAQItem(
      question: 'What if the property doesn\'t match the listing?',
      answer:
          'If a property significantly differs from its listing, contact us within 24 hours of check-in through the Help Center. Our team will review the issue and may offer a refund or find you alternative accommodation.',
      icon: Icons.home_outlined,
    ),
    FAQItem(
      question: 'How do reviews work?',
      answer:
          'After your stay, you\'ll receive a prompt to rate your experience from 1–5 stars and leave a written review. Reviews are visible to all users and help maintain trust across the StayNear community.',
      icon: Icons.star_outline_rounded,
    ),
    FAQItem(
      question: 'Can I list my own property?',
      answer:
          'Yes! Tap the "Become a Host" button on your profile page. You\'ll be guided through adding photos, setting your availability, pricing, and house rules. Your listing goes live after a brief review.',
      icon: Icons.add_home_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.background(context);
    final textColor = AppColors.text(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(context, isDark, textColor),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, isDark)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _FAQTile(
                      item: _faqs[index],
                      index: index,
                      isExpanded: _expandedIndex == index,
                      onTap: () => setState(
                        () =>
                            _expandedIndex =
                                _expandedIndex == index ? null : index,
                      ),
                    ),
                    childCount: _faqs.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildContactCard(context, isDark)),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    bool isDark,
    Color textColor,
  ) {
    return AppBar(
      backgroundColor: isDark ? AppColors.darkNavbar : AppColors.cardWhite,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.border.withOpacity(0.5),
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkCard
                : AppColors.bgLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? AppColors.darkCardSoft
                  : AppColors.border,
            ),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: textColor,
          ),
        ),
      ),
      title: Text(
        'FAQ',
        style: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: Icon(
            Icons.search_rounded,
            color: AppColors.textMid,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryOrange, Color(0xFFFFCA6C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'How can we\nhelp you?',
            style: TextStyle(
              color: AppColors.text(context),
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find answers to the most commonly\nasked questions about StayNear.',
            style: TextStyle(
              color: AppColors.textMid,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),

          // Search bar (decorative / hookable)
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkCardSoft : AppColors.border,
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.search_rounded,
                  color: AppColors.textLight,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Search questions...',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryOrange,
              const Color(0xFFFFCA6C),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Still need help?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Our support team is available\n24/7 to assist you.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri(
                        scheme: 'mailto',
                        path: 'support@staynear.ph',
                        queryParameters: {
                          'subject': 'StayNear Support Request',
                        },
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else {
                        // Fallback: show email in a dialog
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Contact Support'),
                            content: const Text(
                              'Email us at:\nsupport@staynear.ph',
                              style: TextStyle(height: 1.5),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Contact Support',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Animated FAQ Tile ────────────────────────────────────────────────────────

class _FAQTile extends StatefulWidget {
  final FAQItem item;
  final int index;
  final bool isExpanded;
  final VoidCallback onTap;

  const _FAQTile({
    required this.item,
    required this.index,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  State<_FAQTile> createState() => _FAQTileState();
}

class _FAQTileState extends State<_FAQTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _iconRotation;
  late final Animation<double> _fadeIn;

  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _iconRotation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    // Stagger entrance
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(_FAQTile old) {
    super.didUpdateWidget(old);
    if (widget.isExpanded != old.isExpanded) {
      widget.isExpanded ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = AppColors.card(context);
    final textColor = AppColors.text(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: widget.onTap,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: widget.isExpanded
                  ? (isDark ? AppColors.darkCardSoft : AppColors.orangeLight)
                  : cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.isExpanded
                    ? AppColors.primaryOrange.withOpacity(0.4)
                    : (isDark
                          ? AppColors.darkCardSoft
                          : AppColors.border),
                width: widget.isExpanded ? 1.5 : 1,
              ),
              boxShadow: isDark
                  ? [
                      if (widget.isExpanded)
                        BoxShadow(
                          color: AppColors.primaryOrange.withOpacity(0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          widget.isExpanded ? 0.07 : 0.04,
                        ),
                        blurRadius: widget.isExpanded ? 16 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              children: [
                // Question Row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      // Icon badge
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: widget.isExpanded
                              ? const LinearGradient(
                                  colors: [
                                    AppColors.primaryOrange,
                                    Color(0xFFFFCA6C),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: widget.isExpanded
                              ? null
                              : (isDark
                                    ? AppColors.darkCardSoft
                                    : AppColors.bgLight),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          widget.item.icon,
                          size: 18,
                          color: widget.isExpanded
                              ? Colors.white
                              : AppColors.primaryOrange,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Question text
                      Expanded(
                        child: Text(
                          widget.item.question,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Animated chevron
                      RotationTransition(
                        turns: _iconRotation,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCardSoft
                                : AppColors.bgLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: widget.isExpanded
                                ? AppColors.primaryOrange
                                : AppColors.textMid,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Answer panel
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: Column(
                      children: [
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark
                              ? AppColors.darkCardSoft
                              : AppColors.border,
                          indent: 16,
                          endIndent: 16,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left accent bar
                              Container(
                                width: 3,
                                height: _estimateHeight(widget.item.answer),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.primaryOrange,
                                      Color(0xFFFFCA6C),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  widget.item.answer,
                                  style: TextStyle(
                                    color: AppColors.textMid,
                                    fontSize: 13.5,
                                    height: 1.65,
                                  ),
                                ),
                              ),
                            ],
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
    );
  }

  double _estimateHeight(String text) {
    // Rough estimate: ~20px per line, ~50 chars per line at this font size
    final lines = (text.length / 50).ceil();
    return (lines * 22).toDouble().clamp(40, 200);
  }
}