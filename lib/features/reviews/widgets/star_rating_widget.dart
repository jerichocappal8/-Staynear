// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/features/reviews/widgets/star_rating_widget.dart
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  INTERACTIVE STAR RATING PICKER
//  Usage:
//    StarRatingWidget(
//      rating: _rating,
//      onRatingChanged: (r) => setState(() => _rating = r),
//    )
// ─────────────────────────────────────────────────────────────────────────────

class StarRatingWidget extends StatefulWidget {
  final int rating;
  final void Function(int) onRatingChanged;
  final double starSize;
  final double spacing;

  const StarRatingWidget({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.starSize = 44,
    this.spacing = 8,
  });

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget> {
  int _hovered = 0; // 0 = no hover

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent'];

  static const _labelColors = [
    Colors.transparent,
    Color(0xFFEF4444), // 1 – Poor
    Color(0xFFF97316), // 2 – Fair
    Color(0xFFF59E0B), // 3 – Good
    Color(0xFF84CC16), // 4 – Great
    Color(0xFF22C55E), // 5 – Excellent
  ];

  int get _display => _hovered > 0 ? _hovered : widget.rating;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Stars row ─────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final starIndex = i + 1;
            final filled = starIndex <= _display;

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onRatingChanged(starIndex);
              },
              child: MouseRegion(
                onEnter: (_) => setState(() => _hovered = starIndex),
                onExit: (_) => setState(() => _hovered = 0),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
                  child: _AnimatedStar(
                    filled: filled,
                    size: widget.starSize,
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 12),

        // ── Label ─────────────────────────────────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            _display > 0 ? _labels[_display] : 'Tap to rate',
            key: ValueKey(_display),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _display > 0
                  ? _labelColors[_display]
                  : AppColors.textLight,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ANIMATED STAR
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedStar extends StatefulWidget {
  final bool filled;
  final double size;

  const _AnimatedStar({required this.filled, required this.size});

  @override
  State<_AnimatedStar> createState() => _AnimatedStarState();
}

class _AnimatedStarState extends State<_AnimatedStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_AnimatedStar old) {
    super.didUpdateWidget(old);
    if (old.filled != widget.filled) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (_, __) => Transform.scale(
        scale: _scaleAnim.value,
        child: Icon(
          widget.filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: widget.size,
          color: widget.filled
              ? AppColors.primaryOrange
              : AppColors.textLight,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  READ-ONLY DISPLAY VARIANT (for showing a stored rating)
//  Usage:
//    StarRatingDisplay(rating: 4, size: 16)
// ─────────────────────────────────────────────────────────────────────────────

class StarRatingDisplay extends StatelessWidget {
  final int rating;
  final double size;
  final double spacing;

  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 16,
    this.spacing = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = (i + 1) <= rating;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: filled ? AppColors.primaryOrange : AppColors.textLight,
          ),
        );
      }),
    );
  }
}