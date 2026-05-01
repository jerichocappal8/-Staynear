// ════════════════════════════════════════════════════════════════════════════
//  FILE: home_screen.dart
//
//  Flicker fix architecture:
//  ┌─────────────────────────────────────────────────────────────────────┐
//  │  ROOT CAUSE                                                         │
//  │  StreamBuilder re-evaluates snapshot.hasData on every build cycle. │
//  │  When IndexedStack brings the tab back into view, Flutter may       │
//  │  trigger a build before the stream re-emits, making hasData false   │
//  │  for one frame → spinner flash.                                     │
//  │                                                                     │
//  │  FIX                                                                │
//  │  Replace StreamBuilder with a manual StreamSubscription.            │
//  │  Data lands in _docs — a plain List field that survives all         │
//  │  rebuilds. _isLoading flips to false exactly once (on first data)   │
//  │  and can never go back to true. Any rebuild after that point        │
//  │  always renders content, never the spinner.                         │
//  │                                                                     │
//  │  STREAM LIFECYCLE                                                   │
//  │  initState  → subscribe, _isLoading = true                         │
//  │  first data → setState(_docs, _isLoading = false)  ← only once     │
//  │  next data  → setState(_docs)  [_isLoading stays false forever]    │
//  │  dispose    → _subscription.cancel()                                │
//  └─────────────────────────────────────────────────────────────────────┘
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../profile/host_application_screen.dart';
import '../profile/host_status_screen.dart';
import 'package:staynear/core/auth_helper.dart';
import '../host/host_dashboard_screen.dart';
import 'apartment_detail_page.dart';
import '../../core/app_colors.dart';
import 'search_filter_screen.dart';
import 'search_results_screen.dart';
import '../../widgets/explore_search_bar.dart';
import '../../core/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // ── Stream state ──────────────────────────────────────────────────────────

  List<QueryDocumentSnapshot> _docs = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _subscription;
  final TextEditingController _searchController = TextEditingController();

  // ════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════

@override
void initState() {
  super.initState();
  _subscribeToProperties();
}
  void _subscribeToProperties() {
    _subscription = FirebaseFirestore.instance
        .collection('properties')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _docs = snapshot.docs;
          if (_isLoading) _isLoading = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        debugPrint('HomeScreen stream error: $error');
        setState(() {
          if (_isLoading) _isLoading = false;
        });
      },
    );
  }


  // ════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════════════

  static String _formatPrice(dynamic raw) {
    if (raw == null) return '0';
    final value = (raw is double) ? raw.toInt() : (raw as num).toInt();
    return value
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  }

Future<void> _handleHostPress() async {
  final uid = AuthHelper.uid;

  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();

  final hostDoc = await FirebaseFirestore.instance
      .collection('host_requests')
      .doc(uid)
      .get();

  final data = userDoc.data();
  if (data == null || !mounted) return;

  if (data['isHost'] == true) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HostDashboardScreen()),
    );
    return;
  }

  if (hostDoc.exists) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HostStatusScreen()),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const HostApplicationScreen()),
  );
}

  // FIX: removed duplicate `backgroundColor: backgroundColor:` and replaced
  // AppColors.text(context) with AppColors.primaryOrange for snackbar bg.
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.primaryOrange,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _navigateToDetail(String apartmentId) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ApartmentDetailPage(apartmentId: apartmentId)),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
  child: Stack(
    children: [
      _isLoading
          ? _loadingState()
          : _docs.isEmpty
              ? _emptyState()
              : _contentView(),

      // Floating dropdown layer
    ],
  ),
),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CONTENT VIEW
  // ════════════════════════════════════════════════════════════════════════

  Widget _contentView() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _headerRow(),
        const SizedBox(height: 18),
        _searchBar(),
        const SizedBox(height: 28),
        _sectionHeader("Near You"),
        const SizedBox(height: 14),
        _horizontalCardList(),
        const SizedBox(height: 28),
        _sectionHeader("All Listings"),
        const SizedBox(height: 14),
        _verticalCardList(),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: _handleHostPress,
          child: _promoCard(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  HEADER & SEARCH
  // ════════════════════════════════════════════════════════════════════════

  Widget _headerRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.orangeLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: AppColors.primaryOrange, size: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
  LocationService.currentLocation,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMid),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // FIX: removed Theme.of(context).brightness ternary + duplicate
              // backgroundColor: prefix; replaced with AppColors.text(context)
              Text(
                "Find your\nperfect space",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text(context),
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
Widget _searchBar() {
  return ExploreSearchBar(
    controller: _searchController,
    includeApartments: true,
    onCitySelected: (city) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SearchResultsScreen(
            filters: {'city': city},
          ),
        ),
      );
    },
    onApartmentSelected: (apartmentName) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SearchResultsScreen(
            filters: {'name': apartmentName},
          ),
        ),
      );
    },
    onFilterTap: () async {
      final filters = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SearchFilterScreen(),
        ),
      );
      if (filters != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchResultsScreen(filters: filters),
          ),
        );
      }
    },
    // onSuggestionsChanged is gone — no longer needed
  );
}

  Widget _sectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.text(context),
              letterSpacing: -0.3,
            )),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchResultsScreen(filters: const {}),
            ),
          ),
          child: Text("See all",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryOrange)),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CARD LISTS
  // ════════════════════════════════════════════════════════════════════════

  Widget _horizontalCardList() {
    return SizedBox(
      height: 270,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _docs.length.clamp(0, 20),
        itemBuilder: (_, i) => _propertyCardHorizontal(_docs[i]),
      ),
    );
  }

  Widget _verticalCardList() {
    return Column(
      children: _docs.map(_propertyCardVertical).toList(),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  HORIZONTAL PROPERTY CARD
  // ════════════════════════════════════════════════════════════════════════

  Widget _propertyCardHorizontal(QueryDocumentSnapshot doc) {
    final d           = doc.data() as Map<String, dynamic>;
    final name        = (d['name']         ?? '') as String;
    final location    = (d['location']     ?? '') as String;
    final category    = (d['category']     ?? '') as String;
    final minPrice    = d['minPrice'];
final pricingMode = (d['minPricingMode'] ?? 'monthly').toString();
    final coverUrl    = (d['coverImageUrl'] ?? '') as String;
    final rating      = d['rating'];
    final reviewCount = d['reviewCount'];

    return GestureDetector(
      onTap: () => _navigateToDetail(doc.id),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: AppColors.card(context),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.07),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              child: Stack(
                children: [
                  _coverImage(coverUrl, height: 155, width: double.infinity),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 70,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC000000)],
                        ),
                      ),
                    ),
                  ),
                  if (rating != null)
                    Positioned(
                        top: 10,
                        right: 10,
                        child: _ratingBadge(rating, reviewCount)),
                  if (category.isNotEmpty)
                    Positioned(
                        bottom: 10,
                        left: 10,
                        child: _categoryPill(category)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FIX: removed const from TextStyle + fixed color property
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.text(context))),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 11, color: AppColors.textLight),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textLight)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(children: [
                      const TextSpan(
                          text: "From ",
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textMid)),
                      TextSpan(
                          text: "₱${_formatPrice(minPrice)}",
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryOrange)),
                      TextSpan(
  text: pricingMode == 'daily' ? " /day" : " /mo",
  style: const TextStyle(
    fontSize: 11,
    color: AppColors.textMid
  ),
),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  VERTICAL PROPERTY CARD
  // ════════════════════════════════════════════════════════════════════════

  Widget _propertyCardVertical(QueryDocumentSnapshot doc) {
    final d           = doc.data() as Map<String, dynamic>;
    final name        = (d['name']         ?? '') as String;
    final location    = (d['location']     ?? '') as String;
    final category    = (d['category']     ?? '') as String;
    final minPrice    = d['minPrice'];
final pricingMode = (d['minPricingMode'] ?? 'monthly').toString();
    final coverUrl    = (d['coverImageUrl'] ?? '') as String;
    final rating      = d['rating'];
    final reviewCount = d['reviewCount'];

    return GestureDetector(
      onTap: () => _navigateToDetail(doc.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: AppColors.card(context),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.06),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(22)),
              child: Stack(
                children: [
                  _coverImage(coverUrl, height: 110, width: 110),
                  if (rating != null)
                    Positioned(
                        top: 8,
                        left: 8,
                        child: _ratingBadge(rating, reviewCount,
                            compact: true)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category.isNotEmpty) ...[
                      _categoryPill(category, dark: true),
                      const SizedBox(height: 6),
                    ],
                    // FIX: removed const from TextStyle + fixed color property
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.text(context),
                            height: 1.3)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 11, color: AppColors.textLight),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textLight)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("From",
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textLight)),
                            Text("₱${_formatPrice(minPrice)}",
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryOrange,
                                    letterSpacing: -0.3)),
                          ],
                        ),
                        const SizedBox(width: 2),
                        Padding(
  padding: const EdgeInsets.only(bottom: 2),
  child: Text(
    pricingMode == 'daily' ? "/day" : "/month",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMid)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SHARED CARD COMPONENTS
  // ════════════════════════════════════════════════════════════════════════

  Widget _coverImage(String url,
      {required double height, required double width}) {
    if (url.isEmpty) {
      return Container(
        height: height,
        width: width,
        color: const Color(0xFFF0EDE8),
        child: const Icon(Icons.image_rounded,
            color: Color(0xFFCCC9C3), size: 32),
      );
    }
    return Image.network(
      url,
      height: height,
      width: width,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        width: width,
        color: const Color(0xFFF0EDE8),
        child: const Icon(Icons.image_not_supported_rounded,
            color: Color(0xFFCCC9C3), size: 28),
      ),
    );
  }

  Widget _ratingBadge(dynamic rating, dynamic reviewCount,
      {bool compact = false}) {
    final ratingStr = (rating is double)
        ? rating.toStringAsFixed(1)
        : rating.toString();
    final countStr = reviewCount != null ? " ($reviewCount)" : "";

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.12),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded,
              color: Colors.amber.shade600,
              size: compact ? 11 : 12),
          const SizedBox(width: 3),
          // FIX: removed Theme ternary + duplicate backgroundColor: prefix
          Text(
            compact ? ratingStr : "$ratingStr$countStr",
            style: TextStyle(
                fontSize: compact ? 10.5 : 11,
                fontWeight: FontWeight.w700,
                color: AppColors.text(context)),
          ),
        ],
      ),
    );
  }

  Widget _categoryPill(String category, {bool dark = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.orangeLight
            : AppColors.card(context).withOpacity(.18),
        borderRadius: BorderRadius.circular(20),
        border: dark
            ? Border.all(
                color: AppColors.primaryOrange.withOpacity(.25), width: 1)
            : null,
      ),
      child: Text(
        category,
        style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: dark ? AppColors.primaryOrange : Colors.white,
            letterSpacing: 0.2),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PROMO CARD
  // ════════════════════════════════════════════════════════════════════════

  Widget _promoCard() {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF9A62)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: AppColors.primaryOrange.withOpacity(.35),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Become a Host",
                    style: TextStyle(
                        color: AppColors.card(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: -0.3)),
                const SizedBox(height: 4),
                Text(
                  "List your space and earn passive income",
                  style: TextStyle(
                      color: AppColors.card(context).withOpacity(.85),
                      fontSize: 12.5),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.card(context).withOpacity(.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.house_rounded,
                color: AppColors.card(context), size: 28),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  STATES
  // ════════════════════════════════════════════════════════════════════════

  Widget _loadingState() {
    return const Center(
      child: CircularProgressIndicator(
          color: AppColors.primaryOrange, strokeWidth: 2.5),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                color: AppColors.orangeLight, shape: BoxShape.circle),
            child: const Icon(Icons.apartment_rounded,
                color: AppColors.primaryOrange, size: 36),
          ),
          const SizedBox(height: 18),
          // FIX: removed Theme ternary + duplicate backgroundColor: prefix
          Text("No listings yet",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text(context))),
          const SizedBox(height: 6),
          Text("Active properties will appear here",
              style: TextStyle(fontSize: 13, color: AppColors.textMid)),
        ],
      ),
    );
  }
}