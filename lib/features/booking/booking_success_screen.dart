// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/features/booking/booking_success_screen.dart
//
//  Final step of the booking flow — success confirmation.
//  Stepper shows all 3 steps completed. Navigation logic unchanged.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../home/main_shell.dart';

class BookingSuccessScreen extends StatefulWidget {
  final String guestEmail;

  const BookingSuccessScreen({
    super.key,
    required this.guestEmail,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );

    // Slight delay so the screen settles before animating
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarBrightness: Theme.of(context).brightness == Brightness.dark
          ? Brightness.dark
          : Brightness.light,
    ));

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 28),

              // ── Step indicator (all complete) ─────────────────────
              _CompletedStepper(),

              const Spacer(flex: 2),

              // ── Animated success icon ─────────────────────────────
              ScaleTransition(
                scale: _scaleAnim,
                child: _SuccessIcon(),
              ),

              const SizedBox(height: 28),

              // ── Headline + subtitle ───────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    Text(
                      "You're all set! 🎉",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text(context),
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Your booking is confirmed.\nGet ready for an amazing stay!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: AppColors.textMid,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Email confirmation card ───────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: _EmailConfirmCard(email: widget.guestEmail),
              ),

              const Spacer(flex: 3),

              // ── CTA button ────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: _GoHomeButton(
                  onTap: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (route) => false,
                  ),
                ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  COMPLETED STEPPER  — mirrors the style in PaymentScreen, all 3 done
// ─────────────────────────────────────────────────────────────────────────────

class _CompletedStepper extends StatelessWidget {
  static const _labels = [
    'Your\nSelection',
    'Payment\nMethod',
    'Finish\nBooking',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length * 2 - 1, (i) {
        // Connector line — all active
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: AppColors.primaryOrange,
              ),
            ),
          );
        }

        final index = i ~/ 2;
        final label = _labels[index];

        return Column(
          children: [
            // All steps show check mark (completed)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryOrange,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.check_rounded,
                    size: 16, color: Colors.white),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryOrange,
                height: 1.3,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUCCESS ICON
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryOrange.withOpacity(.08),
          ),
        ),
        // Inner filled circle
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryOrange.withOpacity(.15),
            border: Border.all(
              color: AppColors.primaryOrange.withOpacity(.3),
              width: 2,
            ),
          ),
        ),
        // Icon
        Container(
          width: 66,
          height: 66,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryOrange,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 36,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMAIL CONFIRMATION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _EmailConfirmCard extends StatelessWidget {
  final String email;
  const _EmailConfirmCard({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mail icon badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.orangeLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              size: 20,
              color: AppColors.primaryOrange,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Itinerary sent to',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  GO HOME BUTTON  — matches PaymentConfirmButton gradient style
// ─────────────────────────────────────────────────────────────────────────────

class _GoHomeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoHomeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8C00), AppColors.primaryOrange],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(.38),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.home_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Back to Home',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}