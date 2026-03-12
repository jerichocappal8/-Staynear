import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staynear/core/app_colors.dart';

class TenantDetailsScreen extends StatelessWidget {
  final QueryDocumentSnapshot occupancyDoc;

  const TenantDetailsScreen({super.key, required this.occupancyDoc});

  String _fmt(dynamic v, {bool includeYear = false}) {
    if (v == null) return "—";
    if (v is Timestamp) {
      final d = v.toDate();
      const m = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      if (includeYear) return "${m[d.month - 1]} ${d.day}, ${d.year}";
      return "${m[d.month - 1]} ${d.day}";
    }
    return v.toString();
  }

  int _stayDuration(dynamic checkIn, dynamic checkOut) {
    if (checkIn == null || checkOut == null) return 0;
    if (checkIn is Timestamp && checkOut is Timestamp) {
      return checkOut.toDate().difference(checkIn.toDate()).inDays;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final d = occupancyDoc.data() as Map<String, dynamic>;
    final name = d['guestName'] ?? "Unknown Tenant";
    final bookingId = d['bookingId'] as String?;
    final checkIn = _fmt(d['checkIn'], includeYear: true);
    final checkOut = _fmt(d['checkOut'], includeYear: true);
    final stayDays = _stayDuration(d['checkIn'], d['checkOut']);
    final roomType = d['roomName'] ?? d['roomType'] ?? "—";

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.text(context), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              name,
              style: TextStyle(
                color: AppColors.text(context),
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
            const Text(
              "Tenant Details",
              style: TextStyle(
                  color: AppColors.textMid,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border.withOpacity(0.4)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // ── AVATAR HEADER
          _TenantAvatarHeader(name: name, occupancyData: d),

          const SizedBox(height: 20),

          // ── BOOKING INFORMATION
          _SectionLabel(label: "Booking Information"),
          const SizedBox(height: 10),
          _BookingInfoCard(
            name: name,
            roomType: roomType,
            checkIn: checkIn,
            checkOut: checkOut,
            stayDays: stayDays,
            occupancyData: d,
          ),

          const SizedBox(height: 20),

          // ── PAYMENT BREAKDOWN & HISTORY (needs bookingId)
          if (bookingId != null) ...[
            _SectionLabel(label: "Payment Breakdown"),
            const SizedBox(height: 10),
            _PaymentBreakdownCard(bookingId: bookingId),

            const SizedBox(height: 20),

            _SectionLabel(label: "Payment History"),
            const SizedBox(height: 10),
            _PaymentHistoryCard(bookingId: bookingId),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.textLight, size: 16),
                  SizedBox(width: 8),
                  Text("No booking linked to this occupancy",
                      style: TextStyle(
                          color: AppColors.textMid,
                          fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// AVATAR HEADER
// ─────────────────────────────────────────────────────────
class _TenantAvatarHeader extends StatelessWidget {
  final String name;
  final Map<String, dynamic> occupancyData;

  const _TenantAvatarHeader(
      {required this.name, required this.occupancyData});

  String _statusLabel(dynamic checkOut) {
    if (checkOut == null) return "Occupied";
    DateTime end;
    if (checkOut is Timestamp) {
      end = checkOut.toDate();
    } else {
      return "Occupied";
    }
    final now = DateTime.now();
    if (end.isBefore(now)) return "Completed";
    if (end.difference(now).inDays <= 30) return "Leaving Soon";
    return "Occupied";
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(occupancyData['checkOut']);
    Color statusColor;
    switch (status) {
      case "Leaving Soon":
        statusColor = AppColors.primaryOrange;
        break;
      case "Completed":
        statusColor = AppColors.textMid;
        break;
      default:
        statusColor = const Color(0xFF22C55E);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primaryOrange.withOpacity(0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : "?",
              style: const TextStyle(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text(context),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  occupancyData['roomType'] ?? "Room",
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMid,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: statusColor.withOpacity(0.3), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    letterSpacing: 0.5,
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

// ─────────────────────────────────────────────────────────
// BOOKING INFO CARD
// ─────────────────────────────────────────────────────────
class _BookingInfoCard extends StatelessWidget {
  final String name;
  final String roomType;
  final String checkIn;
  final String checkOut;
  final int stayDays;
  final Map<String, dynamic> occupancyData;

  const _BookingInfoCard({
    required this.name,
    required this.roomType,
    required this.checkIn,
    required this.checkOut,
    required this.stayDays,
    required this.occupancyData,
  });

  @override
  Widget build(BuildContext context) {
    final email = occupancyData['guestEmail'] as String? ?? "—";

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          _InfoRow(
              icon: Icons.person_rounded,
              label: "Guest Name",
              value: name,
              isFirst: true),
          _InfoDivider(),
          _InfoRow(
              icon: Icons.email_rounded, label: "Email", value: email),
          _InfoDivider(),
          _InfoRow(
              icon: Icons.meeting_room_rounded,
              label: "Room Type",
              value: roomType),
          _InfoDivider(),
          _InfoRow(
              icon: Icons.login_rounded, label: "Check-in", value: checkIn),
          _InfoDivider(),
          _InfoRow(
              icon: Icons.logout_rounded,
              label: "Check-out",
              value: checkOut),
          _InfoDivider(),
          _InfoRow(
            icon: Icons.date_range_rounded,
            label: "Stay Duration",
            value: stayDays > 0 ? "$stayDays days" : "—",
            isLast: true,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PAYMENT BREAKDOWN CARD
// ─────────────────────────────────────────────────────────
class _PaymentBreakdownCard extends StatelessWidget {
  final String bookingId;
  const _PaymentBreakdownCard({required this.bookingId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _LoadingCard();
        }
        if (!snap.hasData || !snap.data!.exists) {
          return _ErrorCard(message: "Payment breakdown unavailable");
        }

        final b = snap.data!.data() as Map<String, dynamic>;

final amountPaid = (b['amountPaid'] ?? 0).toDouble();
final totalRent = (b['stayTotal'] ?? 0).toDouble();
final pricingMode = b['pricingMode'] ?? 'daily';

final remaining = (b['remainingBalance'] ?? 0).abs();
final firstMonthRent = b['priceMonthly'] ?? 0;
final securityDeposit = b['securityDeposit'] ?? 0;
final serviceFee = b['serviceFee'] ?? 0;

String paymentStatus = b['paymentStatus'] ?? "unknown";

// Fix: if daily booking is fully paid → mark as paid
if (pricingMode == 'daily' && amountPaid >= totalRent) {
  paymentStatus = 'paid';
}

        Color statusColor;
        switch (paymentStatus.toString().toLowerCase()) {
          case 'paid':
            statusColor = const Color(0xFF22C55E);
            break;
          case 'partial':
            statusColor = AppColors.primaryOrange;
            break;
          default:
            statusColor = AppColors.danger;
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              // status header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Icon(Icons.payments_rounded,
                        size: 14, color: AppColors.primaryOrange),
                    const SizedBox(width: 6),
                    Text(
                      "Overview",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text(context)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: statusColor.withOpacity(0.3), width: 0.8),
                      ),
                      child: Text(
                        paymentStatus.toString().toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border.withOpacity(0.4)),
              _InfoRow(
                  icon: Icons.home_rounded,
                  label: "First Month Rent",
                  value: "₱$firstMonthRent"),
              _InfoDivider(),
              _InfoRow(
                  icon: Icons.security_rounded,
                  label: "Security Deposit",
                  value: "₱$securityDeposit"),
              _InfoDivider(),
              _InfoRow(
                  icon: Icons.build_rounded,
                  label: "Service Fee",
                  value: "₱$serviceFee"),
              _InfoDivider(),
              _InfoRow(
                  icon: Icons.calculate_rounded,
                  label: "Total Rent",
                  value: "₱$totalRent",
                  highlight: true),
              _InfoDivider(),
              _InfoRow(
                  icon: Icons.check_circle_rounded,
                  label: "Total Paid",
                  value: "₱$amountPaid",
                  valueColor: const Color(0xFF22C55E)),
              _InfoDivider(),
              _InfoRow(
                icon: Icons.pending_rounded,
                label: "Remaining Balance",
                value: "₱$remaining",
                valueColor: remaining == 0
                    ? const Color(0xFF22C55E)
                    : AppColors.primaryOrange,
                isLast: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// PAYMENT HISTORY CARD
// ─────────────────────────────────────────────────────────
class _PaymentHistoryCard extends StatelessWidget {
  final String bookingId;
  const _PaymentHistoryCard({required this.bookingId});

  String _fmt(dynamic v) {
    if (v == null) return "—";
    if (v is Timestamp) {
      final d = v.toDate();
      const m = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return "${m[d.month - 1]} ${d.day}, ${d.year}";
    }
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
    .collection('payments')
    .where('bookingId', isEqualTo: bookingId)
    .orderBy('createdAt', descending: false)
    .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _LoadingCard();
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.border.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    color: AppColors.textLight, size: 18),
                const SizedBox(width: 10),
                const Text(
                  "No payment history found",
                  style: TextStyle(
                      color: AppColors.textMid,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        final payments = snap.data!.docs;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
          ),
          child: Column(
            children: payments.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value.data() as Map<String, dynamic>;
              final date = _fmt(p['createdAt']);
              final amount = p['amount'] ?? 0;
              final method = p['method'] ?? "—";
              final label = p['label'] ?? p['description'] ?? "Payment";
              final status = p['status'] ?? "completed";

              final bool isPending =
                  status.toString().toLowerCase() == 'pending';
              final Color statusColor =
                  isPending ? AppColors.primaryOrange : const Color(0xFF22C55E);

              return Column(
                children: [
                  if (idx > 0)
                    Divider(
                        height: 1,
                        color: AppColors.border.withOpacity(0.4),
                        indent: 54),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        // timeline dot + line
                        Column(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: statusColor.withOpacity(0.3),
                                    width: 0.8),
                              ),
                              child: Icon(
                                isPending
                                    ? Icons.schedule_rounded
                                    : Icons.check_rounded,
                                size: 14,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text(context),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    isPending
                                        ? "Pending"
                                        : "₱$amount",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isPending
                                          ? AppColors.primaryOrange
                                          : AppColors.text(context),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    date,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMid,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  if (!isPending) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 3,
                                      height: 3,
                                      decoration: const BoxDecoration(
                                          color: AppColors.textLight,
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      method,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMid,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// SHARED REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;
  final bool highlight;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
    this.highlight = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        isFirst ? 14 : 12,
        16,
        isLast ? 14 : 12,
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primaryOrange),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMid,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 14 : 13,
              fontWeight:
                  highlight ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppColors.text(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: AppColors.border.withOpacity(0.35),
      indent: 40,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.primaryOrange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.text(context),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.4)),
      ),
      child: const Center(
        child: CircularProgressIndicator(
            color: AppColors.primaryOrange, strokeWidth: 2),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.textLight, size: 16),
          const SizedBox(width: 8),
          Text(message,
              style: const TextStyle(
                  color: AppColors.textMid, fontSize: 13)),
        ],
      ),
    );
  }
}