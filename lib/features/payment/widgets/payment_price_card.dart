// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/features/payment/widgets/payment_price_card.dart
//  Itemised price breakdown card.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

class PaymentPriceCard extends StatelessWidget {
  final double stayTotal;
  final double serviceFee;
  final double securityDeposit;
  final double grandTotal;

  const PaymentPriceCard({
    super.key,
    required this.stayTotal,
    required this.serviceFee,
    required this.securityDeposit,
    required this.grandTotal,
  });

  String _fmt(double v) => v
      .toInt()
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Text(
            'Price Details',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.text(context),
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 16),

          // ── Line items ────────────────────────────────────────────
          _PriceRow(label: 'Stay total',       value: '₱${_fmt(stayTotal)}'),
          const SizedBox(height: 10),
          _PriceRow(label: 'Security deposit', value: '₱${_fmt(securityDeposit)}'),
          const SizedBox(height: 10),
          _PriceRow(label: 'Service fee',      value: '₱${_fmt(serviceFee)}'),

          const SizedBox(height: 16),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // ── Grand total ───────────────────────────────────────────
          Row(
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text(context),
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Text(
                '₱${_fmt(grandTotal)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryOrange,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  const _PriceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 13.5, color: AppColors.textMid),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
          ),
        ],
      );
}