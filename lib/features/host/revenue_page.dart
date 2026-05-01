// revenue_page.dart
// ════════════════════════════════════════════════════════════════════════════
//  StayNear — Revenue Analytics Page
//  Admin dashboard screen. Opens when the Revenue card is tapped.
//
//  Data flow:
//    payments (status=="success", amount) ──► bookingId
//    bookings (bookingId) ──► propertyId
//    properties (propertyId) ──► name
//
//  Sections:
//    1. Hero revenue card — total revenue
//    2. Revenue by apartment — grouped + sorted
//    3. Recent payments — last 20, enriched with apt name
//
//  Animations:
//    • Staggered fade + slide on all sections (TweenAnimationBuilder)
//    • Count-up animation on total revenue figure
//    • Bar fill animation on per-apartment progress bars
// ════════════════════════════════════════════════════════════════════════════`

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentRecord {
  final String  id;
  final double  amount;
  final String  bookingId;
  final String  method;
  final DateTime date;

  // enriched after join
  String aptName = 'Unknown';

  _PaymentRecord({
    required this.id,
    required this.amount,
    required this.bookingId,
    required this.method,
    required this.date,
  });

  factory _PaymentRecord.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _PaymentRecord(
      id:        doc.id,
      amount:    ((d['amount'] as num?) ?? 0).toDouble(),
      bookingId: (d['bookingId'] as String?) ?? '',
      method:    (d['paymentMethod'] ?? d['method'] ?? 'Card') as String,
      date: d['createdAt'] is Timestamp
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class _AptRevenue {
  final String aptName;
  double total = 0;
  int    bookings = 0;

  _AptRevenue(this.aptName);
}

class _RevenueData {
  final double             totalRevenue;
  final List<_AptRevenue>  byApartment;
  final List<_PaymentRecord> recent;

  const _RevenueData({
    required this.totalRevenue,
    required this.byApartment,
    required this.recent,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  FIRESTORE LOADER
// ─────────────────────────────────────────────────────────────────────────────

Future<_RevenueData> _loadRevenueData() async {
  final fs = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return const _RevenueData(
        totalRevenue: 0, byApartment: [], recent: []);
  }

  // 1. Fetch successful payments
  final paySnap = await fs
      .collection('payments')
      .where('hostId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'success')
      .orderBy('createdAt', descending: true)
      .get();

  final payments =
      paySnap.docs.map((d) => _PaymentRecord.fromDoc(d)).toList();

  if (payments.isEmpty) {
    return const _RevenueData(
        totalRevenue: 0, byApartment: [], recent: []);
  }

  // 2. Collect unique bookingIds
  final bookingIds =
      payments.map((p) => p.bookingId).where((id) => id.isNotEmpty).toSet();

  // 3. Batch-fetch bookings (Firestore whereIn max 30 per batch)
  final Map<String, String> bookingToProperty = {};
  final idList = bookingIds.toList();
  for (int i = 0; i < idList.length; i += 30) {
    final chunk = idList.sublist(
        i, math.min(i + 30, idList.length));
    final snap = await fs
        .collection('bookings')
        .where('hostId', isEqualTo: user.uid)
        .where(FieldPath.documentId, whereIn: chunk)
        .get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final propId = (data['apartmentId'] as String?) ?? '';
      if (propId.isNotEmpty) bookingToProperty[doc.id] = propId;
    }
  }

  // 4. Collect unique propertyIds
  final propertyIds = bookingToProperty.values.toSet();
  final Map<String, String> propertyNames = {};
  final pIdList = propertyIds.toList();
  for (int i = 0; i < pIdList.length; i += 30) {
    final chunk = pIdList.sublist(
        i, math.min(i + 30, pIdList.length));
    final snap = await fs
        .collection('properties')
        .where(FieldPath.documentId, whereIn: chunk)
        .get();
    for (final doc in snap.docs) {
      final data = doc.data();
      propertyNames[doc.id] =
          (data['name'] ?? data['propertyName'] ?? 'Unnamed') as String;
    }
  }

  // 5. Enrich payments with apartment names
  for (final p in payments) {
    final propId = bookingToProperty[p.bookingId] ?? '';
    p.aptName = propertyNames[propId] ?? 'Unknown';
  }

  // 6. Group by apartment
  final Map<String, _AptRevenue> grouped = {};
  double total = 0;
  for (final p in payments) {
    total += p.amount;
    grouped.putIfAbsent(p.aptName, () => _AptRevenue(p.aptName));
    grouped[p.aptName]!.total    += p.amount;
    grouped[p.aptName]!.bookings += 1;
  }

  final byApt = grouped.values.toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  return _RevenueData(
    totalRevenue: total,
    byApartment:  byApt,
    recent:       payments.take(20).toList(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAGE
// ─────────────────────────────────────────────────────────────────────────────

class RevenuePage extends StatefulWidget {
  const RevenuePage({Key? key}) : super(key: key);

  @override
  State<RevenuePage> createState() => _RevenuePageState();
}

class _RevenuePageState extends State<RevenuePage>
    with SingleTickerProviderStateMixin {

  late final Future<_RevenueData> _future = _loadRevenueData();
  late final AnimationController  _masterCtrl;

  // staggered section animations
  late final List<Animation<double>> _sectionFade;
  late final List<Animation<Offset>>  _sectionSlide;

  @override
  void initState() {
    super.initState();

    _masterCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    );

    // 4 sections: hero, by-apt header, by-apt list, recent
    const offsets = [0.0, 0.20, 0.35, 0.55];
    const ends    = [0.40, 0.60, 0.75, 1.0];

    _sectionFade = List.generate(4, (i) {
      final interval =
          CurvedAnimation(
            parent: _masterCtrl,
            curve:  Interval(offsets[i], ends[i], curve: Curves.easeOut),
          );
      return Tween<double>(begin: 0, end: 1).animate(interval);
    });

    _sectionSlide = List.generate(4, (i) {
      final interval =
          CurvedAnimation(
            parent: _masterCtrl,
            curve:  Interval(offsets[i], ends[i], curve: Curves.easeOutCubic),
          );
      return Tween<Offset>(
        begin: const Offset(0, .045),
        end:   Offset.zero,
      ).animate(interval);
    });

    _future.then((_) {
      if (mounted) _masterCtrl.forward();
    });
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    super.dispose();
  }

  // ─── helpers ───────────────────────────────────────────────────────────────

  Widget _section(int i, Widget child) => FadeTransition(
        opacity: _sectionFade[i],
        child:   SlideTransition(position: _sectionSlide[i], child: child),
      );

  static String _fmtCurrency(double v) =>
      '₱${NumberFormat('#,##0', 'en_US').format(v)}';

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: _buildAppBar(context, isDark),
      body: FutureBuilder<_RevenueData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primaryOrange, strokeWidth: 2.5),
            );
          }
          if (snap.hasError) {
            return const _ErrorState(error: 'Please check your connection and try again.');
          }
          final data = snap.data!;
          if (data.totalRevenue == 0 && data.byApartment.isEmpty) {
            return const _EmptyState();
          }
          return _buildBody(context, data);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      backgroundColor:  AppColors.background(context),
      elevation:        0,
      scrolledUnderElevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:         AppColors.card(context),
            borderRadius: BorderRadius.circular(12),
            border:        Border.all(color: AppColors.border),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size:  16,
              color: AppColors.text(context)),
        ),
      ),
      title: Text(
        'Revenue Analytics',
        style: TextStyle(
          fontSize:      18,
          fontWeight:    FontWeight.w800,
          color:         AppColors.text(context),
          letterSpacing: -.4,
        ),
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:         AppColors.orangeLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.bar_chart_rounded,
                size: 14, color: AppColors.primaryOrange),
            SizedBox(width: 5),
            Text('Host',
                style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                    color:      AppColors.primaryOrange)),
          ]),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, _RevenueData data) {
    final maxApt = data.byApartment.isNotEmpty
        ? data.byApartment.first.total
        : 1.0;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([

              // ── 0 · Hero revenue card ──────────────────────────────
              _section(0, _HeroRevenueCard(
                totalRevenue:  data.totalRevenue,
                totalPayments: data.recent.length,
                aptCount:      data.byApartment.length,
                masterCtrl:    _masterCtrl,
              )),

              const SizedBox(height: 28),

              // ── 1 · Revenue by apartment header ───────────────────
              _section(1, _SectionHeader(
                title:    'Revenue by Apartment',
                subtitle: '${data.byApartment.length} propert${data.byApartment.length == 1 ? 'y' : 'ies'}',
                icon:     Icons.apartment_rounded,
              )),

              const SizedBox(height: 14),

              // ── 2 · Apartment cards ────────────────────────────────
              _section(2, _ApartmentRevenueList(
                items:    data.byApartment,
                maxValue: maxApt,
                total:    data.totalRevenue,
                ctrl:     _masterCtrl,
              )),

              const SizedBox(height: 28),

              // ── 3 · Recent payments ────────────────────────────────
              _section(3, _SectionHeader(
                title:    'Recent Payments',
                subtitle: 'Last ${data.recent.length} transactions',
                icon:     Icons.receipt_long_rounded,
              )),

              const SizedBox(height: 14),

              _section(3, _RecentPaymentsList(
                  payments: data.recent)),

              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HERO REVENUE CARD
//  Gradient hero with count-up animation, three stat chips
// ═════════════════════════════════════════════════════════════════════════════

class _HeroRevenueCard extends StatelessWidget {
  final double            totalRevenue;
  final int               totalPayments;
  final int               aptCount;
  final AnimationController masterCtrl;

  const _HeroRevenueCard({
    required this.totalRevenue,
    required this.totalPayments,
    required this.aptCount,
    required this.masterCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8C00), Color(0xFFF5A623), Color(0xFFFFB74D)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color:      AppColors.primaryOrange.withOpacity(.40),
            blurRadius: 32,
            offset:     const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // top row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color:         Colors.white.withOpacity(.22),
                  borderRadius: BorderRadius.circular(20),
                  border:        Border.all(
                      color: Colors.white.withOpacity(.30), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up_rounded,
                        size: 13, color: Colors.white),
                    SizedBox(width: 5),
                    Text('Total Revenue',
                        style: TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.w700,
                            color:      Colors.white,
                            letterSpacing: .3)),
                  ],
                ),
              ),
              Container(
                width:  42,
                height: 42,
                decoration: BoxDecoration(
                  color:         Colors.white.withOpacity(.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.monetization_on_rounded,
                    color: Colors.white, size: 22),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // count-up amount
          _CountUpAmount(
            target:     totalRevenue,
            controller: masterCtrl,
          ),

          const SizedBox(height: 4),
          Text(
            'All time successful payments',
            style: TextStyle(
              fontSize: 12.5,
              color:    Colors.white.withOpacity(.78),
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 20),

          // stat chips row
          Row(children: [
            _StatChip(
              label: '$totalPayments',
              sub:   'Payments',
              icon:  Icons.payments_outlined,
            ),
            const SizedBox(width: 10),
            _StatChip(
              label: '$aptCount',
              sub:   'Properties',
              icon:  Icons.apartment_outlined,
            ),
            const SizedBox(width: 10),
            _StatChip(
              label: _avgLabel(totalRevenue, totalPayments),
              sub:   'Avg / Pay',
              icon:  Icons.calculate_outlined,
            ),
          ]),
        ],
      ),
    );
  }

  String _avgLabel(double total, int count) {
    if (count == 0) return '₱0';
    final avg = total / count;
    if (avg >= 1000) {
      return '₱${(avg / 1000).toStringAsFixed(1)}k';
    }
    return '₱${avg.toStringAsFixed(0)}';
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  const _StatChip(
      {required this.label, required this.sub, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color:         Colors.white.withOpacity(.18),
            borderRadius: BorderRadius.circular(14),
            border:        Border.all(
                color: Colors.white.withOpacity(.25), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 14, color: Colors.white.withOpacity(.85)),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize:   14,
                  fontWeight: FontWeight.w800,
                  color:      Colors.white,
                  letterSpacing: -.2,
                ),
              ),
              Text(sub,
                  style: TextStyle(
                      fontSize: 10,
                      color:    Colors.white.withOpacity(.72),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
}

// count-up animation for total revenue
class _CountUpAmount extends StatelessWidget {
  final double             target;
  final AnimationController controller;
  const _CountUpAmount(
      {required this.target, required this.controller});

  @override
  Widget build(BuildContext context) {
    final anim = Tween<double>(begin: 0, end: target).animate(
      CurvedAnimation(
        parent: controller,
        curve:  const Interval(0, .55, curve: Curves.easeOutCubic),
      ),
    );

    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final v = anim.value;
        final formatted =
            '₱${NumberFormat('#,##0', 'en_US').format(v.round())}';
        return Text(
          formatted,
          style: const TextStyle(
            fontSize:      40,
            fontWeight:    FontWeight.w900,
            color:         Colors.white,
            letterSpacing: -1.2,
            height:        1.0,
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SECTION HEADER
// ═════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String   title;
  final String   subtitle;
  final IconData icon;
  const _SectionHeader(
      {required this.title,
      required this.subtitle,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width:  36,
        height: 36,
        decoration: BoxDecoration(
          color:         AppColors.orangeLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.primaryOrange),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          title,
          style: TextStyle(
            fontSize:      16,
            fontWeight:    FontWeight.w800,
            color:         AppColors.text(context),
            letterSpacing: -.3,
          ),
        ),
        Text(subtitle,
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.textMid)),
      ]),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  APARTMENT REVENUE LIST
// ═════════════════════════════════════════════════════════════════════════════

class _ApartmentRevenueList extends StatelessWidget {
  final List<_AptRevenue> items;
  final double            maxValue;
  final double            total;
  final AnimationController ctrl;

  const _ApartmentRevenueList({
    required this.items,
    required this.maxValue,
    required this.total,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _InlineEmpty(
          message: 'No apartment revenue data yet');
    }
    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final share = total > 0 ? item.total / total : 0.0;
        return _ApartmentRevenueCard(
          rank:     i + 1,
          item:     item,
          maxValue: maxValue,
          share:    share,
          ctrl:     ctrl,
          delay:    i * .04,
        );
      }),
    );
  }
}

class _ApartmentRevenueCard extends StatelessWidget {
  final int               rank;
  final _AptRevenue       item;
  final double            maxValue;
  final double            share;
  final AnimationController ctrl;
  final double            delay;

  const _ApartmentRevenueCard({
    required this.rank,
    required this.item,
    required this.maxValue,
    required this.share,
    required this.ctrl,
    required this.delay,
  });

  static const _rankColors = [
    Color(0xFFF5A623), // gold
    Color(0xFF94A3B8), // silver
    Color(0xFFCD7F32), // bronze
  ];

  @override
  Widget build(BuildContext context) {
    final rankColor = rank <= 3
        ? _rankColors[rank - 1]
        : AppColors.textLight;

    // bar fill animation
    final barAnim = Tween<double>(begin: 0, end: item.total / maxValue)
        .animate(CurvedAnimation(
          parent: ctrl,
          curve:  Interval(
              math.min(delay + .35, .95),
              math.min(delay + .75, 1.0),
              curve: Curves.easeOutCubic),
        ));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:         AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border:        Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(.04),
              blurRadius: 14,
              offset:     const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(children: [

            // rank badge
            Container(
              width:  34,
              height: 34,
              decoration: BoxDecoration(
                color:         rankColor.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w800,
                    color:      rankColor,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // name + bookings
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.aptName,
                    style: TextStyle(
                      fontSize:   14.5,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.text(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.bookings} booking${item.bookings == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMid),
                  ),
                ],
              ),
            ),

            // total revenue
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₱${NumberFormat('#,##0', 'en_US').format(item.total)}',
                  style: const TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.w800,
                    color:      AppColors.primaryOrange,
                    letterSpacing: -.3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color:         AppColors.orangeLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(share * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize:   10,
                        fontWeight: FontWeight.w700,
                        color:      AppColors.primaryOrange),
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 12),

          // animated progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedBuilder(
              animation: barAnim,
              builder: (_, __) => LinearProgressIndicator(
                value:            barAnim.value.clamp(0.0, 1.0),
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primaryOrange),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  RECENT PAYMENTS LIST
// ═════════════════════════════════════════════════════════════════════════════

class _RecentPaymentsList extends StatelessWidget {
  final List<_PaymentRecord> payments;
  const _RecentPaymentsList({required this.payments});

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const _InlineEmpty(message: 'No recent payments');
    }
    return Container(
      decoration: BoxDecoration(
        color:         AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border:        Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(.04),
              blurRadius: 14,
              offset:     const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: List.generate(payments.length, (i) {
          final p = payments[i];
          final isLast = i == payments.length - 1;
          return Column(children: [
            _PaymentRow(payment: p),
            if (!isLast)
              Divider(
                height: 1,
                indent: 68,
                endIndent: 16,
                color: AppColors.border,
              ),
          ]);
        }),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final _PaymentRecord payment;
  const _PaymentRow({required this.payment});

  static const _methodIcons = <String, IconData>{
    'card':          Icons.credit_card_rounded,
    'gcash':         Icons.account_balance_wallet_rounded,
    'maya':          Icons.phone_android_rounded,
    'bank':          Icons.account_balance_rounded,
    'cash':          Icons.payments_rounded,
    'stripe':        Icons.credit_card_rounded,
    'paymongo':      Icons.payment_rounded,
  };

  static const _methodColors = <String, Color>{
    'card':     Color(0xFF3B82F6),
    'gcash':    Color(0xFF0040DD),
    'maya':     Color(0xFF00A651),
    'bank':     Color(0xFF6366F1),
    'cash':     Color(0xFF10B981),
    'stripe':   Color(0xFF635BFF),
    'paymongo': Color(0xFF0057FF),
  };

  @override
  Widget build(BuildContext context) {
    final methodKey = payment.method.toLowerCase();
    final icon  = _methodIcons[methodKey]  ?? Icons.payment_rounded;
    final color = _methodColors[methodKey] ?? AppColors.primaryOrange;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [

        // method icon container
        Container(
          width:  44,
          height: 44,
          decoration: BoxDecoration(
            color:         color.withOpacity(.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 20),
        ),

        const SizedBox(width: 12),

        // apt name + method + date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payment.aptName,
                style: TextStyle(
                  fontSize:   13.5,
                  fontWeight: FontWeight.w700,
                  color:      AppColors.text(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(children: [
                Text(
                  _capitalise(payment.method),
                  style: TextStyle(
                      fontSize: 11.5,
                      color:    color,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  '  ·  ${DateFormat('MMM d, yyyy').format(payment.date)}',
                  style: const TextStyle(
                      fontSize: 11.5,
                      color:    AppColors.textLight),
                ),
              ]),
            ],
          ),
        ),

        // amount
        Text(
          '₱${NumberFormat('#,##0', 'en_US').format(payment.amount)}',
          style: const TextStyle(
            fontSize:   14,
            fontWeight: FontWeight.w800,
            color:      AppColors.primaryOrange,
            letterSpacing: -.2,
          ),
        ),
      ]),
    );
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ═════════════════════════════════════════════════════════════════════════════
//  EMPTY / ERROR STATES
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width:  80,
              height: 80,
              decoration: BoxDecoration(
                  color:         AppColors.orangeLight,
                  shape: BoxShape.circle),
              child: const Icon(Icons.bar_chart_rounded,
                  size: 38, color: AppColors.primaryOrange),
            ),
            const SizedBox(height: 20),
            Text(
              'No revenue data yet',
              style: TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.w700,
                color:      AppColors.text(context),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Successful payments will appear here once tenants start booking.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5,
                  color:    AppColors.textMid,
                  height:   1.5),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text('Failed to load revenue',
                style: TextStyle(
                    fontSize:   17,
                    fontWeight: FontWeight.w600,
                    color:      AppColors.text(context))),
            const SizedBox(height: 8),
            Text(error,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMid),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final String message;
  const _InlineEmpty({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color:         AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border:        Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          const Icon(Icons.inbox_outlined,
              size: 36, color: AppColors.textLight),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(
                  fontSize:   13.5,
                  color:      AppColors.textMid,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}
