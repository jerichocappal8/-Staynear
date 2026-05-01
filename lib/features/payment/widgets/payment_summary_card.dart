// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/features/payment/widgets/payment_summary_card.dart
//  Property summary card shown at the top of the payment screen.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

class PaymentSummaryCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String address;
  final double totalPrice;

  const PaymentSummaryCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.address,
    required this.totalPrice,
  });

  String _fmt(double v) => v
      .toInt()
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Property image ──────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: imageUrl?.isNotEmpty ?? false
                ? Image.network(
                    imageUrl ?? '',
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(context),
                  )
                : _fallback(context),
          ),

          const SizedBox(width: 14),

          // ── Property info ───────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Badge(label: 'Booking Summary'),
                const SizedBox(height: 8),

                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text(context),
                    height: 1.2,
                    letterSpacing: -0.2,
                  ),
                ),

                const SizedBox(height: 4),

                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 12, color: AppColors.textLight),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: '₱${_fmt(totalPrice)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryOrange,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const TextSpan(
                      text: ' total',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMid),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(BuildContext context) => Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.apartment_rounded,
            size: 32, color: AppColors.textLight),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pay-with-card section — replaces the removed manual card form.
//  Stripe PaymentSheet handles all card input natively.
// ─────────────────────────────────────────────────────────────────────────────

class PayWithCardSection extends StatelessWidget {
  const PayWithCardSection({super.key});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.text(context),
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 14),

          // ── Selected method tile ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primaryOrange, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.orangeLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.credit_card_rounded,
                      size: 20, color: AppColors.primaryOrange),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debit / Credit Card',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Visa, Mastercard, and more — via Stripe',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMid),
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.check_circle_rounded,
                    size: 18, color: AppColors.primaryOrange),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Security note ───────────────────────────────────────────
          Row(
            children: const [
              Icon(Icons.shield_outlined,
                  size: 14, color: AppColors.textMid),
              SizedBox(width: 6),
              Text(
                'Your payment is encrypted & processed by Stripe',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMid),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED SHELL
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.055),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryOrange,
        ),
      ),
    );
  }
}