// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/features/payment/payment_screen.dart
//
//  Step 3 of the booking flow — Stripe PaymentSheet checkout.
//  All backend logic is unchanged. Manual card form removed (Stripe handles it).
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../core/app_colors.dart';
import '../../models/payment_model.dart';
import '../booking/booking_success_screen.dart';
import 'widgets/payment_summary_card.dart';
import 'widgets/payment_price_card.dart';
import 'widgets/payment_confirm_button.dart';

// ─────────────────────────────────────────────────────────────────────────────

class PaymentScreen extends StatefulWidget {
  final String bookingId;
  final String apartmentName;
  final String apartmentImage;
  final String apartmentAddress;
  final double stayTotal;
  final double serviceFee;
  final double securityDeposit;
  final double totalPrice;

  const PaymentScreen({
    super.key,
    required this.bookingId,
    required this.apartmentName,
    required this.apartmentImage,
    required this.apartmentAddress,
    required this.stayTotal,
    required this.serviceFee,
    required this.securityDeposit,
    required this.totalPrice,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

// ─────────────────────────────────────────────────────────────────────────────

class _PaymentScreenState extends State<PaymentScreen> {
  bool _loading = false;
  String _pricingMode = 'daily';

  @override
  void initState() {
    super.initState();
    _loadPricingMode();
  }

  Future<void> _loadPricingMode() async {
    final snap = await FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .get();

    if (!snap.exists) return;

    final data = snap.data()!;
    setState(() {
      _pricingMode = data['pricingMode'] ?? 'daily';
    });
  }
  // ══════════════════════════════════════════════════════════════════════════
  //  STRIPE — initialise PaymentSheet via Cloud Function
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _startStripePayment(double amount) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('createPaymentIntent')
        .call({'amount': (amount * 100).toInt()});

    final clientSecret = result.data['clientSecret'] as String;

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        merchantDisplayName: 'StayNear',
        paymentIntentClientSecret: clientSecret,
      ),
    );

    try {
  await Stripe.instance.presentPaymentSheet();
} on StripeException catch (e) {
  throw Exception("Payment cancelled");
}
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CONFIRM & PAY — unchanged backend logic
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _confirmAndPay() async {
    setState(() => _loading = true);

    try {
      // 1. Stripe PaymentSheet
final bookingRef = FirebaseFirestore.instance
    .collection('bookings')
    .doc(widget.bookingId);

// Fetch booking data
final bookingSnap = await bookingRef.get();
if (!bookingSnap.exists) throw Exception('Booking document not found.');

final data = bookingSnap.data()!;

// Pricing mode
final String pricingMode = data['pricingMode'] ?? 'daily';

final double monthlyPrice = (data['priceMonthly'] ?? 0).toDouble();

// Calculate correct payment
double amountToCharge;

if (pricingMode == 'monthly') {
  // First month + deposit
  amountToCharge = monthlyPrice + widget.securityDeposit;
} else {
  // Daily = pay full stay
  amountToCharge = widget.totalPrice;
}

// Now start Stripe payment
await _startStripePayment(amountToCharge);

      // 3. Update booking status
      await bookingRef.update({
        'amountPaid': FieldValue.increment(amountToCharge),
        'remainingBalance': pricingMode == 'monthly'
    ? FieldValue.increment(-(monthlyPrice))
    : 0,
        'paymentStatus': 'partial',
        'bookingStatus': 'confirmed',
        'paidAt': Timestamp.now(),
      });

      // 4. Write payment history
      final payment = PaymentModel(
        bookingId: widget.bookingId,
        amount: amountToCharge,
        method: 'card',
        status: 'success',
        createdAt: DateTime.now(),
      );
      await FirebaseFirestore.instance
          .collection('payments')
          .add(payment.toMap());

      // 5. Create room occupancy record
      await FirebaseFirestore.instance.collection('room_occupancy').add({
        'bookingId': widget.bookingId,
        'apartmentId': data['apartmentId'],
        'apartmentName': data['apartmentName'],
        'roomId': data['roomId'],
        'roomType': data['roomName'],
        'checkIn': data['checkIn'],
        'hostId': data['hostId'],
        'checkOut': data['checkOut'],
        'pricingMode': data['pricingMode'],
        'guestName': data['guestName'],
        'guestEmail': data['guestEmail'],
        'guestId': data['userId'],
        'status': 'occupied',
        'createdAt': Timestamp.now(),
      });

      // 6. Reduce available units
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(data['apartmentId'])
          .collection('rooms')
          .doc(data['roomId'])
          .update({'availableUnits': FieldValue.increment(-1)});

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              BookingSuccessScreen(guestEmail: data['guestEmail'] ?? ''),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          // ── Scrollable content ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProgressStepper(activeStep: 2),
                  const SizedBox(height: 24),

                  PaymentSummaryCard(
                    name: widget.apartmentName,
                    imageUrl: widget.apartmentImage,
                    address: widget.apartmentAddress,
                    totalPrice: widget.totalPrice,
                  ),
                  const SizedBox(height: 16),

                  PaymentPriceCard(
  stayTotal: widget.stayTotal,
  serviceFee: widget.serviceFee,
  securityDeposit: widget.securityDeposit,
  grandTotal: widget.totalPrice,
),

if (_pricingMode == 'monthly') ...[
  const SizedBox(height: 12),
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.orangeLight.withOpacity(.25),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppColors.primaryOrange.withOpacity(.25),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: AppColors.primaryOrange,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "You only need to pay the first month's rent today. "
            "The remaining balance will be paid monthly during your stay.",
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.text(context),
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  ),
],

const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Sticky CTA ──────────────────────────────────────────────
          PaymentConfirmButton(
            loading: _loading,
            onTap: _confirmAndPay,
            totalPrice: widget.totalPrice,
          ),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background(context),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leadingWidth: 60,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.only(left: 16),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: AppColors.text(context),
          ),
        ),
      ),
      centerTitle: true,
      title: Text(
        'Payment',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppColors.text(context),
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.orangeLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: const [
              Icon(Icons.lock_rounded,
                  size: 12, color: AppColors.primaryOrange),
              SizedBox(width: 4),
              Text(
                'Secure',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryOrange,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROGRESS STEPPER  (self-contained, no external deps)
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressStepper extends StatelessWidget {
  final int activeStep;
  const _ProgressStepper({required this.activeStep});

  static const _steps = [
    _Step(label: 'Your\nSelection', number: 1),
    _Step(label: 'Payment\nMethod', number: 2),
    _Step(label: 'Finish\nBooking', number: 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        // Connector line
        if (i.isOdd) {
          final lineActive = (i ~/ 2) + 1 < activeStep;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: lineActive
                    ? AppColors.primaryOrange
                    : AppColors.border,
              ),
            ),
          );
        }

        final step = _steps[i ~/ 2];
        final isActive = step.number == activeStep;
        final isPast = step.number < activeStep;

        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppColors.primaryOrange
                    : isPast
                        ? AppColors.primaryOrange.withOpacity(.18)
                        : AppColors.card(context),
                border: Border.all(
                  color: isActive || isPast
                      ? AppColors.primaryOrange
                      : AppColors.border,
                  width: 2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primaryOrange.withOpacity(.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : [],
              ),
              child: Center(
                child: isPast
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: AppColors.primaryOrange)
                    : Text(
                        '${step.number}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isActive
                              ? Colors.white
                              : AppColors.textMid,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              step.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? AppColors.primaryOrange
                    : AppColors.textMid,
                height: 1.3,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _Step {
  final String label;
  final int number;
  const _Step({required this.label, required this.number});
}