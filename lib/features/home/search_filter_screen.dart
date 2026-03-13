// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/features/home/search_filter_screen.dart
//
//  Production-ready Airbnb-style rental filter panel for StayNear.
//
//  Sections (in order):
//    1. Top bar  (back + title + reset)
//    2. Location  → LocationAutocompleteField
//    3. Pricing mode toggle  (Daily | Monthly)
//    4. Price range slider  (adapts to mode)
//    5. Property type chips
//    6. Guest capacity  (Any, 1+, 2+, 4+, 6+)
//    7. Gender restriction  (Any, Open, Male Only, Female Only)
//    8. Amenities  (collapsed 8 / expanded all, with Show more)
//    9. Rating slider
//   10. Availability toggle  (isAvailable + availableUnits)
//   11. Sticky bottom bar  (Reset all | Show N results)
//
//  Filter map returned via Navigator.pop:
//  {
//    'city':               String,
//    'minPrice':           double,
//    'maxPrice':           double,
//    'pricingMode':        'monthly' | 'daily',
//    'category':           String,   // '' = Any
//    'amenities':          List<String>,
//    'rating':             double,
//    'maxOccupants':       int,      // 0 = Any
//    'genderRestriction':  String,   // '' = Any
//    'availableOnly':      bool,
//  }
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../widgets/location_autocomplete_field.dart';

class SearchFilterScreen extends StatefulWidget {
  const SearchFilterScreen({super.key});

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen>
    with SingleTickerProviderStateMixin {

  // ── Location ──────────────────────────────────────────────────────────────
  List<String> _selectedCities = [];
  final _locationCtrl  = TextEditingController();

  // ── Pricing mode ──────────────────────────────────────────────────────────
  String _pricingMode = 'monthly'; // 'monthly' | 'daily'

  // Dynamic slider bounds per mode
  static const _monthlyMax = 50000.0;
  static const _dailyMax   = 5000.0;

  late RangeValues _priceRange;

  double get _priceMax =>
      _pricingMode == 'monthly' ? _monthlyMax : _dailyMax;

  // ── Property type ─────────────────────────────────────────────────────────
  String? _selectedCategory; // null = Any

  static const _categories = [
    'Boarding House',
    'Apartment',
    'Dorm',
    'Studio',
    'Condo',
    'Whole House',
  ];

  // ── Guest capacity ────────────────────────────────────────────────────────
  int _guests = 0; // 0 = Any

  static const _guestOptions = [
    _GuestOption(label: 'Any', value: 0),
    _GuestOption(label: '1+',  value: 1),
    _GuestOption(label: '2+',  value: 2),
    _GuestOption(label: '4+',  value: 4),
    _GuestOption(label: '6+',  value: 6),
  ];

  // ── Gender restriction ────────────────────────────────────────────────────
  String _gender = ''; // '' = Any

  static const _genderOptions = [
    _GenderOption(label: 'Any',         value: ''),
    _GenderOption(label: 'Open',        value: 'open'),
    _GenderOption(label: 'Male Only',   value: 'male'),
    _GenderOption(label: 'Female Only', value: 'female'),
  ];

  // ── Amenities ─────────────────────────────────────────────────────────────
  List<String> _selectedAmenities = [];
  bool         _amenitiesExpanded = false;

  static const _allAmenities = [
    'WiFi',
    'Parking',
    'Aircon',
    'Balcony',
    'CCTV',
    'Gym',
    'Pet Friendly',
    'Kitchen',
    'Security',
    'Self check-in',
    'Free parking',
  ];

  static const _collapsedAmenityCount = 8;

  List<String> get _visibleAmenities => _amenitiesExpanded
      ? _allAmenities
      : _allAmenities.take(_collapsedAmenityCount).toList();

  // ── Rating ────────────────────────────────────────────────────────────────
  double _rating = 0;

  // ── Availability ──────────────────────────────────────────────────────────
  bool _availableOnly = false;

  // ── Result count (stub — wire to Firestore count if needed) ──────────────
  int? _resultCount; // null = unknown

  // ════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _priceRange = RangeValues(0, _priceMax);
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  ACTIONS
  // ════════════════════════════════════════════════════════════════════════

  void _resetAll() {
    setState(() {
      _selectedCities.clear();
      _locationCtrl.clear();
      _pricingMode        = 'monthly';
      _priceRange         = RangeValues(0, _monthlyMax);
      _selectedCategory   = null;
      _guests             = 0;
      _gender             = '';
      _selectedAmenities  = [];
      _rating             = 0;
      _availableOnly      = false;
      _resultCount        = null;
    });
  }

  void _showResults() {
    Navigator.pop(context, {
      'cities': _selectedCities,
      'minPrice':          _priceRange.start,
      'maxPrice':          _priceRange.end,
      'pricingMode':       _pricingMode,
      'category':          _selectedCategory ?? '',
      'amenities':         _selectedAmenities,
      'rating':            _rating,
      'maxOccupants':      _guests,
      'genderRestriction': _gender,
      'availableOnly':     _availableOnly,
    });
  }

  void _onPricingModeChanged(String mode) {
    setState(() {
      _pricingMode = mode;
      // Reset slider to full range for the newly selected mode
      _priceRange  = RangeValues(0, _priceMax);
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════════════

  String _formatPrice(double value) {
    if (value >= 1000) {
      final k = value / 1000;
      return '₱${k % 1 == 0 ? k.toInt() : k.toStringAsFixed(1)}k';
    }
    return '₱${value.toInt()}';
  }

  String get _bottomButtonLabel {
    if (_resultCount != null) return 'Show $_resultCount results';
    return 'Show results';
  }

  bool get _hasActiveFilters =>
      _selectedCities.isNotEmpty      ||
      _priceRange.start > 0           ||
      _priceRange.end < _priceMax     ||
      _selectedCategory != null       ||
      _guests > 0                     ||
      _gender.isNotEmpty              ||
      _selectedAmenities.isNotEmpty   ||
      _rating > 0                     ||
      _availableOnly;

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLocationSection(),
                  _divider(),
                  _buildPricingModeSection(),
                  _divider(),
                  _buildPriceRangeSection(),
                  _divider(),
                  _buildPropertyTypeSection(),
                  _divider(),
                  _buildGuestCapacitySection(),
                  _divider(),
                  _buildGenderSection(),
                  _divider(),
                  _buildAmenitiesSection(),
                  _divider(),
                  _buildRatingSection(),
                  _divider(),
                  _buildAvailabilitySection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  TOP BAR
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildTopBar() {
    return Container(
      color: AppColors.card(context),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              // Back
              _iconBtn(
                icon:    Icons.arrow_back_ios_new_rounded,
                onTap:   () => Navigator.pop(context),
              ),
              const SizedBox(width: 14),

              // Title
              Expanded(
                child: Text(
                  'Filters',
                  style: TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.w800,
                    color:      AppColors.text(context),
                    letterSpacing: -0.4,
                  ),
                ),
              ),

              // Reset (only when filters are active)
              AnimatedOpacity(
                opacity:  _hasActiveFilters ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: GestureDetector(
                  onTap: _hasActiveFilters ? _resetAll : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color:        AppColors.cardSoft(context),
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'Reset all',
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      AppColors.primaryOrange,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  38,
        height: 38,
        decoration: BoxDecoration(
          color:        AppColors.cardSoft(context),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 16, color: AppColors.text(context)),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SHARED UI ATOMS
  // ════════════════════════════════════════════════════════════════════════

  Widget _sectionHeader(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize:      16,
            fontWeight:    FontWeight.w800,
            color:         AppColors.text(context),
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.textMid),
          ),
        ],
      ],
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Divider(
      height: 1, thickness: 1,
      color: AppColors.border.withOpacity(.6),
    ),
  );

  /// Animated chip used throughout the filter screen.
  Widget _filterChip({
    required String       label,
    required bool         selected,
    required VoidCallback onTap,
    IconData?             icon,
    bool                  compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve:    Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical:   compact ? 8  : 10,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryOrange : AppColors.card(context),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.primaryOrange : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(
                  color:      AppColors.primaryOrange.withOpacity(.22),
                  blurRadius: 10,
                  offset:     const Offset(0, 3),
                )]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size:  14,
                  color: selected ? Colors.white : AppColors.textMid),
              const SizedBox(width: 5),
            ] else if (selected) ...[
              const Icon(Icons.check_rounded,
                  size: 13, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize:   13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color:      selected ? Colors.white : AppColors.textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION 1 — LOCATION
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Location',
            subtitle: 'Search by city, municipality, or area'),
        const SizedBox(height: 14),
        LocationAutocompleteField(
          controller: _locationCtrl,
          hint:       'Search city or location',
          onSelected: (city) {
  if (!_selectedCities.contains(city)) {
    setState(() {
      _selectedCities.add(city);
      _locationCtrl.clear();
    });
  }
},
        ),
        if (_selectedCities.isNotEmpty) ...[
  const SizedBox(height: 10),
  Wrap(
    spacing: 8,
    runSpacing: 8,
    children: _selectedCities.map((city) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.orangeLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primaryOrange.withOpacity(.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded,
                color: AppColors.primaryOrange, size: 14),
            const SizedBox(width: 6),
            Text(
              city,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCities.remove(city);
                });
              },
              child: const Icon(Icons.close_rounded,
                  size: 14, color: AppColors.primaryOrange),
            ),
          ],
        ),
      );
    }).toList(),
  ),
],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION 2 — PRICING MODE
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildPricingModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Pricing mode',
            subtitle: 'Filter by daily or monthly rate'),
        const SizedBox(height: 14),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color:        AppColors.cardSoft(context),
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _pricingTab(
                label:  'Monthly',
                icon:   Icons.calendar_month_rounded,
                active: _pricingMode == 'monthly',
                onTap:  () => _onPricingModeChanged('monthly'),
              ),
              _pricingTab(
                label:  'Daily',
                icon:   Icons.today_rounded,
                active: _pricingMode == 'daily',
                onTap:  () => _onPricingModeChanged('daily'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pricingTab({
    required String       label,
    required IconData     icon,
    required bool         active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve:    Curves.easeOutCubic,
          margin:   const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color:        active ? AppColors.primaryOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [BoxShadow(
                    color:      AppColors.primaryOrange.withOpacity(.25),
                    blurRadius: 8,
                    offset:     const Offset(0, 2),
                  )]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size:  14,
                  color: active ? Colors.white : AppColors.textMid),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize:   13.5,
                  fontWeight: FontWeight.w700,
                  color:      active ? Colors.white : AppColors.textMid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION 3 — PRICE RANGE
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildPriceRangeSection() {
    final suffix = _pricingMode == 'monthly' ? '/mo' : '/day';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionHeader('Price range')),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                '${_formatPrice(_priceRange.start)} – '
                '${_formatPrice(_priceRange.end)}$suffix',
                key: ValueKey(
                    '${_priceRange.start}-${_priceRange.end}-$_pricingMode'),
                style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w700,
                  color:      AppColors.primaryOrange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight:    3,
            activeTrackColor:    AppColors.primaryOrange,
            inactiveTrackColor:  AppColors.border,
            thumbColor:          Colors.white,
            overlayColor:        AppColors.primaryOrange.withOpacity(.14),
            rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 12, elevation: 5),
            rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
            overlayShape:    const RoundSliderOverlayShape(overlayRadius: 22),
          ),
          child: RangeSlider(
            values:    _priceRange,
            min:       0,
            max:       _priceMax,
            divisions: 100,
            onChanged: (v) => setState(() => _priceRange = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₱0',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMid)),
              Text(_formatPrice(_priceMax),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMid)),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION 4 — PROPERTY TYPE
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildPropertyTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Property type'),
        const SizedBox(height: 14),
        Wrap(
          spacing:    8,
          runSpacing: 8,
          children: [
            // "Any" chip
            _filterChip(
              label:    'Any',
              selected: _selectedCategory == null,
              onTap:    () => setState(() => _selectedCategory = null),
            ),
            ..._categories.map((cat) => _filterChip(
              label:    cat,
              selected: _selectedCategory == cat,
              onTap:    () => setState(() => _selectedCategory = cat),
            )),
          ],
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION 5 — GUEST CAPACITY
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildGuestCapacitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Guests',
            subtitle: 'Minimum occupant capacity (maxOccupants)'),
        const SizedBox(height: 14),
        Row(
          children: _guestOptions.map((opt) {
            final selected = _guests == opt.value;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _filterChip(
                label:    opt.label,
                selected: selected,
                compact:  true,
                onTap:    () => setState(() => _guests = opt.value),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION 6 — GENDER RESTRICTION
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildGenderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Gender restriction',
            subtitle: 'Matches the genderRestriction field on rooms'),
        const SizedBox(height: 14),
        Wrap(
          spacing:    8,
          runSpacing: 8,
          children: _genderOptions.map((opt) => _filterChip(
            label:    opt.label,
            selected: _gender == opt.value,
            onTap:    () => setState(() => _gender = opt.value),
          )).toList(),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION 7 — AMENITIES
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildAmenitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionHeader('Amenities',
                  subtitle: 'Matches the amenities array on properties'),
            ),
            if (_selectedAmenities.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _selectedAmenities.clear()),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      AppColors.primaryOrange,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing:    8,
          runSpacing: 8,
          children: _visibleAmenities.map((a) {
            final selected = _selectedAmenities.contains(a);
            return _filterChip(
              label:    a,
              selected: selected,
              onTap: () {
                setState(() {
                  selected
                      ? _selectedAmenities.remove(a)
                      : _selectedAmenities.add(a);
                });
              },
            );
          }).toList(),
        ),

        // Show more / less toggle
        if (_allAmenities.length > _collapsedAmenityCount) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(
                () => _amenitiesExpanded = !_amenitiesExpanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _amenitiesExpanded ? 'Show less' : 'Show more',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      AppColors.primaryOrange,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns:    _amenitiesExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: AppColors.primaryOrange),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION 8 — RATING
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionHeader('Rating')),
            AnimatedOpacity(
              opacity:  _rating > 0 ? 1 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: Row(
                children: [
                  Icon(Icons.star_rounded,
                      size: 16, color: AppColors.primaryOrange),
                  const SizedBox(width: 4),
                  Text(
                    _rating == 0
                        ? 'Any'
                        : '${_rating.toStringAsFixed(1)}+',
                    style: TextStyle(
                      fontSize:   13.5,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.text(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Star visualiser
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            final filled = i.toDouble() < _rating;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                key:   ValueKey(filled),
                filled
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: filled ? AppColors.primaryOrange : AppColors.border,
                size:  30,
              ),
            );
          }),
        ),
        const SizedBox(height: 10),

        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight:      3,
            activeTrackColor: AppColors.primaryOrange,
            inactiveTrackColor: AppColors.border,
            thumbColor:       Colors.white,
            thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 12, elevation: 5),
            overlayColor:  AppColors.primaryOrange.withOpacity(.14),
            overlayShape:  const RoundSliderOverlayShape(overlayRadius: 22),
          ),
          child: Slider(
            value:     _rating,
            min:       0,
            max:       5,
            divisions: 10,
            onChanged: (v) => setState(() => _rating = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Any',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMid)),
              Text('5.0',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMid)),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION 9 — AVAILABILITY
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildAvailabilitySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.card(context),
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(
          color: _availableOnly
              ? AppColors.primaryOrange.withOpacity(.4)
              : AppColors.border,
          width: _availableOnly ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Icon badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _availableOnly
                  ? AppColors.orangeLight
                  : AppColors.cardSoft(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _availableOnly
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: _availableOnly
                  ? AppColors.primaryOrange
                  : AppColors.textLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available now',
                  style: TextStyle(
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                    color:      AppColors.text(context),
                  ),
                ),
                Text(
                  'Only show rooms where isAvailable = true',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMid),
                ),
              ],
            ),
          ),

          // Toggle
          Switch.adaptive(
            value:       _availableOnly,
            onChanged:   (v) => setState(() => _availableOnly = v),
            activeColor: AppColors.primaryOrange,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  STICKY BOTTOM BAR
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(.07),
            blurRadius: 20,
            offset:     const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [

              // ── Reset all ─────────────────────────────────────────────
              GestureDetector(
                onTap: _resetAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded,
                          size:  16,
                          color: _hasActiveFilters
                              ? AppColors.primaryOrange
                              : AppColors.textLight),
                      const SizedBox(width: 6),
                      Text(
                        'Reset all',
                        style: TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.w600,
                          color:      _hasActiveFilters
                              ? AppColors.text(context)
                              : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ── Show results button ───────────────────────────────────
              GestureDetector(
                onTap: _showResults,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 15),
                  decoration: BoxDecoration(
                    color:        AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:      AppColors.primaryOrange.withOpacity(.35),
                        blurRadius: 14,
                        offset:     const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _bottomButtonLabel,
                      key:   ValueKey(_bottomButtonLabel),
                      style: const TextStyle(
                        fontSize:   15,
                        fontWeight: FontWeight.w700,
                        color:      Colors.white,
                      ),
                    ),
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
//  DATA MODELS  (file-private)
// ─────────────────────────────────────────────────────────────────────────────

class _GuestOption {
  final String label;
  final int    value;
  const _GuestOption({required this.label, required this.value});
}

class _GenderOption {
  final String label;
  final String value;
  const _GenderOption({required this.label, required this.value});
}