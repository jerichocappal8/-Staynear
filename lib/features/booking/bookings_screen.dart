// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/features/bookings/bookings_screen.dart
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import 'booking_detail_screen.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _fmtDate(dynamic raw) {
    if (raw == null) return '—';
    try {
      final dt = (raw is Timestamp) ? raw.toDate() : DateTime.parse(raw.toString());
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return raw.toString();
    }
  }

  static String _fmtShortDate(dynamic raw) {
    if (raw == null) return '—';
    try {
      final dt = (raw is Timestamp) ? raw.toDate() : DateTime.parse(raw.toString());
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return raw.toString();
    }
  }

  static String _fmtPrice(dynamic raw) {
    if (raw == null) return '₱0';
    final v = (raw is double) ? raw : (raw as num).toDouble();
    return '₱${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
  }

  // ── Status helpers ─────────────────────────────────────────────────────────

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF059669);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'completed':
        return const Color(0xFF3B82F6);
      default:
        return AppColors.textMid;
    }
  }

  static Color _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFFD1FAE5);
      case 'pending':
        return const Color(0xFFFEF3C7);
      case 'cancelled':
        return const Color(0xFFFEE2E2);
      case 'completed':
        return const Color(0xFFDBEAFE);
      default:
        return AppColors.border;
    }
  }

  static IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'completed':
        return Icons.task_alt_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
final user = FirebaseAuth.instance.currentUser;
if (user == null) {
  return const Center(child: Text('User not logged in'));
}
final userId = user.uid;
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('bookings')
                    .where('userId', isEqualTo: userId)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _LoadingState();
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(error: snapshot.error.toString());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return _EmptyState();
                  }
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      return _BookingCard(
                        docId: docs[i].id,
                        data: data,
                        fmtDate: _fmtDate,
                        fmtShortDate: _fmtShortDate,
                        fmtPrice: _fmtPrice,
                        statusColor: _statusColor,
                        statusBg: _statusBg,
                        statusIcon: _statusIcon,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.orangeLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primaryOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Bookings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text(context),
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'Track your reservations',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMid,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BOOKING CARD
// ─────────────────────────────────────────────────────────────────────────────

class _BookingCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String Function(dynamic) fmtDate;
  final String Function(dynamic) fmtShortDate;
  final String Function(dynamic) fmtPrice;
  final Color Function(String) statusColor;
  final Color Function(String) statusBg;
  final IconData Function(String) statusIcon;

  const _BookingCard({
    required this.docId,
    required this.data,
    required this.fmtDate,
    required this.fmtShortDate,
    required this.fmtPrice,
    required this.statusColor,
    required this.statusBg,
    required this.statusIcon,
  });

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _pressCtrl.forward();
  void _onTapUp(_) => _pressCtrl.reverse();
  void _onTapCancel() => _pressCtrl.reverse();

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final name = (d['apartmentName'] ?? 'Apartment') as String;
    final imageUrl = (d['apartmentImage'] ?? '') as String;
    final checkIn = d['checkIn'];
    final checkOut = d['checkOut'];
    final amount = d['amountPaid'];
    final status = (d['bookingStatus'] ?? 'pending').toString();

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingDetailPage(
              bookingId: widget.docId,
              data: d,
            ),
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image + status overlay ─────────────────────────────────
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    child: _ApartmentImage(url: imageUrl, height: 160),
                  ),
                  // Status badge overlaid on image
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _StatusBadge(
                      status: status,
                      color: widget.statusColor(status),
                      bgColor: widget.statusBg(status),
                      icon: widget.statusIcon(status),
                    ),
                  ),
                ],
              ),

              // ── Card body ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(context),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Date row
                    Row(
                      children: [
                        _DateChip(
                          label: 'Check-in',
                          date: widget.fmtShortDate(checkIn),
                          context: context,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: AppColors.textMid,
                          ),
                        ),
                        _DateChip(
                          label: 'Check-out',
                          date: widget.fmtShortDate(checkOut),
                          context: context,
                        ),
                        const Spacer(),
                        // Price
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                              ),
                            ),
                            Text(
                              widget.fmtPrice(amount),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryOrange,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Divider(height: 1, thickness: 0.8),
                    const SizedBox(height: 12),

                    // View Details button
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Booked on ${widget.fmtDate(d['createdAt'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMid,
                          ),
                        ),
                        const Spacer(),
                        _ViewButton(),
                      ],
                    ),
                  ],
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
//  SMALL COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _ApartmentImage extends StatelessWidget {
  final String url;
  final double height;
  const _ApartmentImage({required this.url, required this.height});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        color: AppColors.orangeLight,
        child: const Icon(Icons.apartment_rounded,
            color: AppColors.primaryOrange, size: 40),
      );
    }
    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        width: double.infinity,
        color: AppColors.orangeLight,
        child: const Icon(Icons.broken_image_rounded,
            color: AppColors.textLight, size: 36),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  final Color bgColor;
  final IconData icon;
  const _StatusBadge({
    required this.status,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final String date;
  final BuildContext context;
  const _DateChip({
    required this.label,
    required this.date,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          date,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.text(context),
          ),
        ),
      ],
    );
  }
}

class _ViewButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            'View Details',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.1,
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LOADING / EMPTY / ERROR STATES
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      itemCount: 3,
      itemBuilder: (_, __) => _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skel(width: 180, height: 16),
                const SizedBox(height: 12),
                Row(children: [
                  _skel(width: 80, height: 12),
                  const SizedBox(width: 8),
                  _skel(width: 80, height: 12),
                  const Spacer(),
                  _skel(width: 60, height: 20),
                ]),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  _skel(width: 100, height: 32, radius: 20),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skel(
      {required double width,
      required double height,
      double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: AppColors.orangeLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: AppColors.primaryOrange,
                size: 42,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No bookings yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.text(context),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your upcoming and past reservations\nwill appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMid,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.textMid),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.text(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}