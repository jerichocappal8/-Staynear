// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/features/bookings/advance_payment_page.dart
//
//  Architecture:
//  ┌─────────────────────────────────────────────────────────────────────┐
//  │  AdvancePaymentPage (StatefulWidget)                                │
//  │  └─ loads booking doc from Firestore on initState                  │
//  │  └─ builds payment options dynamically from remainingBalance        │
//  │  └─ calls your backend to create a PaymentIntent                   │
//  │  └─ presents Stripe PaymentSheet                                    │
//  │  └─ on success → updates Firestore atomically via transaction       │
//  │                                                                     │
//  │  Sub-widgets (stateless, reusable):                                 │
//  │    PaymentHeaderCard   — shows monthly price + months remaining     │
//  │    PaymentOptionsCard  — radio list of month options                │
//  │    PaymentSummaryCard  — remaining balance + stay total             │
//  │    PaymentActionButton — sticky CTA with loading state              │
//  └─────────────────────────────────────────────────────────────────────┘
//
//  Dependencies (add to pubspec.yaml):
//    flutter_stripe: ^10.x
//    cloud_firestore: ^4.x
//    firebase_auth: ^4.x
//    http: ^1.x
// ════════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../core/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PAYMENT OPTION MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentOption {
  final String label;
  final String sublabel;
  final double amount;
  final bool isFull;

  const _PaymentOption({
    required this.label,
    required this.sublabel,
    required this.amount,
    this.isFull = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN PAGE
// ─────────────────────────────────────────────────────────────────────────────

class AdvancePaymentPage extends StatefulWidget {
  final String bookingId;

  const AdvancePaymentPage({
    super.key,
    required this.bookingId,
  });

  @override
  State<AdvancePaymentPage> createState() => _AdvancePaymentPageState();
}

class _AdvancePaymentPageState extends State<AdvancePaymentPage>
    with SingleTickerProviderStateMixin {

  // ── Firestore data ────────────────────────────────────────────────────────
  Map<String, dynamic>? _bookingData;
  bool _dataLoading = true;
  String? _dataError;

  // ── Payment options ───────────────────────────────────────────────────────
  List<_PaymentOption> _options = [];
  int _selectedIndex = 0;

  // ── Payment state ─────────────────────────────────────────────────────────
  bool _paying = false;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ─────────────────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _loadBooking();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  DATA LOADING
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadBooking() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();

      if (!doc.exists || !mounted) return;

      final data = doc.data()!;
      _buildOptions(data);

      setState(() {
        _bookingData = data;
        _dataLoading = false;
      });

      _fadeCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dataError = e.toString();
        _dataLoading = false;
      });
    }
  }

  void _buildOptions(Map<String, dynamic> data) {
    final priceMonthly =
        ((data['priceMonthly'] as num?) ?? 0).toDouble();
    final remaining =
        ((data['remainingBalance'] as num?) ?? 0).toDouble();

    if (priceMonthly <= 0) return;

    final monthsRemaining = (remaining / priceMonthly).floor();
    final opts = <_PaymentOption>[];

    for (int m = 1; m <= monthsRemaining; m++) {
      final amount = priceMonthly * m;
      final isFull = amount >= remaining;

      opts.add(_PaymentOption(
        label: m == 1 ? '1 Month' : '$m Months',
        sublabel: isFull ? 'Clears full balance' : _fmtPrice(amount),
        amount: isFull ? remaining : amount,
        isFull: isFull,
      ));

      // Stop adding once we reach the full balance
      if (isFull) break;
    }

    // Safety: if remainingBalance isn't a perfect multiple of priceMonthly,
    // make sure "Full Balance" is always the last option.
    if (opts.isNotEmpty && !opts.last.isFull) {
      opts.add(_PaymentOption(
        label: 'Full Balance',
        sublabel: 'Clears full balance',
        amount: remaining,
        isFull: true,
      ));
    }

    _options = opts;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  STRIPE PAYMENT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handlePay() async {
    if (_paying || _options.isEmpty) return;

    setState(() => _paying = true);

    try {
      final selected = _options[_selectedIndex];
      final amountCents = (selected.amount * 100).round();

      // ── 1. Create PaymentIntent on your backend ──────────────────────
      //    Replace with your actual endpoint URL.
      final result = await FirebaseFunctions.instance
    .httpsCallable('createPaymentIntent')
    .call({
      'amount': amountCents,
    });

final clientSecret = result.data['clientSecret'];
      // ── 2. Init PaymentSheet ─────────────────────────────────────────
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'StayNear',
          style: ThemeMode.dark,
          // ── Stripe PaymentSheet colors are NOT modified per rules ─────
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: AppColors.primaryOrange,
              background: AppColors.darkBackground,
              componentBackground: AppColors.darkCard,
              componentText: Colors.white,
              placeholderText: AppColors.textLight,
              icon: AppColors.primaryOrange,
              secondaryText: AppColors.textMid,
              componentBorder: AppColors.darkCardSoft,
              componentDivider: AppColors.darkCardSoft,
              primaryText: Colors.white,
            ),
            shapes: PaymentSheetShape(
              borderRadius: 16,
              borderWidth: 1,
            ),
          ),
        ),
      );

      // ── 3. Present PaymentSheet ──────────────────────────────────────
      await Stripe.instance.presentPaymentSheet();

      // ── 4. Payment succeeded — update Firestore ──────────────────────
      await _updateFirestore(selected.amount);

      if (!mounted) return;
      _showSuccessDialog(selected.amount);
    } on StripeException catch (e) {
      if (!mounted) return;
      // User cancelled — silently dismiss
      if (e.error.code == FailureCode.Canceled) {
        setState(() => _paying = false);
        return;
      }
      _showErrorSnack(e.error.localizedMessage ?? 'Payment failed');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack(e.toString());
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

Future<void> _updateFirestore(double amountPaid) async {

  final bookingRef = FirebaseFirestore.instance
      .collection('bookings')
      .doc(widget.bookingId);

  final paymentsRef =
      FirebaseFirestore.instance.collection('payments');

  final paymentDoc = paymentsRef.doc();

  // ── transaction ─────────────────────────
  await FirebaseFirestore.instance.runTransaction((tx) async {

    final snap = await tx.get(bookingRef);
    final current = snap.data()!;

    final prevAmountPaid =
        ((current['amountPaid'] as num?) ?? 0).toDouble();

    final prevRemaining =
        ((current['remainingBalance'] as num?) ?? 0).toDouble();

    final newAmountPaid = prevAmountPaid + amountPaid;

    final newRemaining =
        (prevRemaining - amountPaid).clamp(0.0, double.infinity);

    final newStatus = newRemaining <= 0 ? 'paid' : 'partial';

    // update booking
    tx.update(bookingRef, {
      'amountPaid': newAmountPaid,
      'remainingBalance': newRemaining,
      'paymentStatus': newStatus,
    });

    // create payment
    tx.set(paymentDoc, {
      'amount': amountPaid,
      'bookingId': widget.bookingId,
      'apartmentName': current['apartmentName'],
      'method': 'card',
      'status': 'success',
      'createdAt': FieldValue.serverTimestamp(),
    });

  });

  // ── attach payment to chat conversation ──
  final convoSnap = await FirebaseFirestore.instance
      .collection("conversations")
      .where("bookingId", isEqualTo: widget.bookingId)
      .limit(1)
      .get();

  if (convoSnap.docs.isNotEmpty) {
    await convoSnap.docs.first.reference.update({
      "paymentId": paymentDoc.id,
    });
  }
}

  // ─────────────────────────────────────────────────────────────────────────
  //  DIALOGS & SNACKS
  // ─────────────────────────────────────────────────────────────────────────

  void _showSuccessDialog(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessDialog(
        amount: amount,
        onDone: () {
          Navigator.pop(context); // close dialog
          Navigator.pop(context); // go back to booking detail
        },
      ),
    );
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  static String _fmtPrice(double v) =>
      '₱${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context), // was: AppColors.darkBackground
      body: _dataLoading
          ? const _LoadingBody()
          : _dataError != null
              ? _ErrorBody(error: _dataError!)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final data = _bookingData!;
    final priceMonthly =
        ((data['priceMonthly'] as num?) ?? 0).toDouble();
    final remaining =
        ((data['remainingBalance'] as num?) ?? 0).toDouble();
    final stayTotal =
        ((data['stayTotal'] as num?) ?? 0).toDouble();
    final selectedAmount =
        _options.isNotEmpty ? _options[_selectedIndex].amount : 0.0;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          // ── Scrollable body ──────────────────────────────────────────
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App bar
                SliverAppBar(
                  pinned: true,
                  backgroundColor: AppColors.background(context), // was: AppColors.darkBackground
                  leading: _NavBackButton(),
                  title: Text(
                    'Advance Payment',
                    style: TextStyle(
                      color: AppColors.text(context), // was: Colors.white
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  centerTitle: true,
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      PaymentHeaderCard(
                        priceMonthly: priceMonthly,
                        monthsRemaining:
                            priceMonthly > 0 ? (remaining / priceMonthly).ceil() : 0,
                      ),
                      const SizedBox(height: 16),
                      PaymentOptionsCard(
                        options: _options,
                        selectedIndex: _selectedIndex,
                        onSelect: (i) => setState(() => _selectedIndex = i),
                        fmtPrice: _fmtPrice,
                      ),
                      const SizedBox(height: 16),
                      PaymentSummaryCard(
                        remaining: remaining,
                        stayTotal: stayTotal,
                        selectedAmount: selectedAmount,
                        fmtPrice: _fmtPrice,
                      ),
                      const SizedBox(height: 16),
                      _SecurityNote(),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // ── Sticky pay button ─────────────────────────────────────────
          PaymentActionButton(
            amount: selectedAmount,
            paying: _paying,
            fmtPrice: _fmtPrice,
            onTap: _handlePay,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAYMENT HEADER CARD
//  Colors.white kept — all text lives inside an orange gradient container
// ─────────────────────────────────────────────────────────────────────────────

class PaymentHeaderCard extends StatelessWidget {
  final double priceMonthly;
  final int monthsRemaining;

  const PaymentHeaderCard({
    super.key,
    required this.priceMonthly,
    required this.monthsRemaining,
  });

  static String _fmt(double v) =>
      '₱${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8C00), Color(0xFFF5A623)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text side
          Expanded(
  child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Monthly Rate',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white, // kept: inside orange gradient card
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _fmt(priceMonthly),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white, // kept: inside orange gradient card
                    letterSpacing: -1.0,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'per month',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.80), // kept: inside orange gradient card
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Months pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: Colors.white.withOpacity(0.25), width: 1),
            ),
            child: Column(
              children: [
                Text(
                  '$monthsRemaining',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white, // kept: inside orange gradient card
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  monthsRemaining == 1 ? 'month\nleft' : 'months\nleft',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.85), // kept: inside orange gradient card
                    fontWeight: FontWeight.w600,
                    height: 1.3,
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
//  PAYMENT OPTIONS CARD
// ─────────────────────────────────────────────────────────────────────────────

class PaymentOptionsCard extends StatelessWidget {
  final List<_PaymentOption> options;
  final int selectedIndex;
  final void Function(int) onSelect;
  final String Function(double) fmtPrice;

  const PaymentOptionsCard({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
    required this.fmtPrice,
  });

  @override
  Widget build(BuildContext context) {
    return _DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.tune_rounded,
            title: 'Payment Options',
            subtitle: 'Choose how much to pay',
          ),
          const SizedBox(height: 16),
          ...List.generate(options.length, (i) {
            final opt = options[i];
            final isSelected = i == selectedIndex;
            return _OptionTile(
              option: opt,
              isSelected: isSelected,
              isLast: i == options.length - 1,
              fmtPrice: fmtPrice,
              onTap: () => onSelect(i),
            );
          }),
        ],
      ),
    );
  }
}

class _OptionTile extends StatefulWidget {
  final _PaymentOption option;
  final bool isSelected;
  final bool isLast;
  final String Function(double) fmtPrice;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.isLast,
    required this.fmtPrice,
    required this.onTap,
  });

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim =
        Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opt = widget.option;
    final isSelected = widget.isSelected;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.only(bottom: widget.isLast ? 0 : 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryOrange.withOpacity(0.12)
                : AppColors.cardSoft(context).withOpacity(0.5), // was: AppColors.darkCardSoft.withOpacity(0.5)
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryOrange
                  : AppColors.cardSoft(context), // was: AppColors.darkCardSoft
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // ── Custom radio ───────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryOrange
                        : AppColors.textLight,
                    width: isSelected ? 0 : 2,
                  ),
                  color: isSelected
                      ? AppColors.primaryOrange
                      : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white) // kept: icon on filled orange circle
                    : null,
              ),
              const SizedBox(width: 14),

              // ── Label ─────────────────────────────────────────────
              Flexible(
  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(
  children: [
    Text(
      opt.label,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: isSelected
            ? AppColors.primaryOrange
            : AppColors.text(context), // was: Colors.white
      ),
    ),
    if (opt.isFull) ...[
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryOrange.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'CLEARS DEBT',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryOrange,
            letterSpacing: 0.4,
          ),
        ),
      ),
    ],
  ],
),
                    const SizedBox(height: 2),
                    Text(
                      opt.sublabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? AppColors.primaryOrange.withOpacity(0.75)
                            : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Amount ────────────────────────────────────────────
              Text(
                widget.fmtPrice(opt.amount),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? AppColors.primaryOrange
                      : AppColors.text(context), // was: Colors.white
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAYMENT SUMMARY CARD
// ─────────────────────────────────────────────────────────────────────────────

class PaymentSummaryCard extends StatelessWidget {
  final double remaining;
  final double stayTotal;
  final double selectedAmount;
  final String Function(double) fmtPrice;

  const PaymentSummaryCard({
    super.key,
    required this.remaining,
    required this.stayTotal,
    required this.selectedAmount,
    required this.fmtPrice,
  });

  @override
  Widget build(BuildContext context) {
    final afterPayment = (remaining - selectedAmount).clamp(0.0, double.infinity);

    return _DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.receipt_long_rounded,
            title: 'Summary',
          ),
          const SizedBox(height: 16),

          _SummaryRow(
            label: 'Total Stay Cost',
            value: fmtPrice(stayTotal),
            valueColor: AppColors.text(context), // was: Colors.white
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Remaining Balance',
            value: fmtPrice(remaining),
            valueColor: AppColors.danger,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'You\'re paying',
            value: fmtPrice(selectedAmount),
            valueColor: AppColors.primaryOrange,
            bold: true,
          ),

          const SizedBox(height: 14),
          Divider(color: AppColors.cardSoft(context), height: 1), // was: const Divider(color: AppColors.darkCardSoft)
          const SizedBox(height: 14),

          _SummaryRow(
            label: 'Balance after payment',
            value: fmtPrice(afterPayment),
            valueColor: afterPayment <= 0
                ? const Color(0xFF34D399)
                : AppColors.text(context), // was: Colors.white
            bold: true,
          ),

          if (afterPayment <= 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF34D399).withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF34D399).withOpacity(0.30),
                ),
              ),
              child: Row(
                children: const [
                  Icon(Icons.celebration_rounded,
                      size: 16, color: Color(0xFF34D399)),
                  SizedBox(width: 8),
                  Text(
                    'This will fully settle your balance!',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.textMid,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 13.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAYMENT ACTION BUTTON (sticky bottom)
// ─────────────────────────────────────────────────────────────────────────────

class PaymentActionButton extends StatelessWidget {
  final double amount;
  final bool paying;
  final String Function(double) fmtPrice;
  final VoidCallback onTap;

  const PaymentActionButton({
    super.key,
    required this.amount,
    required this.paying,
    required this.fmtPrice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.card(context), // was: AppColors.darkNavbar
        border: Border(
          top: BorderSide(color: AppColors.cardSoft(context), width: 1), // was: AppColors.darkCardSoft
        ),
      ),
      child: GestureDetector(
        onTap: paying ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            gradient: paying
                ? null
                : const LinearGradient(
                    colors: [Color(0xFFFF8C00), Color(0xFFF5A623)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: paying ? AppColors.cardSoft(context) : null, // was: AppColors.darkCardSoft
            borderRadius: BorderRadius.circular(18),
            boxShadow: paying
                ? []
                : [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.40),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: paying
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
                      const Icon(Icons.lock_rounded,
                          size: 16, color: Colors.white), // kept: inside gradient button
                      const SizedBox(width: 8),
                      Text(
                        'Pay ${fmtPrice(amount)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white, // kept: inside gradient button
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
//  SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _DarkCard extends StatelessWidget {
  final Widget child;
  const _DarkCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context), // was: AppColors.darkCard
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardSoft(context), width: 1), // was: AppColors.darkCardSoft
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _CardTitle({
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
                color: AppColors.text(context), // was: Colors.white
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

class _SecurityNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.verified_user_rounded, size: 13, color: AppColors.textLight),
        SizedBox(width: 5),
        Text(
          'Secured by Stripe · 256-bit SSL encryption',
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.textLight,
          ),
        ),
      ],
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
            color: AppColors.card(context), // was: AppColors.darkCard
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardSoft(context)), // was: AppColors.darkCardSoft
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.text(context), // was: Colors.white
            size: 16,
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
  final double amount;
  final VoidCallback onDone;

  const _SuccessDialog({required this.amount, required this.onDone});

  static String _fmt(double v) =>
      '₱${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card(context), // was: AppColors.darkCard
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
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
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 36), // kept: icon inside gradient circle
            ),
            const SizedBox(height: 20),
            Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.text(context), // was: Colors.white
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_fmt(amount)} has been applied\nto your booking.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textMid,
                height: 1.5,
              ),
            ),
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
                ),
                child: const Center(
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white, // kept: inside gradient button
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
//  LOADING & ERROR BODIES
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primaryOrange,
        strokeWidth: 2.5,
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String error;
  const _ErrorBody({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              'Failed to load booking',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(context)), // was: Colors.white
            ),
            const SizedBox(height: 8),
            Text(error,
                style: const TextStyle(fontSize: 12, color: AppColors.textMid),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}