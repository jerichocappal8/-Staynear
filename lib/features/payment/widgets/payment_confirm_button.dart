// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/features/payment/widgets/payment_confirm_button.dart
//  Sticky bottom CTA — triggers _confirmAndPay() in the parent screen.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

class PaymentConfirmButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  final double totalPrice;

  const PaymentConfirmButton({
    super.key,
    required this.loading,
    required this.onTap,
    required this.totalPrice,
  });

  String _fmt(double v) => v
      .toInt()
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Amount reminder ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_rounded,
                    size: 13, color: AppColors.textMid),
                const SizedBox(width: 5),
                Text(
                  'You will be charged ₱${_fmt(totalPrice)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMid),
                ),
              ],
            ),
          ),

          // ── CTA button ──────────────────────────────────────────────
          GestureDetector(
            onTap: loading ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: loading
                    ? null
                    : const LinearGradient(
                        colors: [
                          Color(0xFFFF8C00),
                          AppColors.primaryOrange
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                color: loading ? AppColors.border : null,
                boxShadow: loading
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.primaryOrange.withOpacity(.38),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.lock_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Confirm & Pay',
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
          ),
        ],
      ),
    );
  }
}