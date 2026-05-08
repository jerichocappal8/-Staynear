// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/features/home/explore_screen.dart
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_colors.dart';
import '../../widgets/explore_search_bar.dart';
import 'apartment_detail_page.dart';
import 'search_filter_screen.dart';
import 'search_results_screen.dart';
import '../../core/location_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TOP-LEVEL DATA  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
const _kCategories = [
  _Category(label: 'Boarding House', icon: Icons.home_work_rounded),
  _Category(label: 'Apartment', icon: Icons.apartment_rounded),
  _Category(label: 'Whole House', icon: Icons.house_rounded),
  _Category(label: 'Studio', icon: Icons.single_bed_rounded),
  _Category(label: 'Condo Unit', icon: Icons.location_city_rounded),
  _Category(label: 'Hotel', icon: Icons.hotel_rounded),
];

const _kLocations = [
  _Location(city: 'Urdaneta City', icon: Icons.location_city_rounded, bgColor: Color(0xFFFFF0E0), iconColor: Color(0xFFBF360C)),
  _Location(city: 'Dagupan City',  icon: Icons.water_rounded,          bgColor: Color(0xFFE0F4FF), iconColor: Color(0xFF01579B)),
  _Location(city: 'Binalonan',     icon: Icons.forest_rounded,         bgColor: Color(0xFFE8F5E9), iconColor: Color(0xFF1B5E20)),
  _Location(city: 'Mangaldan',     icon: Icons.landscape_rounded,      bgColor: Color(0xFFF3E5F5), iconColor: Color(0xFF4A148C)),
  _Location(city: 'San Carlos',    icon: Icons.home_work_rounded,      bgColor: Color(0xFFFFEBEE), iconColor: Color(0xFFB71C1C)),
];

const _kBudgets = [
  _Budget(label: 'Under ₱2,000',   minPrice: 0,    maxPrice: 2000),
  _Budget(label: '₱2,000–₱7,000', minPrice: 2000, maxPrice: 7000),
  _Budget(label: '₱7,000+',        minPrice: 7000, maxPrice: 1000000000000),
];

// ─────────────────────────────────────────────────────────────────────────────
//  IMMUTABLE DATA MODELS  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _Category {
  final String label;
  final IconData icon;
  const _Category({required this.label, required this.icon});
}

class _Location {
  final String   city;
  final IconData icon;
  final Color    bgColor;
  final Color    iconColor;
  const _Location({
    required this.city,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });
}

class _Budget {
  final String label;
  final double minPrice;
  final double maxPrice;
  const _Budget({required this.label, required this.minPrice, required this.maxPrice});
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {

  // ── Search controller ─────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();

  // ── Newly-added listings ──────────────────────────────────────────────────
  List<QueryDocumentSnapshot> _newListings = [];
  bool _newLoading = true;
  StreamSubscription<QuerySnapshot>? _newSub;
  // ── Location listing counts ───────────────────────────────────────────────
  Map<String, int> _locationCounts = {};
  bool _countsLoaded = false;

  // ════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════

@override
void initState() {
  super.initState();
  _subscribeToNewListings();
  _loadLocationCounts();
}
  @override
  void dispose() {
    _searchCtrl.dispose();
    _newSub?.cancel();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  FIRESTORE  (unchanged)
  // ════════════════════════════════════════════════════════════════════════

  void _subscribeToNewListings() {
    _newSub = FirebaseFirestore.instance
        .collection('properties')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        setState(() {
          _newListings = snap.docs;
          if (_newLoading) _newLoading = false;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _newLoading = false);
      },
    );
  }

  Future<void> _loadLocationCounts() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('properties')
          .where('isActive', isEqualTo: true)
          .get();

      final counts = <String, int>{};

      for (final doc in snap.docs) {
        // city field (current schema) takes priority over location (old schema).
        final _d = doc.data();
        String city = (_d['city'] as String? ?? _d['location'] as String? ?? '');
        city = city.trim().toLowerCase();

        if (city.contains('urdaneta'))       city = 'Urdaneta City';
        else if (city.contains('dagupan'))   city = 'Dagupan City';
        else if (city.contains('binalonan')) city = 'Binalonan';
        else if (city.contains('mangaldan')) city = 'Mangaldan';
        else if (city.contains('san carlos')) city = 'San Carlos City';

        counts[city] = (counts[city] ?? 0) + 1;
      }

      if (!mounted) return;
      setState(() {
        _locationCounts = counts;
        _countsLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _countsLoaded = true);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  NAVIGATION  (unchanged)
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _openFilters() async {
    final filters = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const SearchFilterScreen()),
    );
    if (filters != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SearchResultsScreen(filters: filters),
        ),
      );
    }
  }

  void _goToMap({Map<String, dynamic>? filters}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(filters: filters ?? {}),
      ),
    );
  }

  void _goToCategory(String category) => _goToMap(filters: {'category': category});
  void _goToLocation(String city)     => _goToMap(filters: {'city': city});
  void _goToBudget(_Budget b)         =>
      _goToMap(filters: {'minPrice': b.minPrice, 'maxPrice': b.maxPrice});

  /// Called when the user picks a city from the autocomplete dropdown.
  void _onCitySelected(String city) => _goToMap(filters: {'city': city});

  // ════════════════════════════════════════════════════════════════════════
  //  HELPERS  (unchanged)
  // ════════════════════════════════════════════════════════════════════════

  static String _fmtPrice(dynamic raw) {
    if (raw == null) return '0';
    final v = (raw is double) ? raw.toInt() : (raw as num).toInt();
    return v.toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExploreHeader(location: LocationService.currentLocation),
              const SizedBox(height: 18),

              // ── Search bar — now uses shared ExploreSearchBar ─────────
              ExploreSearchBar(
                controller:     _searchCtrl,
                onCitySelected: _onCitySelected,
                onFilterTap:    _openFilters,
                includeApartments: true,
              ),

              const SizedBox(height: 28),
              _MapExploreCard(onTap: _goToMap),
              const SizedBox(height: 28),
              _SectionTitle(title: 'Browse by Category'),
              const SizedBox(height: 14),
              _CategoryChips(categories: _kCategories, onTap: _goToCategory),
              const SizedBox(height: 28),
              _SectionTitle(title: 'Popular Locations'),
              const SizedBox(height: 14),
              _LocationCards(
                locations: _kLocations,
                counts:    _locationCounts,
                onTap:     _goToLocation,
              ),
              const SizedBox(height: 28),
              _SectionTitle(title: 'Budget Friendly'),
              const SizedBox(height: 14),
              _BudgetCards(budgets: _kBudgets, onTap: _goToBudget),
              const SizedBox(height: 28),
              _SectionTitle(title: 'Newly Added'),
              const SizedBox(height: 14),
              _NewListings(
                loading:  _newLoading,
                docs:     _newListings,
                onTap:    (id) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ApartmentDetailPage(apartmentId: id),
                  ),
                ),
                fmtPrice: _fmtPrice,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEADER  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _ExploreHeader extends StatelessWidget {

  final String location;

  const _ExploreHeader({required this.location});

  @override
  Widget build(BuildContext context) {
    return Column(
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
          child: const Icon(
            Icons.location_on_rounded,
            color: AppColors.primaryOrange,
            size: 14,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          location,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMid,
          ),
        ),
      ],
    ),

    const SizedBox(height: 8),

    Text(
      'Explore',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: AppColors.text(context),
        letterSpacing: -0.8,
        height: 1.05,
      ),
    ),

    const SizedBox(height: 4),

    Text(
      'Discover your next home',
      style: TextStyle(
        fontSize: 14,
        color: AppColors.textMid,
      ),
    ),
  ],
);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAP EXPLORE CARD  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _MapExploreCard extends StatelessWidget {
  final VoidCallback onTap;
  const _MapExploreCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color:      AppColors.textDark.withOpacity(.10),
              blurRadius: 22,
              offset:     const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/map_preview.png', fit: BoxFit.cover),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.centerLeft,
                    end:    Alignment.centerRight,
                    colors: [
                      AppColors.textDark.withOpacity(.75),
                      AppColors.textDark.withOpacity(.30),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:  MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:        AppColors.primaryOrange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.map_rounded,
                          color: AppColors.cardWhite, size: 20),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Explore apartments on the map',
                      style: TextStyle(
                          color:      AppColors.cardWhite,
                          fontSize:   16,
                          fontWeight: FontWeight.w800,
                          height:     1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Browse nearby places visually',
                      style: TextStyle(
                          color:    AppColors.cardWhite.withOpacity(.75),
                          fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 16,
                right:  16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color:        AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Open map',
                          style: TextStyle(
                              fontSize:   12,
                              fontWeight: FontWeight.w700,
                              color:      AppColors.textDark)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 13, color: AppColors.textDark),
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

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION TITLE  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize:      18,
        fontWeight:    FontWeight.w800,
        color:         AppColors.text(context),
        letterSpacing: -0.3,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CATEGORY CHIPS  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final List<_Category> categories;
  final void Function(String) onTap;

  const _CategoryChips({
    required this.categories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final cat = categories[i];

          return GestureDetector(
            onTap: () => onTap(cat.label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat.icon,
                    size: 16,
                    color: AppColors.textMid,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    cat.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMid,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  POPULAR LOCATION CARDS  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _LocationCards extends StatelessWidget {
  final List<_Location>       locations;
  final Map<String, int>      counts;
  final void Function(String) onTap;

  const _LocationCards({
    required this.locations,
    required this.counts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection:  Axis.horizontal,
        physics:          const BouncingScrollPhysics(),
        padding:          const EdgeInsets.only(right: 4),
        itemCount:        locations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final loc   = locations[i];
          final count = counts[loc.city];

          return GestureDetector(
            onTap: () => onTap(loc.city),
            child: Container(
              width: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color:        loc.bgColor,
                boxShadow: [
                  BoxShadow(
                      color:      AppColors.textDark.withOpacity(.06),
                      blurRadius: 14,
                      offset:     const Offset(0, 5)),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(loc.icon, size: 28, color: loc.iconColor),
                  const Spacer(),
                  Text(loc.city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize:   13.5,
                          fontWeight: FontWeight.w800,
                          color:      AppColors.textDark)),
                  if (count != null) ...[
                    const SizedBox(height: 2),
                    Text('$count listing${count == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMid)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BUDGET CARDS  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetCards extends StatelessWidget {
  final List<_Budget>          budgets;
  final void Function(_Budget) onTap;
  const _BudgetCards({required this.budgets, required this.onTap});

  static const _gradients = [
    [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
    [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
    [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection:  Axis.horizontal,
        physics:          const BouncingScrollPhysics(),
        padding:          const EdgeInsets.only(right: 4),
        itemCount:        budgets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final b = budgets[i];
          final g = _gradients[i % _gradients.length];

          return GestureDetector(
            onTap: () => onTap(b),
            child: Container(
              width: 155,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                    colors: g,
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight),
                boxShadow: [
                  BoxShadow(
                      color:      AppColors.textDark.withOpacity(.06),
                      blurRadius: 12,
                      offset:     const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:  MainAxisAlignment.center,
                children: [
                  Text(b.label,
                      style: const TextStyle(
                          fontSize:      14,
                          fontWeight:    FontWeight.w800,
                          color:         AppColors.textDark,
                          letterSpacing: -0.2)),
                  const SizedBox(height: 4),
                  const Text('per month',
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.textMid)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NEWLY ADDED LISTINGS  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _NewListings extends StatelessWidget {
  final bool                        loading;
  final List<QueryDocumentSnapshot> docs;
  final void Function(String)       onTap;
  final String Function(dynamic)    fmtPrice;

  const _NewListings({
    required this.loading,
    required this.docs,
    required this.onTap,
    required this.fmtPrice,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(
              color: AppColors.primaryOrange, strokeWidth: 2.5),
        ),
      );
    }

    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color:        AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width:  44,
              height: 44,
              decoration: BoxDecoration(
                color:        AppColors.orangeLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.home_outlined,
                color: AppColors.primaryOrange,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No new listings yet',
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'New stays will appear here once hosts publish them.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color:    AppColors.textMid,
                      height:   1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: ListView.separated(
        scrollDirection:  Axis.horizontal,
        physics:          const BouncingScrollPhysics(),
        itemCount:        docs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => _NewListingCard(
            doc: docs[i], onTap: onTap, fmtPrice: fmtPrice),
      ),
    );
  }
}

class _NewListingCard extends StatelessWidget {
  final QueryDocumentSnapshot    doc;
  final void Function(String)    onTap;
  final String Function(dynamic) fmtPrice;

  const _NewListingCard({
    required this.doc,
    required this.onTap,
    required this.fmtPrice,
  });

  @override
  Widget build(BuildContext context) {
    final d        = doc.data() as Map<String, dynamic>;
    final name     = (d['name'] ?? '') as String;
    final location = (d['location'] ?? '') as String;
    final category = (d['category'] ?? '') as String;
    final minPrice = d['minPrice'];
    final coverUrl = (d['coverImageUrl'] ?? '') as String;
    final rating   = d['rating'];
     final pricingMode = (d['minPricingMode'] ?? 'monthly').toString();

    return GestureDetector(
      onTap: () => onTap(doc.id),
      child: Container(
        width: 185,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color:        AppColors.card(context),
          boxShadow: [
            BoxShadow(
                color:      AppColors.textDark.withOpacity(.07),
                blurRadius: 18,
                offset:     const Offset(0, 6)),
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
                  _buildCover(coverUrl),
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color:        AppColors.primaryOrange,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('NEW',
                          style: TextStyle(
                              color:          AppColors.cardWhite,
                              fontSize:       10,
                              fontWeight:     FontWeight.w800,
                              letterSpacing:  0.5)),
                    ),
                  ),
                  if (rating != null)
                    Positioned(
                      top: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color:        AppColors.card(context),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color:      AppColors.textDark.withOpacity(.12),
                                blurRadius: 6),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                size: 11, color: AppColors.primaryOrange),
                            const SizedBox(width: 2),
                            Text(
                              (rating is double)
                                  ? rating.toStringAsFixed(1)
                                  : rating.toString(),
                              style: TextStyle(
                                  fontSize:   10.5,
                                  fontWeight: FontWeight.w700,
                                  color:      AppColors.text(context)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color:        AppColors.orangeLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primaryOrange.withOpacity(.3)),
                      ),
                      child: Text(category,
                          style: const TextStyle(
                              fontSize:   9.5,
                              fontWeight: FontWeight.w700,
                              color:      AppColors.primaryOrange)),
                    ),
                    const SizedBox(height: 5),
                  ],
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   13.5,
                          color:      AppColors.text(context))),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 11, color: AppColors.textLight),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textLight)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RichText(
  text: TextSpan(
    children: [
      const TextSpan(
        text: 'From ',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textMid,
        ),
      ),
      TextSpan(
        text: '₱${fmtPrice(minPrice)}',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryOrange,
        ),
      ),
      TextSpan(
        text: pricingMode == 'daily' ? ' /day' : ' /mo',
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textMid,
        ),
      ),
    ],
  ),
),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(String url) {
    const double h = 130;
    if (url.isEmpty) {
      return Container(
          height: h,
          width:  double.infinity,
          color:  AppColors.border,
          child:  Icon(Icons.image_rounded,
              color: AppColors.textLight, size: 32));
    }
    return Image.network(url,
        height: h,
        width:  double.infinity,
        fit:    BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
            height: h,
            width:  double.infinity,
            color:  AppColors.border,
            child:  Icon(Icons.image_not_supported_rounded,
                color: AppColors.textLight, size: 28)));
  }
}