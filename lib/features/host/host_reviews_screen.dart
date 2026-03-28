// host_reviews_screen.dart
// ════════════════════════════════════════════════════════════════════════════
//  StayNear — Host Reviews Screen
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:staynear/core/app_colors.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class HostReviewsScreen extends StatefulWidget {
  const HostReviewsScreen({super.key});

  @override
  State<HostReviewsScreen> createState() => _HostReviewsScreenState();
}

class _HostReviewsScreenState extends State<HostReviewsScreen>
    with SingleTickerProviderStateMixin {
  // ── entrance animation ─────────────────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve:  Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve:  Curves.easeOutCubic,
    ));

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    try {
      final dt = (value is Timestamp) ? value.toDate() : DateTime.parse(value.toString());
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '—';
    try {
      final amount = double.parse(value.toString());
      return '₱${NumberFormat('#,##0.00').format(amount)}';
    } catch (_) {
      return '₱${value.toString()}';
    }
  }

  double _calcAverage(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;
    final total = docs.fold<double>(
      0,
      (sum, d) => sum + ((d['rating'] ?? 0) as num).toDouble(),
    );
    return total / docs.length;
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: _buildAppBar(context, isDark),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reviews')
                .where('hostId', isEqualTo: uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              // ── loading ──────────────────────────────────────────────────
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryOrange,
                    strokeWidth: 2.5,
                  ),
                );
              }

              // ── error ────────────────────────────────────────────────────
              if (snapshot.hasError) {
                return _buildErrorState(context);
              }

              final docs = snapshot.data?.docs ?? [];

              // ── empty ────────────────────────────────────────────────────
              if (docs.isEmpty) {
                return _buildEmptyState(context);
              }

              final average = _calcAverage(docs);

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── summary header ───────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _SummaryHeader(
                      totalReviews: docs.length,
                      averageRating: average,
                    ),
                  ),

                  // ── review cards ─────────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          return _ReviewCard(
                            index:         index,
                            data:          data,
                            formatDate:    _formatDate,
                            formatCurrency: _formatCurrency,
                          );
                        },
                        childCount: docs.length,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      backgroundColor:
          isDark ? AppColors.darkNavbar : AppColors.cardWhite,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.border.withOpacity(0.5),
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.bgLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkCardSoft : AppColors.border,
            ),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size:  16,
            color: AppColors.text(context),
          ),
        ),
      ),
      title: Text(
        'Guest Reviews',
        style: TextStyle(
          color:       AppColors.text(context),
          fontSize:    18,
          fontWeight:  FontWeight.w700,
          letterSpacing: -.3,
        ),
      ),
      centerTitle: true,
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  80,
              height: 80,
              decoration: BoxDecoration(
                color:         AppColors.primaryOrange.withOpacity(.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_outline_rounded,
                size:  38,
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No reviews yet',
              style: TextStyle(
                color:      AppColors.text(context),
                fontSize:   18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reviews from your guests will\nappear here after their stay.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:   AppColors.textMid,
                fontSize: 14,
                height:  1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error state ─────────────────────────────────────────────────────────────

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 42, color: AppColors.textLight),
          const SizedBox(height: 12),
          Text(
            'Could not load reviews',
            style: TextStyle(
              color:      AppColors.text(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Check your connection and try again.',
            style: TextStyle(color: AppColors.textMid, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SUMMARY HEADER
// ═════════════════════════════════════════════════════════════════════════════

class _SummaryHeader extends StatelessWidget {
  final int    totalReviews;
  final double averageRating;

  const _SummaryHeader({
    required this.totalReviews,
    required this.averageRating,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryOrange, Color(0xFFFFCA6C)],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color:      AppColors.primaryOrange.withOpacity(.32),
              blurRadius: 22,
              offset:     const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Row(
          children: [
            // ── Average rating ─────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Average Rating',
                    style: TextStyle(
                      color:      Colors.white70,
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   40,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          height:     1,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6, left: 4),
                        child: Text(
                          '/ 5.0',
                          style: TextStyle(
                            color:      Colors.white70,
                            fontSize:   14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Star row
                  Row(
                    children: List.generate(5, (i) {
                      final full = i < averageRating.floor();
                      final half = !full &&
                          i < averageRating &&
                          (averageRating - i) >= 0.5;
                      return Icon(
                        full
                            ? Icons.star_rounded
                            : half
                                ? Icons.star_half_rounded
                                : Icons.star_outline_rounded,
                        color: Colors.white,
                        size:  18,
                      );
                    }),
                  ),
                ],
              ),
            ),

            // ── Divider ─────────────────────────────────────────────────────
            Container(
              width:  1,
              height: 70,
              color:  Colors.white.withOpacity(.3),
              margin: const EdgeInsets.symmetric(horizontal: 20),
            ),

            // ── Total reviews ────────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width:  56,
                  height: 56,
                  decoration: BoxDecoration(
                    color:  Colors.white.withOpacity(.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.rate_review_rounded,
                    color: Colors.white,
                    size:  26,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  totalReviews.toString(),
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
                const Text(
                  'Total Reviews',
                  style: TextStyle(
                    color:      Colors.white70,
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  REVIEW CARD
// ═════════════════════════════════════════════════════════════════════════════

class _ReviewCard extends StatefulWidget {
  final int                        index;
  final Map<String, dynamic>       data;
  final String Function(dynamic)   formatDate;
  final String Function(dynamic)   formatCurrency;

  const _ReviewCard({
    required this.index,
    required this.data,
    required this.formatDate,
    required this.formatCurrency,
  });

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Stagger each card's entrance
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final data        = widget.data;
    final rating      = ((data['rating'] ?? 0) as num).toDouble();
    final guestName   = data['guestName']     ?? 'Anonymous';
    final aptName     = data['apartmentName'] ?? 'Unknown Property';
    final comment     = data['comment']       ?? '';
    final amountPaid  = widget.formatCurrency(data['amountPaid']);
    final checkIn     = widget.formatDate(data['checkIn']);
    final checkOut    = widget.formatDate(data['checkOut']);
    final reviewDate  = widget.formatDate(data['createdAt']);

    return FadeTransition(
      opacity:  _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color:         AppColors.card(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? AppColors.darkCardSoft
                  : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(.30)
                    : Colors.black.withOpacity(.055),
                blurRadius: 16,
                offset:     const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Card header ──────────────────────────────────────────────
              _CardHeader(
                guestName:  guestName,
                aptName:    aptName,
                rating:     rating,
                reviewDate: reviewDate,
              ),

              // ── Divider ──────────────────────────────────────────────────
              Divider(
                height:    1,
                thickness: 1,
                color: isDark
                    ? AppColors.darkCardSoft
                    : AppColors.border,
              ),

              // ── Comment ──────────────────────────────────────────────────
              if (comment.isNotEmpty)
                _CommentBlock(comment: comment),

              // ── Divider ──────────────────────────────────────────────────
              if (comment.isNotEmpty)
                Divider(
                  height:    1,
                  thickness: 1,
                  color: isDark
                      ? AppColors.darkCardSoft
                      : AppColors.border,
                ),

              // ── Stay details footer ──────────────────────────────────────
              _StayDetails(
                checkIn:    checkIn,
                checkOut:   checkOut,
                amountPaid: amountPaid,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CARD HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final String guestName;
  final String aptName;
  final double rating;
  final String reviewDate;

  const _CardHeader({
    required this.guestName,
    required this.aptName,
    required this.rating,
    required this.reviewDate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          Container(
            width:  46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryOrange, Color(0xFFFFCA6C)],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                guestName.isNotEmpty
                    ? guestName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Name + apt + date ────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guestName,
                  style: TextStyle(
                    color:      AppColors.text(context),
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.apartment_rounded,
                      size:  11,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        aptName,
                        style: const TextStyle(
                          color:    AppColors.textMid,
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // ── Star rating row ────────────────────────────────────────
                _StarRating(rating: rating),
              ],
            ),
          ),

          // ── Review date ──────────────────────────────────────────────────
          Text(
            reviewDate,
            style: const TextStyle(
              color:    AppColors.textLight,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STAR RATING
// ─────────────────────────────────────────────────────────────────────────────

class _StarRating extends StatelessWidget {
  final double rating;
  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final full = i < rating.floor();
          final half = !full && i < rating && (rating - i) >= 0.5;
          return Icon(
            full
                ? Icons.star_rounded
                : half
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            color: AppColors.primaryOrange,
            size:  15,
          );
        }),
        const SizedBox(width: 5),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            color:      AppColors.primaryOrange,
            fontSize:   12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  COMMENT BLOCK
// ─────────────────────────────────────────────────────────────────────────────

class _CommentBlock extends StatelessWidget {
  final String comment;
  const _CommentBlock({required this.comment});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent bar
          Container(
            width:  3,
            height: _estimateHeight(comment),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryOrange, Color(0xFFFFCA6C)],
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              comment,
              style: TextStyle(
                color:   isDark ? Colors.white70 : AppColors.textMid,
                fontSize: 13.5,
                height:  1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _estimateHeight(String text) {
    final lines = (text.length / 48).ceil();
    return (lines * 22.0).clamp(22, 180);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STAY DETAILS FOOTER
// ─────────────────────────────────────────────────────────────────────────────

class _StayDetails extends StatelessWidget {
  final String checkIn;
  final String checkOut;
  final String amountPaid;

  const _StayDetails({
    required this.checkIn,
    required this.checkOut,
    required this.amountPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          // Check-in
          Expanded(
            child: _DetailChip(
              icon:  Icons.login_rounded,
              label: 'Check-in',
              value: checkIn,
            ),
          ),
          const SizedBox(width: 8),
          // Check-out
          Expanded(
            child: _DetailChip(
              icon:  Icons.logout_rounded,
              label: 'Check-out',
              value: checkOut,
            ),
          ),
          const SizedBox(width: 8),
          // Amount paid
          Expanded(
            child: _DetailChip(
              icon:  Icons.payments_rounded,
              label: 'Amount Paid',
              value: amountPaid,
              accent: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final bool     accent;

  const _DetailChip({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.primaryOrange.withOpacity(.10)
            : isDark
                ? AppColors.darkCardSoft.withOpacity(.5)
                : AppColors.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: accent
            ? Border.all(
                color: AppColors.primaryOrange.withOpacity(.25),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size:  11,
                color: accent ? AppColors.primaryOrange : AppColors.textLight,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color:    accent ? AppColors.primaryOrange : AppColors.textLight,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent
                  ? AppColors.primaryOrange
                  : AppColors.text(context),
              fontSize:   11.5,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}