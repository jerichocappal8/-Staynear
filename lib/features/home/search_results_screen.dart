// lib/features/home/search_results_screen.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/app_colors.dart';
import '../../widgets/explore_search_bar.dart';          // ← shared widget
import 'apartment_detail_page.dart';
import 'search_filter_screen.dart';
// ─────────────────────────────────────────────────────────────────────────────
//  SearchResultsScreen
//
//  Stack layout:
//    ① Full-screen GoogleMap                 (never rebuilt after init)
//    ② DraggableScrollableSheet             (results panel)
//    ③ Floating top search bar              (SafeArea overlay)
// ─────────────────────────────────────────────────────────────────────────────

class SearchResultsScreen extends StatefulWidget {
  final Map<String, dynamic> filters;
  const SearchResultsScreen({super.key, required this.filters});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen>
    with TickerProviderStateMixin {
  // ── Firestore data ────────────────────────────────────────────────────────
  List<QueryDocumentSnapshot> _results = [];
  bool _loading = true;
  String? _error;

  // ── Google Map ────────────────────────────────────────────────────────────
  GoogleMapController? _mapCtrl;
  Set<Marker> _markers = {};
  String? _selectedId;

  // ── Marker icon cache  (key = "$label|$selected") ─────────────────────────
  final Map<String, BitmapDescriptor> _markerCache = {};

  // ── Active filters (mutable copy of widget.filters) ───────────────────────
  Map<String, dynamic> _filters = {};

  // ── Sheet / list ──────────────────────────────────────────────────────────
  static const double _sheetInitSize = 0.40;
  static const double _sheetMinSize  = 0.18;
  static const double _sheetMaxSize  = 0.90;
  static const int    _pageSize      = 10;
  int _displayCount = _pageSize;

  // ── Sheet controller for programmatic expansion ───────────────────────────
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

  // ── Scroll controller for list ────────────────────────────────────────────
  final ScrollController _listCtrl = ScrollController();

  // ── Search bar controller (shared with ExploreSearchBar) ──────────────────
  final TextEditingController _searchCtrl = TextEditingController();

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _resultsAnimCtrl;
  late Animation<double>   _resultsFadeAnim;

  // ── Heart icon states ─────────────────────────────────────────────────────
  final Set<String> _likedIds = {};

  // ── Fallback map centre (Urdaneta City, Pangasinan) ───────────────────────
  static const LatLng _kCenter = LatLng(15.9754, 120.5710);

  // ── Known city coordinates for initial camera when no results yet ─────────
  static const Map<String, LatLng> _cityCenters = {
    'urdaneta city': LatLng(15.9754, 120.5710),
    'dagupan city':  LatLng(16.0433, 120.3333),
    'binalonan':     LatLng(15.9991, 120.5877),
    'mangaldan':     LatLng(16.0662, 120.4045),
    'san carlos city': LatLng(15.9268, 120.3535),
    'lingayen':      LatLng(16.0168, 120.2352),
    'calasiao':      LatLng(16.0191, 120.4221),
    'malasiqui':     LatLng(15.9197, 120.4152),
    'alaminos city': LatLng(16.1554, 119.9804),
    'san fabian':    LatLng(16.1177, 120.3946),
  };

  // ── Active sort ───────────────────────────────────────────────────────────
  String _sortMode = 'default'; // 'default' | 'price_asc' | 'price_desc' | 'rating'

  // ──────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Copy filters so we can mutate them when the user searches again
    _filters = Map<String, dynamic>.from(widget.filters);

    // Pre-fill search bar with the incoming city filter
    if (_filters['city'] != null) {
      _searchCtrl.text = _filters['city'].toString();
    }

    _resultsAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _resultsFadeAnim = CurvedAnimation(
      parent: _resultsAnimCtrl,
      curve:  Curves.easeOut,
    );

    _loadResults();
  }

@override
void dispose() {
  _mapCtrl = null;
  _markers.clear();

  _listCtrl.dispose();
  _sheetCtrl.dispose();
  _searchCtrl.dispose();
  _resultsAnimCtrl.dispose();

  super.dispose();
}

  // ══════════════════════════════════════════════════════════════════════════
  //  FIRESTORE  — uses 'city' field and 'priceMonthly' from rooms subcollection
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadResults() async {
    setState(() {
      _loading = true;
      _error   = null;
      _results = [];
    });

    try {
      // ── Normalize city string ─────────────────────────────────────────
// Use cities exactly as selected
List<String> cities = [];

if (_filters['city'] != null) {
  cities.add(_filters['city'].toString().trim());
}

if (_filters['cities'] != null) {
  cities.addAll((_filters['cities'] as List).cast<String>());
}

      // ── Fetch all active properties ───────────────────────────────────
      final snap = await FirebaseFirestore.instance
          .collection('properties')
          .where('isActive', isEqualTo: true)
          .get();

      List<QueryDocumentSnapshot> docs = snap.docs;

      // ── Server-side category filter ───────────────────────────────────
      final cat = _filters['category'];
      if (cat != null && cat.toString().isNotEmpty) {
        docs = docs
            .where((d) =>
                (d.data() as Map)['category']?.toString() == cat.toString())
            .toList();
      }

// ── Client-side city OR apartment name filter ─────────────────────
final nameFilter = _filters['name']?.toString();

if ((cities.isNotEmpty) || 
    (nameFilter != null && nameFilter.trim().isNotEmpty)) {

  final nameSearch = nameFilter?.toLowerCase();

  docs = docs.where((doc) {

    final data = doc.data() as Map<String, dynamic>;

    final cityField    = (data['city'] ?? '').toString().toLowerCase();
    final addressField = (data['address'] ?? '').toString().toLowerCase();
    final nameField    = (data['name'] ?? '').toString().toLowerCase();

    bool cityMatch = false;
    bool nameMatch = false;

if (cities.isNotEmpty) {
  cityMatch = cities.any((c) {
    final search = c.toLowerCase();
    return cityField.contains(search) || addressField.contains(search);
  });
}

    if (nameSearch != null) {
      nameMatch = nameField.contains(nameSearch);
    }

    return cityMatch || nameMatch;
  }).toList();
}

      // ── Fetch min priceMonthly from rooms subcollection ───────────────
final List<Map<String, dynamic>> enriched = [];

for (final doc in docs) {
  final data = doc.data() as Map<String, dynamic>;

  final minPrice = ((data['minPrice'] as num?) ?? 0).toDouble();
  final priceMode = (data['minPricingMode'] ?? 'monthly').toString();

  enriched.add({
    'doc': doc,
    'minPrice': minPrice,
    'priceMode': priceMode,
  });
}

      // ── Client-side price filters ─────────────────────────────────────
      final minP = (_filters['minPrice'] ?? 0) as num;
      final maxP = (_filters['maxPrice'] ?? 1000000) as num;

      List<Map<String, dynamic>> filtered = enriched.where((e) {
        final price = e['minPrice'] as double;
        return price >= minP && price <= maxP;
      }).toList();

      // ── Client-side rating filter ─────────────────────────────────────
      final minRating = _filters['rating'];
      if (minRating != null && (minRating as num) > 0) {
        filtered = filtered.where((e) {
          final d = e['doc'] as QueryDocumentSnapshot;
          final r = (d.data() as Map)['rating'];
          return r != null && (r as num) >= minRating;
        }).toList();
      }

      // ── Client-side amenities filter ──────────────────────────────────
      final amenities = _filters['amenities'];
      if (amenities != null && (amenities as List).isNotEmpty) {
        filtered = filtered.where((e) {
          final d    = e['doc'] as QueryDocumentSnapshot;
          final prop = List<String>.from((d.data() as Map)['amenities'] ?? []);
          return amenities.every((a) => prop.contains(a));
        }).toList();
      }

      // ── Build result list and price cache ─────────────────────────────
      final resultDocs =
          filtered.map((e) => e['doc'] as QueryDocumentSnapshot).toList();

      _enrichedPrices = {
  for (final e in filtered)
    (e['doc'] as QueryDocumentSnapshot).id: {
      'price': e['minPrice'],
      'mode': e['priceMode'],
    }
};

      if (!mounted) return;
      setState(() {
        _results      = resultDocs;
        _loading      = false;
        _displayCount = _pageSize;
      });
      _applySortToResults();

      _resultsAnimCtrl.forward(from: 0);
      if (!mounted) return;
      await _rebuildMarkers();
      if (!mounted) return;
      _moveCameraToFirst();
    } catch (e) {
      debugPrint('SearchResultsScreen error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = null;
        _results = [];
      });
    }
  }

  // ── Enriched price cache (docId → minPriceMonthly) ─────────────────────
  Map<String, Map<String, dynamic>> _enrichedPrices = {};
  double _priceFor(String docId) =>
    (_enrichedPrices[docId]?['price'] ?? 0).toDouble();

String _priceMode(String docId) =>
    _enrichedPrices[docId]?['mode'] ?? 'monthly';

  // ══════════════════════════════════════════════════════════════════════════
  //  MARKER MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _rebuildMarkers() async {
    final fresh = <Marker>{};

    for (final doc in _results) {
      final data = doc.data() as Map<String, dynamic>;
      final geo  = data['coordinates'] as GeoPoint?;
      if (geo == null) continue;

      final price      = _priceFor(doc.id);
      final mode = _priceMode(doc.id) == 'daily' ? '/d' : '/month';
final label = '₱${_comma(price)}$mode';
      final isSelected = doc.id == _selectedId;

      fresh.add(Marker(
        markerId: MarkerId(doc.id),
        position: LatLng(geo.latitude, geo.longitude),
        icon:     await _resolveIcon(label, isSelected: isSelected),
        zIndex:   isSelected ? 2.0 : 1.0,
        anchor:   const Offset(0.5, 0.5),
        onTap:    () => _selectById(doc.id, fromMarker: true),
      ));
    }

    if (mounted) setState(() => _markers = fresh);
  }

  Future<BitmapDescriptor> _resolveIcon(
    String label, {
    required bool isSelected,
  }) async {
    final key = '$label|$isSelected';
    if (_markerCache.containsKey(key)) return _markerCache[key]!;
    final icon = await _paintBubble(label, isSelected: isSelected);
    _markerCache[key] = icon;
    return icon;
  }

  Future<BitmapDescriptor> _paintBubble(
    String label, {
    bool isSelected = false,
  }) async {
    final double h      = isSelected ? 110.0 : 95.0;
    final double hPad   = isSelected ? 44.0  : 36.0;
    final double fSize  = isSelected ? 34.0  : 30.0;
    final double radius = h / 2;

    final bgColor = isSelected ? AppColors.primaryOrange : AppColors.cardWhite;
    final txColor = isSelected ? AppColors.cardWhite     : AppColors.textDark;

    final tp = TextPainter(
      text: TextSpan(
        text:  label,
        style: TextStyle(
            fontSize:   fSize,
            fontWeight: FontWeight.w800,
            color:      txColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final w  = tp.width + hPad * 2;
    final cw = w + 40.0;
    final ch = h + 40.0;

    final rec    = ui.PictureRecorder();
    final canvas = Canvas(rec);

    // Drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(6, 8, w, h), Radius.circular(radius)),
      Paint()
        ..color      = AppColors.textDark.withOpacity(isSelected ? 0.26 : 0.16)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, isSelected ? 9 : 6),
    );

    // Background fill
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, w, h), Radius.circular(radius)),
      Paint()..color = bgColor,
    );

    // Stroke (inactive only)
    if (!isSelected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(1, 1, w - 2, h - 2), Radius.circular(radius - 1)),
        Paint()
          ..color       = AppColors.textDark.withOpacity(0.12)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Price text
    tp.paint(canvas, Offset((w - tp.width) / 2, (h - tp.height) / 2));

    final picture = rec.endRecording();
    final image   = await picture.toImage(cw.ceil(), ch.ceil());
    final bytes   = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
  }

  void _evictFromCache(String? docId) {
    if (docId == null) return;
    final label = '₱${_comma(_priceFor(docId))}';
    _markerCache
      ..remove('$label|true')
      ..remove('$label|false');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INTERACTION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _selectById(String docId, {bool fromMarker = false}) async {
    if (_selectedId == docId) return;
    _evictFromCache(_selectedId);
    _evictFromCache(docId);
    setState(() => _selectedId = docId);
    await _rebuildMarkers();

    if (fromMarker) {
      _scrollToCard(docId);
      if (_sheetCtrl.isAttached) {
        _sheetCtrl.animateTo(0.65,
            duration: const Duration(milliseconds: 380),
            curve:    Curves.easeOutCubic);
      }
      _zoomToMarker(docId);
    } else {
  _panMapTo(docId);

  // collapse the sheet so map becomes focus
  if (_sheetCtrl.isAttached) {
    _sheetCtrl.animateTo(
      _sheetMinSize,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }
}
  }

  Future<void> _clearSelection() async {
    if (_selectedId == null) return;
    _evictFromCache(_selectedId);
    setState(() => _selectedId = null);
    await _rebuildMarkers();
  }

  void _scrollToCard(String docId) {
    final idx = _results.indexWhere((d) => d.id == docId);
    if (idx < 0 || !_listCtrl.hasClients) return;
    const double cardHeight = 148.0;
    const double headerH    = 62.0;
    final double target     = headerH + idx * cardHeight;
    _listCtrl.animateTo(
      target.clamp(0.0, _listCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 380),
      curve:    Curves.easeOutCubic,
    );
  }

void _panMapTo(String docId) {
  if (!mounted) return;

  final ctrl = _mapCtrl;
  if (ctrl == null) return;

  final doc = _results.where((d) => d.id == docId).firstOrNull;
  if (doc == null) return;

  final geo = (doc.data() as Map)['coordinates'] as GeoPoint?;
  if (geo == null) return;

  try {
    ctrl.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(geo.latitude, geo.longitude),
      ),
    );
  } catch (_) {}
}

void _zoomToMarker(String docId) {
  if (!mounted) return;

  final ctrl = _mapCtrl;
  if (ctrl == null) return;

  final doc = _results.where((d) => d.id == docId).firstOrNull;
  if (doc == null) return;

  final geo = (doc.data() as Map)['coordinates'] as GeoPoint?;
  if (geo == null) return;

  try {
    ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(geo.latitude, geo.longitude),
          zoom: 15.5,
        ),
      ),
    );
  } catch (_) {}
}

void _moveCameraToFirst() {
  if (!mounted) return;

  final ctrl = _mapCtrl;
  if (ctrl == null) return;

  // Try to find the first result with coordinates
  for (final doc in _results) {
    final geo = (doc.data() as Map)['coordinates'] as GeoPoint?;
    if (geo != null) {
      try {
        ctrl.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(geo.latitude, geo.longitude),
              zoom: 14,
            ),
          ),
        );
      } catch (_) {}
      return;
    }
  }

  // Fall back to known city center for the active city filter
  final cityFilter = _filters['city']?.toString().toLowerCase().trim();
  if (cityFilter != null && cityFilter.isNotEmpty) {
    for (final entry in _cityCenters.entries) {
      if (entry.key.contains(cityFilter) || cityFilter.contains(entry.key)) {
        try {
          ctrl.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: entry.value, zoom: 13),
            ),
          );
        } catch (_) {}
        return;
      }
    }
  }
}

  void _recenterMap()    => _moveCameraToFirst();
  void _toggleListView() => Navigator.pop(context);

  void _applySortToResults() {
    if (_sortMode == 'default') return;
    setState(() {
      switch (_sortMode) {
        case 'price_asc':
          _results.sort((a, b) => _priceFor(a.id).compareTo(_priceFor(b.id)));
          break;
        case 'price_desc':
          _results.sort((a, b) => _priceFor(b.id).compareTo(_priceFor(a.id)));
          break;
        case 'rating':
          _results.sort((a, b) {
            final rA = ((a.data() as Map)['rating'] ?? 0) as num;
            final rB = ((b.data() as Map)['rating'] ?? 0) as num;
            return rB.compareTo(rA);
          });
          break;
      }
    });
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Sort by',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text(context))),
              const SizedBox(height: 14),
              ...[
                ('default',   'Default',              Icons.sort_rounded),
                ('price_asc', 'Price: Low to High',   Icons.arrow_upward_rounded),
                ('price_desc','Price: High to Low',   Icons.arrow_downward_rounded),
                ('rating',    'Highest Rated',         Icons.star_rounded),
              ].map((item) {
                final mode  = item.$1;
                final label = item.$2;
                final icon  = item.$3;
                final sel   = _sortMode == mode;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primaryOrange : AppColors.orangeLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18,
                        color: sel ? Colors.white : AppColors.primaryOrange),
                  ),
                  title: Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? AppColors.primaryOrange : AppColors.text(context))),
                  trailing: sel
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primaryOrange, size: 18)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _sortMode = mode;
                      _displayCount = _pageSize;
                    });
                    _applySortToResults();
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _filters.remove('city');
      _filters.remove('cities');
      _searchCtrl.clear();
    });
    _loadResults();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  String _comma(double v) => v
      .toInt()
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  LatLng get _initialTarget {
    for (final doc in _results) {
      final geo = (doc.data() as Map)['coordinates'] as GeoPoint?;
      if (geo != null) return LatLng(geo.latitude, geo.longitude);
    }
    // Use known city coordinates when a city filter is active
    final cityFilter = _filters['city']?.toString().toLowerCase().trim();
    if (cityFilter != null && cityFilter.isNotEmpty) {
      for (final entry in _cityCenters.entries) {
        if (entry.key.contains(cityFilter) || cityFilter.contains(entry.key)) {
          return entry.value;
        }
      }
    }
    return _kCenter;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: _buildSkeletonState(),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline_rounded,
                  size: 56, color: AppColors.textMid),
              const SizedBox(height: 16),
              Text('Something went wrong',
                  style: TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.w600,
                      color:      AppColors.text(context))),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadResults,
                child: Text('Retry',
                    style: TextStyle(color: AppColors.primaryOrange)),
              ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.textDark,
      body: Stack(
        children: [
          // ① Map  (full-screen, never rebuilt)
          _buildMap(),

          // ② Draggable results sheet
          DraggableScrollableSheet(
            controller:       _sheetCtrl,
            initialChildSize: _sheetInitSize,
            minChildSize:     _sheetMinSize,
            maxChildSize:     _sheetMaxSize,
            snap:             true,
            snapSizes:        const [0.40, 0.65, 0.90],
            builder: (_, sheetScrollCtrl) => _buildSheet(sheetScrollCtrl),
          ),

          // ③ Floating top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildTopBar(),
          ),

          // ④ Floating map action buttons
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  ① MAP
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildMap() {
    return SizedBox.expand(
      child: GoogleMap(
        initialCameraPosition:
            CameraPosition(target: _initialTarget, zoom: 14),
        markers:                 _markers,
        zoomControlsEnabled:     false,
        myLocationButtonEnabled: false,
        myLocationEnabled:       true,
        onMapCreated: (ctrl) {
  if (!mounted) return;
  _mapCtrl = ctrl;

  Future.microtask(() {
    if (!mounted) return;
    _moveCameraToFirst();
  });
},
        onTap: (_) => _clearSelection(),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  MAP FLOATING BUTTONS
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildMapFABs() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _mapFAB(icon:    Icons.my_location_rounded,
                onTap:   _recenterMap,
                tooltip: 'Recenter'),
        const SizedBox(height: 10),
        _mapFAB(icon:    Icons.view_list_rounded,
                onTap:   _toggleListView,
                tooltip: 'List view'),
      ],
    );
  }

  Widget _mapFAB({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color:  AppColors.card(context),
            shape:  BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:      AppColors.textDark.withOpacity(0.18),
                blurRadius: 12,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: AppColors.primaryOrange),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  ② DRAGGABLE SHEET
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSheet(ScrollController sheetCtrl) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.background(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color:      AppColors.textDark.withOpacity(0.18),
            blurRadius: 32,
            offset:     const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _buildResultsHeader(),
          Expanded(
            child: _results.isEmpty
                ? _buildEmptyState()
                : _buildResultsList(sheetCtrl),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  ③ TOP BAR  — BackButton + ExploreSearchBar (shared widget)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(
          children: [
            // ── Back button ───────────────────────────────────────────────
            _topBarButton(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppColors.textDark),
            ),

            const SizedBox(width: 10),
// ── Shared ExploreSearchBar ───────────────────────────────────
Expanded(
  child: ExploreSearchBar(
    controller: _searchCtrl,
    includeApartments: true,

    // ── CITY SELECTED ─────────────────────────────────────────
onCitySelected: (city) {
  String normalized = city.toLowerCase();

  if (normalized.contains('urdaneta')) {
    normalized = 'Urdaneta City';
  } else if (normalized.contains('dagupan')) {
    normalized = 'Dagupan City';
  } else if (normalized.contains('binalonan')) {
    normalized = 'Binalonan';
  } else if (normalized.contains('mangaldan')) {
    normalized = 'Mangaldan';
  } else if (normalized.contains('san carlos')) {
    normalized = 'San Carlos City';
  }

  setState(() {
    // ⭐ IMPORTANT: reset filters
    _filters = {
      'city': normalized,
    };

    _searchCtrl.text = normalized;
  });

  _loadResults();
},

    // ⭐ APARTMENT SELECTED (NEW)
onApartmentSelected: (apartmentName) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('properties')
        .where('name', isEqualTo: apartmentName)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return;

    final docId = snap.docs.first.id;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApartmentDetailPage(
          apartmentId: docId,
        ),
      ),
    );
  } catch (e) {
    debugPrint('Home apartment search error: $e');
  }
},

    // ── FILTER BUTTON ─────────────────────────────────────────
    onFilterTap: () async {
      final filters = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SearchFilterScreen(),
        ),
      );

      if (filters != null && mounted) {
        setState(() {
          _filters = Map<String, dynamic>.from(filters);

          if (_filters['city'] != null) {
            _searchCtrl.text = _filters['city'];
          }
        });

        _loadResults();
      }
    },
  ),
),
          ],
        ),
      ),
    );
  }
  Widget _topBarButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color:        AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color:      AppColors.textDark.withOpacity(0.14),
              blurRadius: 12,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  RESULTS HEADER
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          FadeTransition(
            opacity: _resultsFadeAnim,
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: '${_results.length}',
                  style: TextStyle(
                      fontSize:      18,
                      fontWeight:    FontWeight.w800,
                      color:         AppColors.primaryOrange,
                      letterSpacing: -0.3),
                ),
                TextSpan(
                  text: ' homes found',
                  style: TextStyle(
                      fontSize:      15,
                      fontWeight:    FontWeight.w600,
                      color:         AppColors.text(context),
                      letterSpacing: -0.2),
                ),
              ]),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showSortSheet,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _sortMode != 'default'
                    ? AppColors.primaryOrange
                    : AppColors.card(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _sortMode != 'default'
                      ? AppColors.primaryOrange
                      : AppColors.border,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.swap_vert_rounded,
                    size: 16,
                    color: _sortMode != 'default'
                        ? Colors.white
                        : AppColors.textMid),
                const SizedBox(width: 4),
                Text('Sort',
                    style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color: _sortMode != 'default'
                            ? Colors.white
                            : AppColors.textMid)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  EMPTY STATE
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 64, color: AppColors.border),
          const SizedBox(height: 16),
          Text('No homes found in this area',
              style: TextStyle(
                  fontSize:   17,
                  fontWeight: FontWeight.w700,
                  color:      AppColors.text(context)),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Try adjusting filters or searching another city',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textMid, height: 1.4),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _clearFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                color:        AppColors.orangeLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primaryOrange, width: 1.5),
              ),
              child: Text('Clear filters',
                  style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.primaryOrange)),
            ),
          ),
        ]),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  SKELETON LOADING STATE
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSkeletonState() {
    return Stack(
      children: [
        Container(color: AppColors.border),
        DraggableScrollableSheet(
          initialChildSize: _sheetInitSize,
          minChildSize:     _sheetMinSize,
          maxChildSize:     _sheetMaxSize,
          builder: (_, ctrl) => Container(
            decoration: BoxDecoration(
              color:        AppColors.background(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ListView.builder(
              controller: ctrl,
              padding:    const EdgeInsets.fromLTRB(20, 20, 20, 32),
              itemCount:  5,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child:   _buildSkeletonCard(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      height: 116,
      decoration: BoxDecoration(
        color:        AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 92, height: 92,
            decoration: BoxDecoration(
              color:        AppColors.border,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:  MainAxisAlignment.center,
              children: [
                _skeletonLine(width: 80,             height: 10),
                const SizedBox(height: 8),
                _skeletonLine(width: double.infinity, height: 14),
                const SizedBox(height: 6),
                _skeletonLine(width: 120,            height: 10),
                const SizedBox(height: 10),
                _skeletonLine(width: 80,             height: 14),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _skeletonLine({required double width, required double height}) {
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        color:        AppColors.border,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  RESULTS LIST
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildResultsList(ScrollController sheetCtrl) {
    final shown = _results.take(_displayCount).toList();
    return ListView.builder(
      controller: sheetCtrl,
      physics:    const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
      padding:    const EdgeInsets.fromLTRB(20, 10, 20, 36),
      itemCount:  shown.length + 1,
      itemBuilder: (ctx, i) {
        if (i == shown.length) return _buildShowMoreButton();
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child:   _buildPropertyCard(shown[i]),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  PROPERTY CARD
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildPropertyCard(QueryDocumentSnapshot doc) {
    final data       = doc.data() as Map<String, dynamic>;
    final name       = (data['name']          as String?) ?? 'Property';
    final city       = (data['city']          as String?) ?? '';
    final cover      = (data['coverImageUrl'] as String?) ?? '';
    final price      = _priceFor(doc.id);
    final rating     = ((data['rating']       as num?)    ?? 0.0);
    final reviews    = ((data['reviewCount']  as num?)    ?? 0);
    final category   = (data['category']      as String?) ?? '';
    final isSelected = doc.id == _selectedId;
    final isLiked    = _likedIds.contains(doc.id);

    return GestureDetector(
      onTap: () {
  if (_selectedId == doc.id) {
    // SECOND TAP → open detail page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApartmentDetailPage(apartmentId: doc.id),
      ),
    );
  } else {
    // FIRST TAP → select + move map
    _selectById(doc.id, fromMarker: false);
  }
},
      onLongPress: () => _selectById(doc.id, fromMarker: false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve:    Curves.easeOutCubic,
        decoration: BoxDecoration(
          color:        AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : AppColors.border,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color:      AppColors.textDark
                  .withOpacity(isSelected ? 0.14 : 0.06),
              blurRadius: isSelected ? 24 : 14,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cover image ─────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _buildCardImage(cover),
              ),

              const SizedBox(width: 12),

              // ── Detail column ────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category chip + Rating row
                    Row(children: [
                      if (category.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:        AppColors.orangeLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(category,
                              style: TextStyle(
                                  fontSize:   10,
                                  fontWeight: FontWeight.w700,
                                  color:      AppColors.primaryOrange)),
                        ),
                        const Spacer(),
                      ],
                      Icon(Icons.star_rounded,
                          size: 14, color: AppColors.primaryOrange),
                      const SizedBox(width: 3),
                      Text(
                        '${rating.toStringAsFixed(1)} ($reviews)',
                        style: TextStyle(
                            fontSize:   12,
                            fontWeight: FontWeight.w600,
                            color:      AppColors.text(context)),
                      ),
                    ]),

                    const SizedBox(height: 5),

                    // Property name
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize:      15,
                            fontWeight:    FontWeight.w700,
                            color:         AppColors.text(context),
                            letterSpacing: -0.2,
                            height:        1.2)),

                    const SizedBox(height: 3),

                    // City
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 12, color: AppColors.textLight),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color:    AppColors.textMid,
                                height:   1.3)),
                      ),
                    ]),

                    const SizedBox(height: 8),

                    // Price + heart
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        RichText(
                          text: TextSpan(children: [
                            TextSpan(
                              text:  '₱${_comma(price)}',
                              style: TextStyle(
                                  fontSize:      17,
                                  fontWeight:    FontWeight.w800,
                                  color:         AppColors.primaryOrange,
                                  letterSpacing: -0.4),
                            ),
                            TextSpan(
  text: _priceMode(doc.id) == 'daily' ? ' / daily' : ' / monthly',
  style: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textMid,
  ),
),
                          ]),
                        ),
                        const Spacer(),
                        // Animated heart button
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_likedIds.contains(doc.id)) {
                                _likedIds.remove(doc.id);
                              } else {
                                _likedIds.add(doc.id);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width:    32,
                            height:   32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isLiked
                                  ? AppColors.orangeLight
                                  : AppColors.background(context),
                            ),
                            child: Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size:  16,
                              color: isLiked
                                  ? AppColors.primaryOrange
                                  : AppColors.textMid,
                            ),
                          ),
                        ),
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

  Widget _buildCardImage(String url) {
    const double sz = 92;
    return url.isNotEmpty
        ? Image.network(url,
            width: sz, height: sz, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imageFallback(sz))
        : _imageFallback(sz);
  }

  Widget _imageFallback(double sz) => Container(
        width: sz, height: sz,
        color: AppColors.border,
        child: Icon(Icons.apartment_rounded,
            size: 32, color: AppColors.textMid),
      );

  // ──────────────────────────────────────────────────────────────────────────
  //  SHOW MORE BUTTON
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildShowMoreButton() {
    final hasMore = _results.length > _displayCount;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Center(
        child: GestureDetector(
          onTap: hasMore
              ? () => setState(() => _displayCount += _pageSize)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 40, vertical: 15),
            decoration: BoxDecoration(
              color:        AppColors.orangeLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: AppColors.primaryOrange, width: 1.5),
            ),
            child: Text(
              hasMore ? 'Show more results' : 'No more results',
              style: TextStyle(
                  fontSize:   14,
                  fontWeight: FontWeight.w700,
                  color:      AppColors.primaryOrange),
            ),
          ),
        ),
      ),
    );
  }
}