import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staynear/core/app_colors.dart';
import 'tenant_details_screen.dart';

class TenantListScreen extends StatelessWidget {
  final String roomType;
  final List<QueryDocumentSnapshot> occupancyDocs;
  final String propertyId;

  const TenantListScreen({
    super.key,
    required this.roomType,
    required this.occupancyDocs,
    required this.propertyId,
  });

  @override
  Widget build(BuildContext context) {
    final occupied = occupancyDocs
        .where((d) => (d.data() as Map)['status'] == 'occupied')
        .toList();

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
              roomType,
              style: TextStyle(
                color: AppColors.text(context),
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
            const Text(
              "Tenant List",
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
      body: occupied.isEmpty
          ? _EmptyTenants()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              itemCount: occupied.length,
              itemBuilder: (context, index) {
                return _TenantCard(
                  doc: occupied[index],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TenantDetailsScreen(
                          occupancyDoc: occupied[index],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// TENANT CARD — Level 3
// ─────────────────────────────────────────────────────────
class _TenantCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final VoidCallback onTap;

  const _TenantCard({required this.doc, required this.onTap});

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

  int _monthsRemaining(dynamic checkOut) {
    if (checkOut == null) return 0;
    DateTime end;
    if (checkOut is Timestamp) {
      end = checkOut.toDate();
    } else {
      return 0;
    }
    final now = DateTime.now();
    if (end.isBefore(now)) return 0;
    return ((end.difference(now).inDays) / 30).ceil();
  }

  String _tenantStatus(dynamic checkOut) {
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
    final d = doc.data() as Map<String, dynamic>;
    final name = d['guestName'] ?? "Unknown Tenant";
    final checkIn = _fmt(d['checkIn']);
    final checkOut = _fmt(d['checkOut']);
    final bookingId = d['bookingId'] as String?;
    final status = _tenantStatus(d['checkOut']);
    final monthsLeft = _monthsRemaining(d['checkOut']);

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case "Leaving Soon":
        statusColor = AppColors.primaryOrange;
        statusIcon = Icons.schedule_rounded;
        break;
      case "Completed":
        statusColor = AppColors.textMid;
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        statusColor = const Color(0xFF22C55E);
        statusIcon = Icons.person_rounded;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── TENANT HEADER
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primaryOrange.withOpacity(0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : "?",
                      style: const TextStyle(
                        color: AppColors.primaryOrange,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
  children: [
    const Icon(
      Icons.calendar_today_rounded,
      size: 11,
      color: AppColors.textMid,
    ),
    const SizedBox(width: 4),

    Expanded(
      child: Text(
        "$checkIn → $checkOut",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textMid,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  ],
),
                      ],
                    ),
                  ),
                  // STATUS BADGE
                  _StatusBadge(
                    label: status,
                    color: statusColor,
                    icon: statusIcon,
                  ),
                ],
              ),

              // ── MONTHS REMAINING
              if (monthsLeft > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.hourglass_empty_rounded,
                        size: 12, color: AppColors.textMid),
                    const SizedBox(width: 5),
                    Text(
                      "$monthsLeft month${monthsLeft != 1 ? 's' : ''} remaining",
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

              if (bookingId != null) ...[
                const SizedBox(height: 12),
                Divider(color: AppColors.border.withOpacity(0.4), height: 1),
                const SizedBox(height: 12),
                _PaymentSummaryRow(bookingId: bookingId),
              ],

              const SizedBox(height: 12),

              // ── VIEW DETAILS BUTTON
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side:
                        BorderSide(color: AppColors.border.withOpacity(0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onTap,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "View Full Details",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 11, color: AppColors.text(context)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PAYMENT SUMMARY ROW (inside tenant card)
// ─────────────────────────────────────────────────────────
class _PaymentSummaryRow extends StatelessWidget {
  final String bookingId;
  const _PaymentSummaryRow({required this.bookingId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const Text("Payment info unavailable",
              style:
                  TextStyle(fontSize: 11, color: AppColors.textLight));
        }

        final b = snap.data!.data() as Map<String, dynamic>;
        final paymentStatus = b['paymentStatus'] ?? "unknown";
        final amountPaid = b['amountPaid'] ?? 0;
        final remaining = (b['remainingBalance'] ?? 0).abs();

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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_rounded,
                    size: 12, color: AppColors.primaryOrange),
                const SizedBox(width: 5),
                Text(
                  "Payment",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                // Payment health indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  paymentStatus.toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PaymentChip(
                    context: context,
                    icon: Icons.check_circle_rounded,
                    label: "Paid",
                    value: "₱$amountPaid",
                    iconColor: const Color(0xFF22C55E),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PaymentChip(
                    context: context,
                    icon: Icons.pending_rounded,
                    label: "Remaining",
                    value: "₱$remaining",
                    iconColor: remaining == 0
                        ? const Color(0xFF22C55E)
                        : AppColors.primaryOrange,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _StatusBadge(
      {required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final BuildContext context;
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _PaymentChip({
    required this.context,
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext outerContext) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardSoft(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withOpacity(0.4)),
      ),
child: Row(
  children: [
    Icon(icon, size: 13, color: iconColor),
    const SizedBox(width: 6),

    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.text(context),
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

class _EmptyTenants extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.cardSoft(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.person_off_rounded,
                  size: 30, color: AppColors.textLight),
            ),
            const SizedBox(height: 16),
            Text(
              "No tenants",
              style: TextStyle(
                color: AppColors.text(context),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "No occupied rooms in this category",
              style: TextStyle(color: AppColors.textMid, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}