// host_dashboard_screen.dart
// ════════════════════════════════════════════════════════════════════════════
//  StayNear — Host Dashboard Screen  (gesture fix + Reviews card)
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'all_apartments_screen.dart';
import 'active_apartments_screen.dart';
import 'add_apartment_screen.dart';
import 'host_bottom_nav.dart';
import 'package:staynear/core/app_colors.dart';
import 'revenue_page.dart';
import '../chat/chat_list_host_screen.dart';
import 'host_profile_screen.dart';
import '../../core/animations/slide_page_route.dart';
import 'host_reviews_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen>
    with TickerProviderStateMixin {

  // ── original logic (unchanged) ─────────────────────────────────────────────
  String get uid => FirebaseAuth.instance.currentUser!.uid;

  // ── staggered section animations ──────────────────────────────────────────
  late final List<AnimationController> _ctrl;
  late final List<Animation<double>>   _fade;
  late final List<Animation<Offset>>   _slide;

  // ── stat card scale controllers (one per card) ─────────────────────────────
  // FIX: Use AnimationControllers instead of setState for scale to avoid
  // "setState called when widget tree was locked" during long-press / drag.
  late final List<AnimationController> _cardScaleCtrl;
  late final List<Animation<double>>   _cardScaleAnim;

  @override
  void initState() {
    super.initState();

    // 5 sections: header, stats, listings-header, listings-body, cta
    _ctrl = List.generate(
      5,
      (i) => AnimationController(
        vsync:    this,
        duration: const Duration(milliseconds: 560),
      ),
    );

    _fade = _ctrl.map((c) =>
      CurvedAnimation(parent: c, curve: Curves.easeOut)
        as Animation<double>
    ).toList();

    _slide = _ctrl.map((c) =>
      Tween<Offset>(begin: const Offset(0, .06), end: Offset.zero)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic))
    ).toList();

    // staggered fire
    for (int i = 0; i < _ctrl.length; i++) {
      Future.delayed(Duration(milliseconds: 60 + i * 90), () {
        if (mounted) _ctrl[i].forward();
      });
    }

    // FIX: One AnimationController per stat card for safe press animation.
    // This avoids calling setState() inside gesture callbacks while the
    // framework is building / laying out the widget tree (e.g. on long-press).
    _cardScaleCtrl = List.generate(
      4,
      (_) => AnimationController(
        vsync:    this,
        duration: const Duration(milliseconds: 120),
        reverseDuration: const Duration(milliseconds: 180),
      ),
    );

    _cardScaleAnim = _cardScaleCtrl.map((c) =>
      Tween<double>(begin: 1.0, end: 0.955).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOut),
      ),
    ).toList();
  }

  @override
  void dispose() {
    for (final c in _ctrl) c.dispose();
    for (final c in _cardScaleCtrl) c.dispose();
    super.dispose();
  }

  // ── section wrapper ────────────────────────────────────────────────────────
  Widget _s(int i, Widget child) => FadeTransition(
        opacity: _fade[i],
        child:   SlideTransition(position: _slide[i], child: child),
      );

  // ── safe card press handlers ───────────────────────────────────────────────
  // FIX: Use controller.forward/reverse instead of setState so the animation
  // is driven purely by the AnimationController and never touches the
  // widget tree during a locked build phase.
  void _onCardDown(int i) {
    HapticFeedback.lightImpact();
    _cardScaleCtrl[i].forward();
  }

  void _onCardUp(int i, VoidCallback? onTap) {
    _cardScaleCtrl[i].reverse().then((_) => onTap?.call());
  }

  void _onCardCancel(int i) {
    _cardScaleCtrl[i].reverse();
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // original Firestore ref — UNCHANGED
    final propertiesRef = FirebaseFirestore.instance
        .collection('properties')
        .where('ownerId', isEqualTo: uid);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // swipe LEFT → go to Messages
        if (details.primaryVelocity! < 0) {
          Navigator.pushReplacement(
            context,
            SlidePageRoute(
              page: ChatListHostScreen(
                hostId: FirebaseAuth.instance.currentUser!.uid,
              ),
            ),
          );
        }
      },

      child: Scaffold(
        backgroundColor: AppColors.background(context),

        body: StreamBuilder<QuerySnapshot>(
          stream: propertiesRef.snapshots(),
          builder: (context, snapshot) {

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primaryOrange, strokeWidth: 2.5),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: Text('No data'));
            }

            final docs   = snapshot.data!.docs;
            final total  = docs.length;
            final active = docs
                .where((d) => (d['isActive'] ?? false) == true)
                .length;
            final recent = docs.take(3).toList();

            final inquiriesTotal = 0;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [

                SliverToBoxAdapter(
                  child: _s(0, _HeroHeader(
                    total:  total,
                    active: active,
                  )),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      const SizedBox(height: 2),

                      _s(1, _buildStatsGrid(
                        context,
                        total:  total,
                        active: active,
                      )),

                      const SizedBox(height: 32),

                      _s(2, _SectionHeader(
                        title:    'Recent Listings',
                        action:   'See all',
                        onAction: () {},
                      )),

                      const SizedBox(height: 14),

                      _s(3, _RecentListings(docs: recent)),

                      const SizedBox(height: 32),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),

        bottomNavigationBar: HostBottomNav(
          currentIndex: 0,
          onTap: (index) {
            if (index == 0) return;

            if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatListHostScreen(
                    hostId: FirebaseAuth.instance.currentUser!.uid,
                  ),
                ),
              );
            }

            if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HostProfileScreen(),
                ),
              );
            }
          },
        ),

        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 40,
            child: _AddApartmentButton(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddApartmentScreen(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  STATS GRID  — 2×2 cards with controller-driven scale animation
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStatsGrid(
    BuildContext context, {
    required int total,
    required int active,
  }) {
    final cards = [
      _StatCardData(
        index:  0,
        icon:   Icons.apartment_rounded,
        color:  const Color(0xFF3B82F6),
        number: total.toString(),
        label:  'Total Apartments',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AllApartmentsScreen()),
        ),
      ),
      _StatCardData(
        index:  1,
        icon:   Icons.home_rounded,
        color:  AppColors.primaryOrange,
        number: active.toString(),
        label:  'My Apartments',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ActiveApartmentsScreen()),
        ),
      ),
      _StatCardData(
        index:  2,
        icon:   Icons.payments_rounded,
        color:  const Color(0xFF10B981),
        number: '₱',
        label:  'Revenue',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RevenuePage()),
        ),
      ),
      // ── CHANGED: Inquiries → Reviews ──────────────────────────────────────
_StatCardData(
  index:  3,
  icon:   Icons.star_rounded,
  color:  const Color(0xFFF5A623),
  number: '★',
  label:  'Reviews',
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const HostReviewsScreen(),
    ),
  ),
),
    ];

    return GridView.count(
      shrinkWrap:      true,
      physics:         const NeverScrollableScrollPhysics(),
      crossAxisCount:  2,
      crossAxisSpacing: 14,
      mainAxisSpacing:  14,
      childAspectRatio: 1.05,
      children: cards.map((data) {
        return GestureDetector(
          // FIX: All callbacks are safe — they only call controller methods,
          // never setState, so they cannot trigger a build-phase conflict.
          onTapDown:   (_) => _onCardDown(data.index),
          onTapUp:     (_) => _onCardUp(data.index, data.onTap),
          onTapCancel: ()  => _onCardCancel(data.index),
          // Also handle long-press release safely
          onLongPressEnd: (_) => _onCardCancel(data.index),
          child: AnimatedBuilder(
            animation: _cardScaleAnim[data.index],
            builder: (context, child) => Transform.scale(
              scale: _cardScaleAnim[data.index].value,
              child: child,
            ),
            child: _StatCard(data: data),
          ),
        );
      }).toList(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HERO HEADER
// ═════════════════════════════════════════════════════════════════════════════

class _HeroHeader extends StatelessWidget {
  final int total;
  final int active;
  const _HeroHeader({required this.total, required this.active});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF0A0F25), Color(0xFF1C2541)],
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
              )
            : const LinearGradient(
                colors: [Color(0xFFFFF8EE), Color(0xFFF8F7F5)],
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
              ),
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color:      isDark
                ? Colors.black.withOpacity(.25)
                : AppColors.primaryOrange.withOpacity(.08),
            blurRadius: 24,
            offset:     const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── top row: greeting + avatar ───────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:         AppColors.primaryOrange.withOpacity(.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wb_sunny_rounded,
                                size: 11, color: AppColors.primaryOrange),
                            SizedBox(width: 5),
                            Text('Good morning',
                                style: TextStyle(
                                    fontSize:   11,
                                    fontWeight: FontWeight.w700,
                                    color:      AppColors.primaryOrange,
                                    letterSpacing: .3)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Host Dashboard',
                        style: TextStyle(
                          fontSize:      26,
                          fontWeight:    FontWeight.w900,
                          color:         AppColors.text(context),
                          letterSpacing: -.6,
                          height:        1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Here's your latest overview",
                        style: TextStyle(
                            fontSize: 13.5, color: AppColors.textMid),
                      ),
                    ],
                  ),

                  // avatar circle with orange ring
                  Container(
                    width:  52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.primaryOrange, width: 2.5),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8C00), AppColors.primaryOrange],
                        begin:  Alignment.topLeft,
                        end:    Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 28),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── quick stats strip ────────────────────────────────────
              Row(children: [
                Expanded(
                  child: _QuickStat(
                    value: total.toString(),
                    label: 'Properties',
                    icon:  Icons.apartment_rounded,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickStat(
                    value: active.toString(),
                    label: 'Active',
                    icon:  Icons.check_circle_rounded,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickStat(
                    value: (total - active).toString(),
                    label: 'Inactive',
                    icon:  Icons.pause_circle_rounded,
                    color: AppColors.textLight,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String   value;
  final String   label;
  final IconData icon;
  final Color    color;
  const _QuickStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCardSoft.withOpacity(.55)
            : Colors.white.withOpacity(.70),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark
                ? AppColors.darkCardSoft
                : AppColors.border.withOpacity(.6),
            width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.w900,
              color:      AppColors.text(context),
              letterSpacing: -.3,
            ),
          ),
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5, color: AppColors.textMid,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STAT CARD DATA MODEL
// ═════════════════════════════════════════════════════════════════════════════

class _StatCardData {
  final int           index;
  final IconData      icon;
  final Color         color;
  final String        number;
  final String        label;
  final VoidCallback? onTap;

  const _StatCardData({
    required this.index,
    required this.icon,
    required this.color,
    required this.number,
    required this.label,
    this.onTap,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
//  STAT CARD WIDGET
// ═════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final _StatCardData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final tappable = data.onTap != null;

    // Special glow for Reviews card (index 3)
    final isReviews = data.index == 3;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isReviews
              ? AppColors.primaryOrange.withOpacity(.25)
              : AppColors.border.withOpacity(.6),
        ),
        boxShadow: [
          BoxShadow(
            color: isReviews
                ? AppColors.primaryOrange.withOpacity(.12)
                : Colors.black.withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width:  44,
                height: 44,
                decoration: BoxDecoration(
                  // Reviews card gets a warm gradient badge
                  gradient: isReviews
                      ? const LinearGradient(
                          colors: [
                            Color(0xFFF5A623),
                            Color(0xFFFFCA6C),
                          ],
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight,
                        )
                      : null,
                  color: isReviews ? null : data.color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  data.icon,
                  color: isReviews ? Colors.white : data.color,
                  size:  22,
                ),
              ),
              if (tappable)
                Container(
                  width:  28,
                  height: 28,
                  decoration: BoxDecoration(
                    color:  data.color.withOpacity(.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 13, color: data.color),
                ),
            ],
          ),

          const Spacer(),

          // Reviews card shows a star rating display instead of a plain number
          if (isReviews) ...[
            Row(
              children: List.generate(5, (i) => Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  i < 4 ? Icons.star_rounded : Icons.star_half_rounded,
                  size:  16,
                  color: AppColors.primaryOrange,
                ),
              )),
            ),
            const SizedBox(height: 4),
          ] else ...[
            Text(
              data.number,
              style: TextStyle(
                fontSize:      26,
                fontWeight:    FontWeight.w900,
                color:         AppColors.text(context),
                letterSpacing: -.5,
                height:        1.0,
              ),
            ),
            const SizedBox(height: 4),
          ],

          Text(
            data.label,
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.textMid,
                fontWeight: FontWeight.w500),
          ),

          if (tappable) ...[
            const SizedBox(height: 10),
            Container(
              height: 3,
              width:  32,
              decoration: BoxDecoration(
                color:         data.color.withOpacity(.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],

          // Reviews card bottom accent
          if (isReviews) ...[
            const SizedBox(height: 10),
            Container(
              height: 3,
              width:  32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryOrange, Color(0xFFFFCA6C)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SECTION HEADER
// ═════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String       title;
  final String       action;
  final VoidCallback onAction;
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize:      18,
            fontWeight:    FontWeight.w800,
            color:         AppColors.text(context),
            letterSpacing: -.3,
          ),
        ),
        GestureDetector(
          onTap: onAction,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(action,
                style: const TextStyle(
                    fontSize:   13,
                    color:      AppColors.primaryOrange,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.primaryOrange),
          ]),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  RECENT LISTINGS
// ═════════════════════════════════════════════════════════════════════════════

class _RecentListings extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  const _RecentListings({required this.docs});

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color:         AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border:        Border.all(color: AppColors.border),
        ),
        child: const Column(children: [
          Icon(Icons.apartment_outlined,
              size: 36, color: AppColors.textLight),
          SizedBox(height: 8),
          Text('No listings yet',
              style: TextStyle(
                  color:      AppColors.textMid,
                  fontWeight: FontWeight.w500)),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color:         AppColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border:        Border.all(color: AppColors.border.withOpacity(.6)),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(.04),
              blurRadius: 16,
              offset:     const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: List.generate(docs.length, (i) {
          final data     = docs[i].data() as Map<String, dynamic>;
          final name     = data['name']     ?? 'Unnamed';
          final addr     = data['address']  ?? 'No location';
          final isActive = (data['isActive'] ?? false) == true;
          final isLast   = i == docs.length - 1;

          return Column(children: [
            _ListingRow(
              name:     name,
              address:  addr,
              isActive: isActive,
            ),
            if (!isLast)
              Divider(
                height:    1,
                indent:    20,
                endIndent: 20,
                color:     AppColors.border,
              ),
          ]);
        }),
      ),
    );
  }
}

class _ListingRow extends StatelessWidget {
  final String name;
  final String address;
  final bool   isActive;
  const _ListingRow({
    required this.name,
    required this.address,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [

        Container(
          width:  44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryOrange.withOpacity(.10)
                : AppColors.border.withOpacity(.5),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.apartment_rounded,
            size:  20,
            color: isActive ? AppColors.primaryOrange : AppColors.textLight,
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
                  fontWeight: FontWeight.w700,
                  fontSize:   14.5,
                  color:      AppColors.text(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 11, color: AppColors.textLight),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMid),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ],
          ),
        ),

        const SizedBox(width: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF10B981).withOpacity(.12)
                : AppColors.border.withOpacity(.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width:  6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF10B981)
                    : AppColors.textLight,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              isActive ? 'ACTIVE' : 'INACTIVE',
              style: TextStyle(
                fontSize:   10,
                fontWeight: FontWeight.w800,
                color:      isActive
                    ? const Color(0xFF059669)
                    : AppColors.textMid,
                letterSpacing: .3,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ADD APARTMENT CTA BUTTON
// ═════════════════════════════════════════════════════════════════════════════

class _AddApartmentButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddApartmentButton({required this.onTap});

  @override
  State<_AddApartmentButton> createState() => _AddApartmentButtonState();
}

class _AddApartmentButtonState extends State<_AddApartmentButton>
    with SingleTickerProviderStateMixin {
  // FIX: Use AnimationController here too for consistency and safety.
  late final AnimationController _ctrl;
  late final Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
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
    return GestureDetector(
      onTapDown:   (_) { HapticFeedback.lightImpact(); _ctrl.forward(); },
      onTapUp:     (_) { _ctrl.reverse().then((_) => widget.onTap()); },
      onTapCancel: ()  { _ctrl.reverse(); },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          height: 60,
          width:  double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8C00), AppColors.primaryOrange],
              begin:  Alignment.centerLeft,
              end:    Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color:      AppColors.primaryOrange.withOpacity(.40),
                blurRadius: 22,
                offset:     const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_rounded, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text(
                'Add Apartment',
                style: TextStyle(
                  color:         Colors.white,
                  fontWeight:    FontWeight.w800,
                  fontSize:      16,
                  letterSpacing: -.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}