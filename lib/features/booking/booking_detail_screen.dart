// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/features/bookings/booking_detail_page.dart
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'advance_payment_page.dart';
import '../reviews/review_page.dart';

import '../../core/app_colors.dart';

class BookingDetailPage extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> data;

  const BookingDetailPage({
    super.key,
    required this.bookingId,
    required this.data,
  });

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  bool _cancelling = false;

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmtDate(dynamic raw) {
    if (raw == null) return '—';
    try {
      final dt =
          (raw is Timestamp) ? raw.toDate() : DateTime.parse(raw.toString());
      return DateFormat('EEEE, MMM d, yyyy').format(dt);
    } catch (_) {
      return raw.toString();
    }
  }

  String _fmtPrice(dynamic raw) {
    if (raw == null) return '₱0';
    final v = (raw is double) ? raw : (raw as num).toDouble();
    return '₱${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
  }

  /// Compute nights between checkIn and checkOut
  int _nights(dynamic checkIn, dynamic checkOut) {
    try {
      final inDt =
          (checkIn is Timestamp) ? checkIn.toDate() : DateTime.parse(checkIn.toString());
      final outDt =
          (checkOut is Timestamp) ? checkOut.toDate() : DateTime.parse(checkOut.toString());
      return outDt.difference(inDt).inDays.abs();
    } catch (_) {
      return 0;
    }
  }

  // ── Status helpers ─────────────────────────────────────────────────────────

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed': return const Color(0xFF059669);
      case 'pending':   return const Color(0xFFF59E0B);
      case 'cancelled': return const Color(0xFFEF4444);
      case 'completed': return const Color(0xFF3B82F6);
      default:          return AppColors.textMid;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed': return const Color(0xFFD1FAE5);
      case 'pending':   return const Color(0xFFFEF3C7);
      case 'cancelled': return const Color(0xFFFEE2E2);
      case 'completed': return const Color(0xFFDBEAFE);
      default:          return AppColors.border;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed': return Icons.check_circle_rounded;
      case 'pending':   return Icons.schedule_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      case 'completed': return Icons.task_alt_rounded;
      default:          return Icons.info_outline_rounded;
    }
  }

  // ── Cancel booking ─────────────────────────────────────────────────────────
  //
  //  Design: one atomic Firestore transaction.
  //
  //  Why pre-fetch occupancy refs before the transaction:
  //    Firestore transactions cannot run collection queries (.where(...).get()).
  //    We fetch the document refs first, outside the transaction, then lock
  //    those exact documents inside it. This is the standard Firestore pattern.
  //    It is safe here because occupancy docs are created once on payment and
  //    never added again for the same booking.
  //
  //  Transaction rule — ALL reads must come before ALL writes in the callback.
  //  Firestore will retry the whole callback if any document changed between
  //  the read and the commit, guaranteeing consistency.
  //
  //  UI contract:
  //    • The screen uses StreamBuilder, so Firestore drives the displayed status.
  //    • We never manually set "Cancelled" in the UI — the stream does it.
  //    • If the transaction throws, _cancelling is reset so the button reappears.
  //    • We do NOT setState after Navigator.pop to avoid "setState after dispose".

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _CancelDialog(),
    );
    if (confirmed != true) return;

    setState(() => _cancelling = true);

    try {
      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId);

      // ── Phase 1: pre-fetch occupancy refs (query, outside transaction) ────
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('not_signed_in');

      final occQuerySnap = await FirebaseFirestore.instance
          .collection('room_occupancy')
          .where('bookingId', isEqualTo: widget.bookingId)
          .where('guestId', isEqualTo: uid)
          .get();
      final occRefs = occQuerySnap.docs.map((d) => d.reference).toList();

      // ── Phase 2: single atomic transaction ───────────────────────────────
      await FirebaseFirestore.instance.runTransaction((txn) async {

        // ── ALL READS FIRST ────────────────────────────────────────────────

        // 1. Read booking (source of truth for status, ids, and timestamps)
        final bookingSnap = await txn.get(bookingRef);
        if (!bookingSnap.exists) throw Exception('booking_not_found');

        final bookingData   = bookingSnap.data()!;
        final currentStatus = (bookingData['bookingStatus'] ?? '').toString();

        // Double-cancel guard — atomic: no other cancel can slip through
        if (currentStatus == 'cancelled') throw Exception('already_cancelled');

        // 24-hour window — validated against live Firestore data (not stale widget.data)
        final rawCreatedAt = bookingData['createdAt'];
        if (rawCreatedAt is Timestamp) {
          if (DateTime.now().difference(rawCreatedAt.toDate()).inHours > 24) {
            throw Exception('window_expired');
          }
        }

        // Payment guard — server-side counterpart to the UI canCancel check.
        // Blocks cancellation even if the client bypasses the button visibility.
        final paidSoFar =
            ((bookingData['amountPaid'] as num?) ?? 0).toDouble();
        if (paidSoFar > 0) throw Exception('payment_already_made');

        final apartmentId = bookingData['apartmentId'] as String?;
        final roomId      = bookingData['roomId']      as String?;

        // 2. Read room document so we can compute newUnits from the live value
        DocumentReference? roomRef;
        DocumentSnapshot?  roomSnap;
        if (apartmentId != null && apartmentId.isNotEmpty &&
            roomId      != null && roomId.isNotEmpty) {
          roomRef  = FirebaseFirestore.instance
              .collection('properties')
              .doc(apartmentId)
              .collection('rooms')
              .doc(roomId);
          roomSnap = await txn.get(roomRef);
        }

        // 3. Lock every occupancy document so no concurrent write can change them
        for (final ref in occRefs) {
          await txn.get(ref);
        }

        // ── ALL WRITES (no reads after this line) ─────────────────────────

        // 4. Mark booking cancelled
        txn.update(bookingRef, {
          'bookingStatus': 'cancelled',
          'cancelledAt':   Timestamp.now(),
        });

        // 5. Restore room availability — computed from the live read value.
        //    Using the read value (not FieldValue.increment) means the new
        //    count is predictable and can be capped at totalUnits if that field
        //    exists in the room document.
        if (roomRef != null && roomSnap != null && roomSnap.exists) {
          final roomData     = roomSnap.data() as Map<String, dynamic>;
          final currentUnits = (roomData['availableUnits'] as num?)?.toInt() ?? 0;
          final totalUnits   = (roomData['totalUnits']     as num?)?.toInt();
          // Increment by 1; if the host has stored a totalUnits ceiling, clamp to it
          final newUnits     = (totalUnits != null)
              ? (currentUnits + 1).clamp(0, totalUnits)
              : currentUnits + 1;
          txn.update(roomRef, {'availableUnits': newUnits});
        }

        // 6. Mark every occupancy record for this booking as cancelled
        for (final ref in occRefs) {
          txn.update(ref, {'status': 'cancelled'});
        }

        // Transaction commits here. If anything conflicted, Firestore retries
        // the entire callback — the booking stays unchanged until all writes
        // land together.
      });

      // ── Transaction committed ─────────────────────────────────────────────
      // The StreamBuilder picks up 'cancelled' from Firestore automatically.
      // We pop the screen; no setState needed — the widget will be disposed.
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Booking cancelled successfully.'),
          backgroundColor: AppColors.primaryOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );

      Navigator.pop(context);

    } catch (e) {
      // Transaction did not commit — Firestore was not changed.
      // Restore the button so the user can see the original status and retry.
      if (!mounted) return;
      setState(() => _cancelling = false);

      final raw = e.toString();
      final String msg;
      if (raw.contains('already_cancelled')) {
        msg = 'This booking is already cancelled.';
      } else if (raw.contains('window_expired')) {
        msg = 'Cancellation window has expired (24 hours after booking).';
      } else if (raw.contains('booking_not_found')) {
        msg = 'Booking not found. Please refresh and try again.';
      } else if (raw.contains('payment_already_made')) {
        msg = 'Cancellation is not available after a payment has been made.';
      } else {
        msg = 'Cancellation failed. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

@override
Widget build(BuildContext context) {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .snapshots(),
    builder: (context, snapshot) {

      if (!snapshot.hasData) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (!snapshot.data!.exists) {
        return const Scaffold(
          body: Center(child: Text('Booking not found')),
        );
      }

      final d = snapshot.data!.data() as Map<String, dynamic>;

    final name          = (d['apartmentName'] ?? 'Apartment') as String;
    final imageUrl      = (d['apartmentImage'] ?? '') as String;
    final guestName     = (d['guestName']      ?? '—') as String;
    final guestEmail    = (d['guestEmail']      ?? '—') as String;
    final checkIn       = d['checkIn'];
    final checkOut      = d['checkOut'];
    final amount           = d['amountPaid']; // kept dynamic for _fmtPrice compat
    final amountPaidVal    = ((d['amountPaid']       as num?) ?? 0).toDouble();
    final bookingStatus    = (d['bookingStatus'] ?? 'pending').toString();
    String paymentStatus   = (d['paymentStatus'] ?? 'unpaid').toString();
    final nights           = _nights(checkIn, checkOut);
    final isCancelled      = bookingStatus.toLowerCase() == 'cancelled';
    final hasReview        = (d['hasReview'] ?? false) as bool;
    final monthlyRent      = d['priceMonthly'] ?? 0;
    final securityDeposit  = d['securityDeposit'] ?? 0;
    final serviceFee       = d['serviceFee'] ?? 0;
    final totalDueToday    = d['totalDueToday'] ?? 0;
    final stayTotal        = ((d['stayTotal']        as num?) ?? 0).toDouble();
    final remainingBalance = ((d['remainingBalance'] as num?) ?? 0).toDouble();
    final pricingMode      = d['pricingMode'] ?? 'daily';

// Unified payment status — same rule for monthly and daily:
//   amountPaid == 0                        → unpaid
//   amountPaid > 0  &&  remainingBalance > 0 → partial
//   remainingBalance <= 0  (and paid > 0)   → paid
//
// Monthly example (₱1,234 × 5 months):
//   initial payment = ₱1,334  remainingBalance = ₱4,936  → partial
//   full advance    = ₱4,936  remainingBalance = ₱0      → paid
if (amountPaidVal <= 0) {
  paymentStatus = 'unpaid';
} else if (remainingBalance > 0) {
  paymentStatus = 'partial';
} else {
  paymentStatus = 'paid';
}

// ── Auto-complete: write 'completed' once when the confirmed booking's
// checkOut timestamp has passed.
//
// Conditions (all must be true):
//   • bookingStatus == 'confirmed'   (not pending / cancelled / already completed)
//   • checkOut is a valid Timestamp
//   • checkOut is in the past
//
// Idempotent: on the next open, bookingStatus is already 'completed'
// so the first condition fails — no duplicate write.
// The StreamBuilder refreshes the UI automatically on a successful write.
// Firestore rule allows this: bookingStatus is in bookingUserUpdateFields().
if (bookingStatus == 'confirmed' && checkOut is Timestamp) {
  if (DateTime.now().isAfter((checkOut as Timestamp).toDate())) {
    FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .update({'bookingStatus': 'completed'})
        .catchError((e) {
          debugPrint('[BookingDetail] auto-complete write failed: $e');
        });
  }
}

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero image app bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.background(context),
            leading: _BackButton(),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Apartment image
                  imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.orangeLight,
                            child: const Icon(Icons.apartment_rounded,
                                color: AppColors.primaryOrange, size: 56),
                          ),
                        )
                      : Container(
                          color: AppColors.orangeLight,
                          child: const Icon(Icons.apartment_rounded,
                              color: AppColors.primaryOrange, size: 56),
                        ),
                  // Bottom gradient for readability
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC000000)],
                        stops: [0.55, 1.0],
                      ),
                    ),
                  ),
                  // Apartment name overlaid on image
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.4,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StatusPill(
                          status: bookingStatus,
                          color: _statusColor(bookingStatus),
                          bgColor: _statusBg(bookingStatus),
                          icon: _statusIcon(bookingStatus),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Stay summary card ─────────────────────────────────
                  _SectionCard(
                    title: 'Stay Summary',
                    icon: Icons.night_shelter_rounded,
                    child: Column(
                      children: [
                        _StayTimeline(
                          checkIn: _fmtDate(checkIn),
                          checkOut: _fmtDate(checkOut),
                          nights: nights,
                          context: context,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Guest info card ───────────────────────────────────
                  _SectionCard(
                    title: 'Guest Information',
                    icon: Icons.person_rounded,
                    child: Column(
                      children: [
                        _DetailRow(
                          label: 'Name',
                          value: guestName,
                          icon: Icons.badge_rounded,
                          context: context,
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          label: 'Email',
                          value: guestEmail,
                          icon: Icons.email_rounded,
                          context: context,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Payment card ──────────────────────────────────────
                  _SectionCard(
                    title: 'Payment',
                    icon: Icons.payment_rounded,
                    child: Column(
  children: [

// MONTHLY SUMMARY
if (pricingMode == "monthly") ...[
  _PaymentRow("Monthly Rent", _fmtPrice(monthlyRent)),
  _PaymentRow("Security Deposit", _fmtPrice(securityDeposit)),
  _PaymentRow("Service Fee", _fmtPrice(serviceFee)),

  const SizedBox(height: 12),
  const Divider(height: 1),

  // Show actual amount paid, not the static "due today" figure.
  // Before payment: show what is due. After payment: show what was paid.
  if (amountPaidVal > 0)
    _PaymentRow("Amount Paid", _fmtPrice(amountPaidVal), highlight: true)
  else
    _PaymentRow("Due Today", _fmtPrice(totalDueToday)),

  const SizedBox(height: 10),

  _PaymentRow("Remaining Balance", _fmtPrice(remainingBalance)),
  // "Total Rent Cost" = priceMonthly × months (deposit/fee excluded — paid once only).
  _PaymentRow("Total Rent Cost", _fmtPrice(stayTotal)),
],


// DAILY SUMMARY
if (pricingMode == "daily") ...[
  _PaymentRow("Price per Night", _fmtPrice(d['pricePerNight'] ?? 0)),
  _PaymentRow("Number of Nights", nights.toString()),
  const SizedBox(height: 12),
  const Divider(height: 1),
  _PaymentRow("Total Stay Cost", _fmtPrice(stayTotal), highlight: true),
  _PaymentRow("Amount Paid", _fmtPrice(amount ?? 0)),
],

    const SizedBox(height: 12),
    const Divider(height: 1),
    const SizedBox(height: 12),

    Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      'Payment Status',
      style: TextStyle(
        fontSize: 14,
        color: AppColors.textMid,
      ),
    ),
    _PaymentBadge(status: paymentStatus),
  ],
),

if (pricingMode == "monthly" && remainingBalance > 0 && !isCancelled) ...[
  const SizedBox(height: 16),

  SizedBox(
  width: double.infinity,
  height: 52,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryOrange,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    onPressed: () {
      Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => AdvancePaymentPage(
      bookingId: widget.bookingId,
    ),
  ),
);
    },
child: Text(
  "Pay Remaining Balance",
  style: const TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  ),
),
  ),
),
],
  ],
),
                  ),

                  const SizedBox(height: 16),

                  // ── Booking ref ───────────────────────────────────────
                  _SectionCard(
                    title: 'Booking Reference',
                    icon: Icons.confirmation_number_rounded,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.bookingId,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMid,
                              fontFamily: 'monospace',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

if (!isCancelled) ...[
  Builder(
    builder: (context) {
      final createdAt = d['createdAt'] as Timestamp?;
      final isPaid    = paymentStatus.toLowerCase() == 'paid' ||
          remainingBalance <= 0;
      final canReview = bookingStatus.toLowerCase() != 'cancelled' &&
          (paymentStatus.toLowerCase() == 'paid' || remainingBalance <= 0) &&
          !hasReview;
      bool canCancel  = false;

      if (createdAt != null) {
        canCancel = DateTime.now()
            .difference(createdAt.toDate())
            .inHours <= 24
            && amountPaidVal <= 0;
      }

      debugPrint(
        '[BookingDetail] isPaid=$isPaid  canReview=$canReview  canCancel=$canCancel  '
        'hasReview=$hasReview  bookingStatus=$bookingStatus  '
        'paymentStatus=$paymentStatus',
      );

      // ── 1. Fully paid → review actions.
      //       Never show cancel button or 24-hour warning.
      if (isPaid) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Thank you for completing your payment.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMid,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (hasReview)
              const _ReviewSubmittedBadge()
            else if (canReview)
              _ReviewButton(
                onTap: () async {
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewPage(
                        bookingId: widget.bookingId,
                        data: d,
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      }

      // ── 2. Partially paid + within 24-hour window → cancel button.
      //       Partially paid + window expired → nothing here; the payment
      //       card above already shows "Pay Remaining Balance".
      if (canCancel) {
        return _CancelButton(
          cancelling: _cancelling,
          onTap: _cancelBooking,
        );
      }

      // ── 3. Partial payment, window expired → suppress warning.
      //       The payment card handles the "pay remaining" action.
      if (paymentStatus == 'partial') return const SizedBox.shrink();

      // ── 4. Unpaid + window expired → warning only, no cancel button.
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.danger.withOpacity(0.35),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.danger, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Bookings can only be cancelled within 24 hours after booking.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    },
  ),
],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  },
);
}
}

// ─────────────────────────────────────────────────────────────────────────────
//  SMALL COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
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
            color: Colors.black.withOpacity(0.35),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final Color color;
  final Color bgColor;
  final IconData icon;
  const _StatusPill({
    required this.status,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section card wrapper with a title bar
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.orangeLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      Icon(icon, size: 15, color: AppColors.primaryOrange),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
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
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Timeline-style stay display
class _StayTimeline extends StatelessWidget {
  final String checkIn;
  final String checkOut;
  final int nights;
  final BuildContext context;
  const _StayTimeline({
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Check-in
        Expanded(
          child: _TimelineNode(
            label: 'Check-in',
            date: checkIn,
            icon: Icons.login_rounded,
            context: context,
          ),
        ),
        // Night count pill
        Column(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.orangeLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(0.3)),
              ),
              child: Text(
                '$nights ${nights == 1 ? 'night' : 'nights'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryOrange,
                ),
              ),
            ),
          ],
        ),
        // Check-out
        Expanded(
          child: _TimelineNode(
            label: 'Check-out',
            date: checkOut,
            icon: Icons.logout_rounded,
            isRight: true,
            context: context,
          ),
        ),
      ],
    );
  }
}

class _TimelineNode extends StatelessWidget {
  final String label;
  final String date;
  final IconData icon;
  final bool isRight;
  final BuildContext context;
  const _TimelineNode({
    required this.label,
    required this.date,
    required this.icon,
    required this.context,
    this.isRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isRight) ...[
              Icon(icon, size: 13, color: AppColors.primaryOrange),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isRight) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 13, color: AppColors.primaryOrange),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          date,
          textAlign: isRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.text(context),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final BuildContext context;
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.orangeLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppColors.primaryOrange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textLight),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final String status;
  const _PaymentBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPaid = status.toLowerCase() == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isPaid
            ? const Color(0xFFD1FAE5)
            : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
            size: 12,
            color: isPaid
                ? const Color(0xFF059669)
                : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 5),
          Text(
            isPaid ? 'Paid' : status[0].toUpperCase() + status.substring(1),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isPaid
                  ? const Color(0xFF059669)
                  : const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }
}
class _PaymentRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _PaymentRow(
    this.label,
    this.value, {
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMid,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 18 : 14,
              fontWeight: FontWeight.w700,
              color: highlight
                  ? AppColors.primaryOrange
                  : AppColors.text(context),
            ),
          ),
        ],
      ),
    );
  }
}
class _ReviewButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ReviewButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primaryOrange,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Leave a Review',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
class _ReviewSubmittedBadge extends StatelessWidget {
  const _ReviewSubmittedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text(
          'Review Submitted',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF059669),
          ),
        ),
      ),
    );
  }
}
class _CancelButton extends StatelessWidget {
  final bool cancelling;
  final VoidCallback onTap;
  const _CancelButton({required this.cancelling, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: cancelling ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.danger.withOpacity(0.6),
            width: 1.5,
          ),
        ),
        child: Center(
          child: cancelling
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.danger,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel_outlined,
                        size: 18, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Text(
                      'Cancel Booking',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
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
//  CANCEL CONFIRMATION DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _CancelDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Cancel Booking?',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.text(context),
          fontSize: 18,
        ),
      ),
      content: Text(
        'This action cannot be undone. Are you sure you want to cancel this booking?',
        style: TextStyle(
          color: AppColors.textMid,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Keep Booking',
            style: TextStyle(
              color: AppColors.textMid,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Yes, Cancel',
            style: TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
