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
  final String? apartmentImage;
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
    if (!mounted) return;
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
    } on StripeException {
      throw Exception("payment_cancelled");
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CONFIRM & PAY
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _confirmAndPay() async {
    const stripeKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
    if (stripeKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Stripe is not configured. Run the app with --dart-define=STRIPE_PUBLISHABLE_KEY=your_key.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 6),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId);

      // Fetch latest booking data
      final bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) throw Exception('Booking document not found.');

      final data = bookingSnap.data()!;

      // ── Duplicate-payment guard ─────────────────────────────────────────
      final currentBookingStatus = (data['bookingStatus'] ?? '').toString();
      final currentPaymentStatus = (data['paymentStatus'] ?? '').toString();
      if (currentBookingStatus == 'confirmed' || currentPaymentStatus == 'paid') {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This booking has already been paid.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      // Pricing mode
      final String pricingMode = data['pricingMode'] ?? 'daily';
      final double monthlyPrice = (data['priceMonthly'] ?? 0).toDouble();

      // DEMO/CAPSTONE MODE: PaymentSheet confirms on the client, then the app
      // records booking/payment side effects below. Production should move these
      // writes to a trusted backend or Stripe webhook.
      final double amountToCharge = widget.totalPrice;

      // ── Stripe — early return on cancellation, no Firestore writes ───────
      try {
        await _startStripePayment(amountToCharge);
      } catch (e) {
        if (mounted) setState(() => _loading = false);
        if (!mounted) return;
        if (!e.toString().contains('payment_cancelled')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_paymentErrorMessage(e)),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      // ── Validate doc path fields before building refs ────────────────────
      final apartmentId = data['apartmentId'] as String?;
      final roomId = data['roomId'] as String?;
      if (apartmentId == null || apartmentId.isEmpty) {
        throw Exception('Missing apartmentId on booking.');
      }
      if (roomId == null || roomId.isEmpty) {
        throw Exception('Missing roomId on booking.');
      }

      // ── Pre-allocate refs so WriteBatch can use .set() ──────────────────
      final paymentRef =
          FirebaseFirestore.instance.collection('payments').doc();
      final occupancyRef =
          FirebaseFirestore.instance.collection('room_occupancy').doc();
      final roomRef = FirebaseFirestore.instance
          .collection('properties')
          .doc(apartmentId)
          .collection('rooms')
          .doc(roomId);

      // ── WriteBatch: all 4 core writes land atomically ───────────────────
      final batch = FirebaseFirestore.instance.batch();

      // 1. Update booking status
      //
      // remainingBalance formula (monthly):
      //   starts at  stayTotal = priceMonthly × months       (e.g. ₱6,170 for 5 months)
      //   after here = stayTotal − priceMonthly               (e.g. ₱4,936)
      //   ↳ security deposit + service fee are NOT subtracted — they are one-time fees
      //     already included in totalDueToday but not in the rent balance.
      //
      // paymentStatus is derived from the NEW remaining balance, not hardcoded,
      // so a 1-month booking (newRemaining == 0) correctly becomes "paid".
      final currentRemaining = pricingMode == 'monthly'
          ? ((data['remainingBalance'] as num?) ?? 0.0).toDouble()
          : 0.0;
      final newRemaining = pricingMode == 'monthly'
          ? (currentRemaining - monthlyPrice).clamp(0.0, double.infinity)
          : 0.0;
      final newPaymentStatus = newRemaining <= 0 ? 'paid' : 'partial';

      batch.update(bookingRef, {
        'amountPaid': FieldValue.increment(amountToCharge),
        'remainingBalance': pricingMode == 'monthly'
            ? FieldValue.increment(-monthlyPrice)
            : 0,
        'paymentStatus': newPaymentStatus,
        'bookingStatus': 'confirmed',
        'paidAt': Timestamp.now(),
      });

      // 2. Write payment record
      final payment = PaymentModel(
        bookingId:  widget.bookingId,
        userId:     (data['userId']      as String?) ?? '',
        hostId:     (data['hostId']      as String?) ?? '',
        propertyId: (data['apartmentId'] as String?) ?? '',
        amount:     amountToCharge,
        method:     'card',
        status:     'success',
        createdAt:  DateTime.now(),
      );
      batch.set(paymentRef, payment.toMap());

      // 3. Create room occupancy record
      batch.set(occupancyRef, {
        'bookingId':     widget.bookingId,
        'apartmentId':   data['apartmentId'],
        'apartmentName': data['apartmentName'],
        'roomId':        data['roomId'],
        'roomType':      data['roomName'],
        'checkIn':       data['checkIn'],
        'hostId':        data['hostId'],
        'checkOut':      data['checkOut'],
        'pricingMode':   data['pricingMode'],
        'guestName':     data['guestName'],
        'guestEmail':    data['guestEmail'],
        'guestId':       data['userId'],
        'status':        'occupied',
        'createdAt':     Timestamp.now(),
      });

      // 4. Decrement available units
      batch.update(roomRef, {'availableUnits': FieldValue.increment(-1)});

      await batch.commit();

      // ── Conversation update — kept separate (requires a query) ──────────
      final convoSnap = await FirebaseFirestore.instance
          .collection('conversations')
          .where('bookingId', isEqualTo: widget.bookingId)
          .where('userId', isEqualTo: data['userId'])
          .limit(1)
          .get();

      if (convoSnap.docs.isNotEmpty) {
        await convoSnap.docs.first.reference.update({
          'paymentId': paymentRef.id,
        });
      }

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
          content: Text(_paymentErrorMessage(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _paymentErrorMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unauthenticated':
          return "Please sign in again before paying.";
        case 'invalid-argument':
          return "Payment amount is invalid. Please refresh and try again.";
        case 'unavailable':
        case 'deadline-exceeded':
          return "Payment service is temporarily unavailable. Please try again.";
        default:
          return "Could not start payment. Please try again.";
      }
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return "Payment could not be saved because booking access changed. If you were charged, contact support.";
        case 'unavailable':
        case 'deadline-exceeded':
          return "Could not save payment details. Please check your connection and try again.";
        default:
          return "Could not finish updating your booking. Please try again.";
      }
    }

    if (error.toString().contains('payment_cancelled')) {
      return "Payment was cancelled.";
    }

    return "Payment could not be completed. Please try again.";
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
