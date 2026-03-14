// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/features/booking/checkout_screen.dart
//
//  Step 1 of the booking flow — Property selection summary & price breakdown.
//  Navigates to GuestInfoScreen (placeholder) on PROCEED.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_colors.dart';
import '../../models/room_offer.dart';
import '../../models/apartment_model.dart';
import '../guest/guest_info_screen.dart';
import '../../models/guest_info_model.dart';
import '../../models/booking_model.dart';
import '../payment/payment_screen.dart';
import 'dart:ui';
// ─────────────────────────────────────────────────────────────────────────────
//  LIGHTWEIGHT LOCAL MODELS
//  (Replace with your real model imports when integrating)
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
//  CHECKOUT SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CheckoutScreen extends StatefulWidget {
  final ApartmentModel apartment;
  final RoomOffer room;

  const CheckoutScreen({
    super.key,
    required this.apartment,
    required this.room,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {

  bool _creatingBooking = false;
  
  GuestInfoModel? guestInfo;

  // ── Price helpers ─────────────────────────────────────────
double get _serviceFee =>
    double.tryParse(widget.room.serviceFee.trim()) ?? 0;

double get _securityDeposit =>
    double.tryParse(widget.room.securityDeposit.trim()) ?? 0;

double get _roomBasePrice => widget.room.activePrice;
int get _stayDuration {
  if (guestInfo == null) return 0;

  final days = guestInfo!.checkOutDate
      .difference(guestInfo!.checkInDate)
      .inDays;

  if (widget.room.pricingMode == 'daily') {
    return days;
  } else {
    return (days / 30).round();
  }
}

  double get _stayTotal {

if (guestInfo == null) {
  return 0;
}

  final isDaily = widget.room.pricingMode == 'daily';

  if (isDaily) {

    final nights = guestInfo!.checkOutDate
        .difference(guestInfo!.checkInDate)
        .inDays;

    final priceDaily =
        double.tryParse(widget.room.priceDaily.trim()) ?? 0;

    return priceDaily * nights;

  } else {

final days = guestInfo!.checkOutDate
    .difference(guestInfo!.checkInDate)
    .inDays;

final months = (days / 30).round();

    final priceMonthly =
        double.tryParse(widget.room.priceMonthly.trim()) ?? 0;

    return priceMonthly * months;
  }
}

double get _totalDueToday {

  final isDaily = widget.room.pricingMode == 'daily';

  if (isDaily) {
    // daily bookings pay full stay
    return _stayTotal + _securityDeposit + _serviceFee;
  } else {
    // monthly bookings pay first month only
    return _roomBasePrice + _securityDeposit + _serviceFee;
  }

}

  String _fmt(double v) => v
      .toInt()
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  // ── Price helpers ───────────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

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
          // ── Scrollable content ────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProgressStepper(),
                  const SizedBox(height: 24),
                  _PropertyCard(apartment: widget.apartment, room: widget.room, fmt: _fmt),
                  const SizedBox(height: 18),
                  _InputDetailsCard(
  guestInfo: guestInfo,
  onEdit: () async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuestInfoScreen(
          room: widget.room,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        guestInfo = result;
      });
    }
  },
),

if (guestInfo != null) ...[
  const SizedBox(height: 18),
  _PriceDetailsCard(
  roomBasePrice: _roomBasePrice,
  stayDuration: _stayDuration,
  securityDeposit: _securityDeposit,
  serviceFee: _serviceFee,
  totalDueToday: _totalDueToday,
  pricingMode: widget.room.pricingMode,
  fmt: _fmt,
),
],

const SizedBox(height: 18),
_PoliciesRow(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Fixed bottom button ───────────────────────────────────────
          _ProceedButton(
  context: context,
  onTap: _createBooking,
)
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  APP BAR
  // ════════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background(context),
      elevation:       0,
      surfaceTintColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () {
  Navigator.of(context).pop();
},
        child: Container(
          margin: const EdgeInsets.only(left: 16),
          width:  38,
          height: 38,
          decoration: BoxDecoration(
            color:        AppColors.card(context),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: AppColors.border),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size:  16,
            color: AppColors.text(context),
          ),
        ),
      ),
      leadingWidth: 60,
      centerTitle:  true,
      title: Text(
        'Rent booking',
        style: TextStyle(
          fontSize:   17,
          fontWeight: FontWeight.w800,
          color:      AppColors.text(context),
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          width:  38,
          height: 38,
          decoration: BoxDecoration(
            color:        AppColors.card(context),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: AppColors.border),
          ),
          child: Icon(
            Icons.bookmark_border_rounded,
            size:  18,
            color: AppColors.text(context),
          ),
        ),
      ],
    );
  }
Future<void> _createBooking() async {

  if (_creatingBooking) return;

  setState(() {
    _creatingBooking = true;
  });

  if (guestInfo == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please complete guest info first")),
    );

    setState(() {
      _creatingBooking = false;
    });

    return;
  }

  final user = FirebaseAuth.instance.currentUser;
if (widget.room.id == null || widget.room.id!.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Room ID missing. Please try again.")),
  );

  setState(() {
    _creatingBooking = false;
  });

  return;
}
print("Creating booking...");
print("ApartmentId: ${widget.apartment.id}");
print("RoomId: ${widget.room.id}");
final booking = BookingModel(
  apartmentId: widget.apartment.id,
  apartmentName: widget.apartment.name,
  apartmentImage: widget.apartment.images.first,

  roomId: widget.room.id!,
  roomName: widget.room.roomType,

  userId: user!.uid,
  hostId: widget.apartment.ownerId, 
  guestName: "${guestInfo!.firstName} ${guestInfo!.lastName}",
  guestEmail: guestInfo!.email,

  checkIn: guestInfo!.checkInDate,
  checkOut: guestInfo!.checkOutDate,

  pricingMode: widget.room.pricingMode,
  priceMonthly: double.tryParse(widget.room.priceMonthly.trim()) ?? 0,

  monthsStayed: _stayDuration,
  stayTotal: _stayTotal,

  serviceFee: _serviceFee,
  securityDeposit: _securityDeposit,

  totalDueToday: _totalDueToday,
  totalPrice: _totalDueToday,

  amountPaid: 0,
  remainingBalance: _stayTotal,

  paymentStatus: "unpaid",
  bookingStatus: "pending",

  createdAt: DateTime.now(),
);

  final bookingRef = await FirebaseFirestore.instance
      .collection("bookings")
      .add(booking.toMap());
// ── attach booking to chat conversation ──
await FirebaseFirestore.instance
    .collection("conversations")
    .where("propertyId", isEqualTo: widget.apartment.id)
    .where("userId", isEqualTo: user.uid)
    .limit(1)
    .get()
    .then((snapshot) async {

  if (snapshot.docs.isNotEmpty) {

    final conversationId = snapshot.docs.first.id;

    await FirebaseFirestore.instance
        .collection("conversations")
        .doc(conversationId)
        .update({
      "bookingId": bookingRef.id,
    });

  }

});
  Navigator.of(context).push(
  PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => PaymentScreen(
      bookingId: bookingRef.id,
      apartmentName: widget.apartment.name,
      apartmentImage: widget.apartment.images.first,
      apartmentAddress: widget.apartment.address,
      stayTotal: _stayTotal,
      serviceFee: _serviceFee,
      securityDeposit: _securityDeposit,
      totalPrice: _totalDueToday,
    ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ),
        child: child,
      );
    },
  ),
);

  setState(() {
    _creatingBooking = false;
  });
}
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROGRESS STEPPER
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressStepper extends StatelessWidget {
  final _steps = const [
    _Step(label: 'Your\nSelection', number: 1),
    _Step(label: 'Payment\nMethod',   number: 2),
    _Step(label: 'Final\nBooking',  number: 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final leftActive  = (i ~/ 2) < 1;  // step before connector active?
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: leftActive
                    ? AppColors.primaryOrange
                    : AppColors.border,
              ),
            ),
          );
        }

        final step     = _steps[i ~/ 2];
        final isActive = step.number == 1;
        final isPast   = step.number < 1;

        return Column(
          children: [
            // Circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width:  36,
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
                          color:      AppColors.primaryOrange.withOpacity(.35),
                          blurRadius: 10,
                          offset:     const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  '${step.number}',
                  style: TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w800,
                    color: isActive
                        ? Colors.white
                        : isPast
                            ? AppColors.primaryOrange
                            : AppColors.textMid,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Label
            Text(
              step.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize:   10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color:      isActive
                    ? AppColors.primaryOrange
                    : AppColors.textMid,
                height:     1.3,
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
  final int    number;
  const _Step({required this.label, required this.number});
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROPERTY SUMMARY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _PropertyCard extends StatelessWidget {
  final ApartmentModel          apartment;
  final RoomOffer           room;
  final String Function(double) fmt;

  const _PropertyCard({
    required this.apartment,
    required this.room,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border:       Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(.07),
            blurRadius: 22,
            offset:     const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
// ── Cover image ──────────────────────────────────────────────
_PropertyImage(
  url: apartment.images.isNotEmpty ? apartment.images.first : '',
),

const SizedBox(width: 14),

            // ── Text ─────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:        AppColors.orangeLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 12, color: Colors.amber.shade600),
                        const SizedBox(width: 3),
                        Text(
  '${apartment.rating} (${apartment.reviewCount})',
  style: const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryOrange,
  ),
),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    apartment.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.w800,
                      color:      AppColors.text(context),
                      height:     1.2,
                      letterSpacing: -0.2,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 12, color: AppColors.textLight),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          apartment.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color:    AppColors.textLight,
                            height:   1.35,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
// Price
Builder(
  builder: (context) {
    final isDaily = room.pricingMode == 'daily';

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '₱${fmt(room.activePrice)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryOrange,
              letterSpacing: -0.4,
            ),
          ),
          TextSpan(
            text: isDaily ? ' /day' : ' /month',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMid,
            ),
          ),
        ],
      ),
    );
  },
),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyImage extends StatelessWidget {
  final String url;
  const _PropertyImage({required this.url});

  @override
  Widget build(BuildContext context) {
    const double size = 100;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: url.isNotEmpty
          ? Image.network(
              url,
              width:  size,
              height: size,
              fit:    BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(context, size),
            )
          : _fallback(context, size),
    );
  }

  Widget _fallback(BuildContext context, double size) => Container(
    width:  size,
    height: size,
    color:  AppColors.border,
    child:  const Icon(Icons.apartment_rounded,
        size: 32, color: AppColors.textLight),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  INPUT DETAILS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _InputDetailsCard extends StatelessWidget {
  final VoidCallback onEdit;
  final GuestInfoModel? guestInfo;

  const _InputDetailsCard({
    required this.onEdit,
    required this.guestInfo,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      context: context,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Your input details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text(context),
                ),
              ),
              const Spacer(),

              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.orangeLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          _Divider(),
          const SizedBox(height: 16),

_DetailRow(
  icon: Icons.calendar_today_rounded,
  label: 'Date',
  value: guestInfo == null
      ? 'Not selected'
      : '${GuestInfoModel.fmtDate(guestInfo!.checkInDate)} - ${GuestInfoModel.fmtDate(guestInfo!.checkOutDate)}',
),

          const SizedBox(height: 14),

          _DetailRow(
  icon: Icons.people_rounded,
  label: 'Guest',
  value: guestInfo == null
      ? 'Not selected'
      : '${guestInfo!.firstName} ${guestInfo!.lastName}',
),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PRICE DETAILS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _PriceDetailsCard extends StatelessWidget {
  final double roomBasePrice;
  final double securityDeposit;
  final double serviceFee;
  final int stayDuration;
  final double totalDueToday;
  final String pricingMode;
  final String Function(double) fmt;

const _PriceDetailsCard({
  required this.roomBasePrice,
  required this.securityDeposit,
  required this.serviceFee,
  required this.totalDueToday,
  required this.pricingMode,
  required this.stayDuration,
  required this.fmt,
});

@override
Widget build(BuildContext context) {

  final isDaily = pricingMode == 'daily';
  final durationLabel = isDaily ? 'days' : 'months';

  return _SectionCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price details',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.text(context),
            ),
          ),

          const SizedBox(height: 16),

_PriceRow(
  label: 'Room price (₱${fmt(roomBasePrice)} / ${pricingMode == 'daily' ? 'day' : 'month'} × $stayDuration $durationLabel)',
  value: '₱${fmt(roomBasePrice * stayDuration)}',
  context: context,
),

          const SizedBox(height: 10),

          _PriceRow(
            label: 'Security deposit',
            value: '₱${fmt(securityDeposit)}',
            context: context,
          ),

          const SizedBox(height: 10),

          _PriceRow(
            label: 'Service fee',
            value: '₱${fmt(serviceFee)}',
            context: context,
          ),

          const SizedBox(height: 16),
          _Divider(),
          const SizedBox(height: 16),

          Row(
            children: [
              Text(
                'Total Due Today',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text(context),
                ),
              ),
              const Spacer(),
              Text(
                '₱${fmt(totalDueToday)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

if (pricingMode == 'monthly')
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.orangeLight.withOpacity(0.25),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primaryOrange.withOpacity(0.25)),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  POLICIES ROW
// ─────────────────────────────────────────────────────────────────────────────
class _PoliciesRow extends StatefulWidget {
  @override
  State<_PoliciesRow> createState() => _PoliciesRowState();
}

class _PoliciesRowState extends State<_PoliciesRow> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              expanded = !expanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.orangeLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.policy_rounded,
                    size: 18,
                    color: AppColors.primaryOrange,
                  ),
                ),

                const SizedBox(width: 12),

                Text(
                  'Read other policies',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                ),

                const Spacer(),

                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMid,
                ),
              ],
            ),
          ),
        ),

        if (expanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              "• No smoking inside the property\n"
              "• Respect quiet hours\n"
              "• Deposit required before check-in\n"
              "• Valid ID required",
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMid,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}
class _ProceedButton extends StatelessWidget {
  final BuildContext context;
  final VoidCallback onTap;

  const _ProceedButton({
    required this.context,
    required this.onTap,
  });

  @override
  Widget build(BuildContext _) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8C00), Color(0xFFF5A623)],
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            'PROCEED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Shared card shell with soft shadow + border
class _SectionCard extends StatelessWidget {
  final BuildContext context;
  final Widget       child;

  const _SectionCard({required this.context, required this.child});

  @override
  Widget build(BuildContext _) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        AppColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border:       Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(.055),
            blurRadius: 18,
            offset:     const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    color:  AppColors.border,
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color:        AppColors.background(context),
            borderRadius: BorderRadius.circular(10),
            border:       Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 15, color: AppColors.textMid),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            color:    AppColors.textMid,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize:   13.5,
            fontWeight: FontWeight.w700,
            color:      AppColors.text(context),
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String       label;
  final String       value;
  final BuildContext context;

  const _PriceRow({
    required this.label,
    required this.value,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13.5,
          color: AppColors.textMid,
        ),
      ),
    ),
    const SizedBox(width: 8),
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
}