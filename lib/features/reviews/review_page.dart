// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/features/reviews/review_page.dart
//
//  Entry point:
//    Navigator.push(context, MaterialPageRoute(
//      builder: (_) => ReviewPage(bookingId: id, data: bookingData),
//    ));
//
//  Returns true on pop if a review was submitted, so the caller can react:
//    final submitted = await Navigator.push<bool>(...);
//    if (submitted == true) { /* refresh UI */ }
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import 'review_service.dart';
import 'widgets/star_rating_widget.dart';

class ReviewPage extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> data;

  const ReviewPage({
    super.key,
    required this.bookingId,
    required this.data,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage>
    with TickerProviderStateMixin {

  // ── Form state ────────────────────────────────────────────────────────────
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── Submission state ──────────────────────────────────────────────────────
  bool _submitting = false;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _entranceCtrl;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  static const _cardCount = 4; // header + rating + comment + submit

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnims = List.generate(_cardCount, (i) {
      final start = i * 0.15;
      final end = (start + 0.45).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _slideAnims = List.generate(_cardCount, (i) {
      final start = i * 0.15;
      final end = (start + 0.45).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ));
    });

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  static String _fmtDate(dynamic raw) {
    if (raw == null) return '—';
    try {
      final dt =
          (raw is Timestamp) ? raw.toDate() : DateTime.parse(raw.toString());
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return raw.toString();
    }
  }

  static String _fmtPrice(double v) =>
      '₱${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  // ─────────────────────────────────────────────────────────────────────────
  //  SUBMIT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rating == 0) {
      _showSnack('Please select a star rating before submitting.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);

    try {
      final d = widget.data;
      final user = FirebaseAuth.instance.currentUser;

      await ReviewService.submitReview(
        bookingId: widget.bookingId,
        apartmentId: (d['apartmentId'] ?? '') as String,
        apartmentName: (d['apartmentName'] ?? 'Apartment') as String,
        userId: user?.uid ?? (d['userId'] ?? '') as String,
        hostId: (d['hostId'] ?? '') as String,
        guestName: (d['guestName'] ?? user?.displayName ?? 'Guest') as String,
        rating: _rating,
        comment: _commentCtrl.text,
        checkIn: d['checkIn'] is Timestamp
            ? (d['checkIn'] as Timestamp).toDate()
            : DateTime.tryParse(d['checkIn'].toString()) ?? DateTime.now(),
        checkOut: d['checkOut'] is Timestamp
            ? (d['checkOut'] as Timestamp).toDate()
            : DateTime.tryParse(d['checkOut'].toString()) ?? DateTime.now(),
        amountPaid: ((d['amountPaid'] as num?) ?? 0).toDouble(),
      );

      if (!mounted) return;
      await _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessDialog(
        rating: _rating,
        onDone: () {
          Navigator.pop(context); // close dialog
          Navigator.pop(context, true); // pop ReviewPage with result = true
        },
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final name = (d['apartmentName'] ?? 'Apartment') as String;
    final imageUrl = (d['apartmentImage'] ?? '') as String;
    final amountPaid = ((d['amountPaid'] as num?) ?? 0).toDouble();
    final checkIn = d['checkIn'];
    final checkOut = d['checkOut'];

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // ── Scrollable content ────────────────────────────────────────
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // App bar
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: AppColors.background(context),
                    leading: _NavBackButton(),
                    title: Text(
                      'Write a Review',
                      style: TextStyle(
                        color: AppColors.text(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    centerTitle: true,
                    elevation: 0,
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([

                        // ── [0] Booking summary card ───────────────────────
                        _AnimatedCard(
                          fadeAnim: _fadeAnims[0],
                          slideAnim: _slideAnims[0],
                          child: _BookingSummaryCard(
                            name: name,
                            imageUrl: imageUrl,
                            checkIn: _fmtDate(checkIn),
                            checkOut: _fmtDate(checkOut),
                            amountPaid: _fmtPrice(amountPaid),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── [1] Star rating card ───────────────────────────
                        _AnimatedCard(
                          fadeAnim: _fadeAnims[1],
                          slideAnim: _slideAnims[1],
                          child: _RatingCard(
                            rating: _rating,
                            onRatingChanged: (r) =>
                                setState(() => _rating = r),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── [2] Comment card ───────────────────────────────
                        _AnimatedCard(
                          fadeAnim: _fadeAnims[2],
                          slideAnim: _slideAnims[2],
                          child: _CommentCard(controller: _commentCtrl),
                        ),
                        const SizedBox(height: 16),

                        // ── [3] Disclaimer ─────────────────────────────────
                        _AnimatedCard(
                          fadeAnim: _fadeAnims[3],
                          slideAnim: _slideAnims[3],
                          child: _DisclaimerNote(),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            // ── Sticky submit button ──────────────────────────────────────
            _SubmitButton(
              rating: _rating,
              submitting: _submitting,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BOOKING SUMMARY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _BookingSummaryCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String checkIn;
  final String checkOut;
  final String amountPaid;

  const _BookingSummaryCard({
    required this.name,
    required this.imageUrl,
    required this.checkIn,
    required this.checkOut,
    required this.amountPaid,
  });

  @override
  Widget build(BuildContext context) {
    return _ReviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(icon: Icons.apartment_rounded, title: 'Your Stay'),
          const SizedBox(height: 16),

          // Apartment image + name row
          Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _ImagePlaceholder(),
                      )
                    : _ImagePlaceholder(),
              ),
              const SizedBox(width: 14),

              // Name + dates
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(context),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 12, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$checkIn → $checkOut',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMid,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: AppColors.cardSoft(context), height: 1),
          const SizedBox(height: 14),

          // Total paid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Paid',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMid,
                ),
              ),
              Text(
                amountPaid,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryOrange,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.apartment_rounded,
          color: AppColors.primaryOrange, size: 28),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RATING CARD
// ─────────────────────────────────────────────────────────────────────────────

class _RatingCard extends StatelessWidget {
  final int rating;
  final void Function(int) onRatingChanged;

  const _RatingCard({required this.rating, required this.onRatingChanged});

  @override
  Widget build(BuildContext context) {
    return _ReviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.star_rounded,
            title: 'Your Rating',
            subtitle: 'How was your overall experience?',
          ),
          const SizedBox(height: 24),
          Center(
            child: StarRatingWidget(
              rating: rating,
              onRatingChanged: onRatingChanged,
              starSize: 48,
              spacing: 6,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  COMMENT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _CommentCard extends StatelessWidget {
  final TextEditingController controller;

  const _CommentCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _ReviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Your Review',
            subtitle: 'Share your experience',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller,
            maxLines: 5,
            maxLength: 500,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please write a short review.';
              }
              if (v.trim().length < 10) {
                return 'Review must be at least 10 characters.';
              }
              return null;
            },
            style: TextStyle(
              fontSize: 14,
              color: AppColors.text(context),
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText:
                  'Tell others about the cleanliness, location, host responsiveness...',
              hintStyle: TextStyle(
                fontSize: 13.5,
                color: AppColors.textLight,
                height: 1.5,
              ),
              filled: true,
              fillColor: AppColors.cardSoft(context).withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.cardSoft(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.cardSoft(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: AppColors.primaryOrange, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.danger, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.danger, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(16),
              counterStyle: TextStyle(
                color: AppColors.textLight,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DISCLAIMER NOTE
// ─────────────────────────────────────────────────────────────────────────────

class _DisclaimerNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded,
            size: 14, color: AppColors.textLight),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Reviews are public and can only be submitted once per booking. '
            'Make sure your feedback is honest and respectful.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUBMIT BUTTON (sticky bottom)
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  final int rating;
  final bool submitting;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.rating,
    required this.submitting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isReady = rating > 0 && !submitting;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(
          top: BorderSide(color: AppColors.cardSoft(context), width: 1),
        ),
      ),
      child: GestureDetector(
        onTap: submitting ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 56,
          decoration: BoxDecoration(
            gradient: isReady
                ? const LinearGradient(
                    colors: [Color(0xFFFF8C00), Color(0xFFF5A623)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: isReady ? null : AppColors.cardSoft(context),
            borderRadius: BorderRadius.circular(18),
            boxShadow: isReady
                ? [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.40),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primaryOrange,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.rate_review_rounded,
                        size: 18,
                        color: isReady ? Colors.white : AppColors.textLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        rating == 0
                            ? 'Select a rating to continue'
                            : 'Submit Review',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color:
                              isReady ? Colors.white : AppColors.textLight,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUCCESS DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessDialog extends StatelessWidget {
  final int rating;
  final VoidCallback onDone;

  const _SuccessDialog({required this.rating, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Animated check circle ──────────────────────────────────
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF34D399), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF34D399).withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Review Submitted!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.text(context),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thank you for sharing your experience.\nYour feedback helps other guests.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textMid,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // Star display
            StarRatingDisplay(rating: rating, size: 22, spacing: 3),

            const SizedBox(height: 24),

            GestureDetector(
              onTap: onDone,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8C00), Color(0xFFF5A623)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Back to Booking',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final Widget child;
  const _ReviewCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardSoft(context), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _CardHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: AppColors.primaryOrange),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text(context),
                letterSpacing: -0.1,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMid,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _AnimatedCard extends StatelessWidget {
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;
  final Widget child;

  const _AnimatedCard({
    required this.fadeAnim,
    required this.slideAnim,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(
        position: slideAnim,
        child: child,
      ),
    );
  }
}

class _NavBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardSoft(context)),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.text(context),
            size: 16,
          ),
        ),
      ),
    );
  }
}