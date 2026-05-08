// ════════════════════════════════════════════════════════════════════════════
//  FILE: add_apartment_screen.dart
//
//  Architecture: Scalable Rental System — Property + Rooms (Subcollection)
//
//  ┌─────────────────────────────────────────────────────────────────────┐
//  │  CHANGE LOG                                                         │
//  │                                                                     │
//  │  • securityDeposit moved from RentalTerms → per-room document       │
//  │  • RentalTerms now only holds: minimumStayMonths,                   │
//  │    advanceMonthsRequired                                            │
//  │  • Each room card now includes a Security Deposit (₱) input field  │
//  │    placed below Service Fee                                         │
//  │  • Room summary chip now shows deposit amount                       │
//  │  • Firestore write includes securityDeposit per room doc            │
//  └─────────────────────────────────────────────────────────────────────┘
//
//  Firestore Structure:
//
//  properties/{propertyId}
//  ├── name, address, description, category
//  ├── rentalTerms { minimumStayMonths, advanceMonthsRequired }
//  │     ↑ securityDeposit REMOVED — now per-room
//  ├── houseRules[], amenities[]
//  ├── coverImageUrl, imageUrls[]
//  ├── isActive, rating, reviewCount
//  ├── ownerId, createdAt, coordinates
//  └── minPrice
//
//  properties/{propertyId}/rooms/{roomId}
//  ├── roomType
//  ├── pricingMode         'monthly' | 'daily'
//  ├── priceMonthly
//  ├── priceDaily
//  ├── serviceFee
//  ├── securityDeposit     ← NEW: per-room deposit
//  ├── availableUnits
//  ├── maxOccupants
//  ├── genderRestriction
//  └── isAvailable
// ════════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/room_offer.dart';
import 'package:staynear/core/app_colors.dart';
import 'package:staynear/core/app_cities.dart';
// ════════════════════════════════════════════════════════════════════════════
//  RENTAL TERMS MODEL
//  Property-wide policy — securityDeposit intentionally removed.
//  Deposit is now a per-room field so different room types can require
//  different deposit amounts.
// ════════════════════════════════════════════════════════════════════════════

class RentalTerms {
  int minimumStayMonths;
  int advanceMonthsRequired;

  RentalTerms({
    this.minimumStayMonths    = 1,
    this.advanceMonthsRequired = 1,
  });

  Map<String, dynamic> toFirestoreMap() => {
    'minimumStayMonths':     minimumStayMonths,
    'advanceMonthsRequired': advanceMonthsRequired,
  };
}

// ════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════════════════════════

class AddApartmentScreen extends StatefulWidget {
  const AddApartmentScreen({super.key});

  @override
  State<AddApartmentScreen> createState() => _AddApartmentScreenState();
}

class _AddApartmentScreenState extends State<AddApartmentScreen>
    with TickerProviderStateMixin {

  // ── Property-level controllers ────────────────────────────────────────────
  final titleCtrl    = TextEditingController();
  final locationCtrl = TextEditingController();
  final descCtrl     = TextEditingController();

  // ── Property Category ─────────────────────────────────────────────────────
static const _categories = [
  'Boarding House',
  'Apartment',
  'Dorm',
  'Studio',
  'Condo',
  'Whole House',
  'Hotel',
];
String? _selectedCity;
  String? _selectedCategory;

  // ── Rental Terms (deposit removed — now per-room) ─────────────────────────
  final RentalTerms _rentalTerms  = RentalTerms();
  final _minStayCtrl              = TextEditingController(text: '1');
  final _advanceMonthsCtrl        = TextEditingController(text: '1');

  // ── House Rules ───────────────────────────────────────────────────────────
  static const _allHouseRules = [
    'No smoking',
    'No pets',
    'Visitors allowed',
    'Visitors not allowed',
    'Curfew required',
    'No curfew',
    'Cooking allowed',
    'Cooking not allowed',
    'Laundry allowed',
    'Laundry not allowed',
    'No loud noise',
    'No parties',
    'No alcohol',
    'No illegal activities',
    'Keep the room clean',
    'Pay on time',
    'No extra overnight guests',
    'Female only',
    'Male only',
    'Open for all',
  ];
  static const _ruleGroups = <String, List<String>>{
    'Smoking & Pets':    ['No smoking', 'No pets'],
    'Visitors & Curfew': ['Visitors allowed', 'Visitors not allowed', 'Curfew required', 'No curfew', 'No extra overnight guests'],
    'Cooking & Laundry': ['Cooking allowed', 'Cooking not allowed', 'Laundry allowed', 'Laundry not allowed'],
    'Behavior':          ['No loud noise', 'No parties', 'No alcohol', 'No illegal activities', 'Keep the room clean', 'Pay on time'],
    'Occupancy':         ['Female only', 'Male only', 'Open for all'],
  };
  final Set<String> _selectedRules = {};

  // ── Property Availability ─────────────────────────────────────────────────
  bool _isActive = true;

  // ── Amenities ─────────────────────────────────────────────────────────────
  static const _amenities = [
    'WiFi',
    'Parking',
    'Aircon',
    'Balcony',
    'CCTV',
    'Gym',
    'Pet Friendly',
    'Private bathroom',
    'Shared bathroom',
    'Kitchen access',
    'Laundry area',
    'Study table',
    'Cabinet / closet',
    'Bed included',
    'Water included',
    'Electricity included',
    'Security guard',
    'Near transportation',
    'Near school',
    'Near mall',
    'Near hospital',
  ];
  static const _amenityGroups = <String, List<String>>{
    'Basic':                   ['WiFi', 'Parking', 'Aircon', 'Balcony', 'CCTV'],
    'Room Features':           ['Private bathroom', 'Shared bathroom', 'Study table', 'Cabinet / closet', 'Bed included'],
    'Shared Facilities':       ['Kitchen access', 'Laundry area', 'Gym'],
    'Included Bills & Nearby': ['Water included', 'Electricity included', 'Security guard', 'Near transportation', 'Near school', 'Near mall', 'Near hospital'],
    'Policy':                  ['Pet Friendly'],
  };
  final Set<String> _selectedAmenities = {};

  // ── Photos ────────────────────────────────────────────────────────────────
  List<File> _images      = [];
  int _coverImageIndex    = 0;

  // ── Room Offers (subcollection rows) ──────────────────────────────────────
  final List<RoomOffer> _roomOffers = [RoomOffer()];

  // Parallel controller lists — same index as _roomOffers
  final List<TextEditingController> _priceCtrlList          = [TextEditingController()];
  final List<TextEditingController> _unitsCtrlList          = [TextEditingController()];
  final List<TextEditingController> _occupantsCtrlList      = [TextEditingController()];
  final List<TextEditingController> _serviceFeeCtrlList     = [TextEditingController()];
  final List<TextEditingController> _securityDepCtrlList    = [TextEditingController()]; // ← NEW

  // ── Room type options ─────────────────────────────────────────────────────
  static const _roomTypes = [
    'Studio', '1 Bedroom', '2 Bedroom', 'Bed Space', 'Entire Unit',
  ];

  // ── Gender options ────────────────────────────────────────────────────────
  static const _genderOptions = ['open', 'female', 'male'];
  static const _genderLabels  = {
    'open':   'Open',
    'female': 'Female Only',
    'male':   'Male Only',
  };

  // ── Map ───────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  LatLng?              _selectedLatLng;
  static const _initialPosition = CameraPosition(
    target: LatLng(15.9750, 120.5710),
    zoom:   14,
  );

  // ── State ─────────────────────────────────────────────────────────────────
  bool   _loading = false;
  final  _picker  = ImagePicker();

  // ════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    titleCtrl.dispose();
    locationCtrl.dispose();
    descCtrl.dispose();
    _minStayCtrl.dispose();
    _advanceMonthsCtrl.dispose();
    for (final c in _priceCtrlList)       c.dispose();
    for (final c in _unitsCtrlList)       c.dispose();
    for (final c in _occupantsCtrlList)   c.dispose();
    for (final c in _serviceFeeCtrlList)  c.dispose();
    for (final c in _securityDepCtrlList) c.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  ROOM OFFER HELPERS
  // ════════════════════════════════════════════════════════════════════════

  void _addRoomOffer() {
    setState(() {
      _roomOffers.add(RoomOffer());
      _priceCtrlList.add(TextEditingController());
      _unitsCtrlList.add(TextEditingController());
      _occupantsCtrlList.add(TextEditingController());
      _serviceFeeCtrlList.add(TextEditingController());
      _securityDepCtrlList.add(TextEditingController());
    });
  }

  void _removeRoomOffer(int index) {
    if (_roomOffers.length == 1) return;
    setState(() {
      _roomOffers.removeAt(index);
      _priceCtrlList[index].dispose();
      _unitsCtrlList[index].dispose();
      _occupantsCtrlList[index].dispose();
      _serviceFeeCtrlList[index].dispose();
      _securityDepCtrlList[index].dispose();
      _priceCtrlList.removeAt(index);
      _unitsCtrlList.removeAt(index);
      _occupantsCtrlList.removeAt(index);
      _serviceFeeCtrlList.removeAt(index);
      _securityDepCtrlList.removeAt(index);
    });
  }

  /// Syncs all text controller values back into model objects before save.
  void _syncRoomOfferControllers() {
    for (int i = 0; i < _roomOffers.length; i++) {
      final isMonthly = _roomOffers[i].pricingMode == 'monthly';
      if (isMonthly) {
        _roomOffers[i].priceMonthly = _priceCtrlList[i].text;
      } else {
        _roomOffers[i].priceDaily = _priceCtrlList[i].text;
      }
      _roomOffers[i].availableUnits  = _unitsCtrlList[i].text;
      _roomOffers[i].maxOccupants    = _occupantsCtrlList[i].text;
      _roomOffers[i].serviceFee      = _serviceFeeCtrlList[i].text;
      _roomOffers[i].securityDeposit = _securityDepCtrlList[i].text;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PHOTO HELPERS
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _images          = picked.map((e) => File(e.path)).toList();
        _coverImageIndex = 0;
      });
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PUBLISH — Two-step write: property doc → room subcollection docs
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _publishApartment() async {
    // Step 0: Sync controllers → models
    _syncRoomOfferControllers();
    _rentalTerms.minimumStayMonths     = int.tryParse(_minStayCtrl.text)       ?? 1;
    _rentalTerms.advanceMonthsRequired = int.tryParse(_advanceMonthsCtrl.text) ?? 1;

    final validRooms = _roomOffers.where((r) => r.isValid).toList();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnack('Please log in again to publish your listing.', isError: true);
      return;
    }

    // Validation
    if (titleCtrl.text.isEmpty    ||
        locationCtrl.text.isEmpty ||
        _selectedCategory == null ||
        _images.isEmpty           ||
        _selectedLatLng == null   ||
        validRooms.isEmpty) {
      _showSnack(
        validRooms.isEmpty
            ? "Add at least one valid room offer"
            : "Fill all required fields, add photos, select category, and pin location",
        isError: true,
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // ── Step 1: Upload all images ─────────────────────────────────────
      final List<String> imageUrls = [];
      for (final img in _images) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('apartments')
            .child('${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        final task = await ref.putFile(img);
        imageUrls.add(await task.ref.getDownloadURL());
      }

      final String coverImageUrl = imageUrls.isNotEmpty
          ? imageUrls[_coverImageIndex.clamp(0, imageUrls.length - 1)]
          : '';

      // ── Step 2: Create the property-level document ────────────────────
      // minPrice uses activePrice (respects pricingMode) across all rooms.
RoomOffer cheapestRoom = validRooms.first;

for (final room in validRooms) {
  if (room.activePrice < cheapestRoom.activePrice) {
    cheapestRoom = room;
  }
}

final double minPrice = cheapestRoom.activePrice;
final String minPricingMode = cheapestRoom.pricingMode;

      final propertyRef = await FirebaseFirestore.instance
          .collection("properties")
          .add({
        "name":        titleCtrl.text.trim(),
        "address":     locationCtrl.text.trim(),
        "city": _selectedCity,
        "description": descCtrl.text.trim(),
        "category":    _selectedCategory,

        // Rental terms — deposit intentionally excluded (now per-room)
        "rentalTerms": _rentalTerms.toFirestoreMap(),

        "houseRules":  _selectedRules.toList(),
        "amenities":   _selectedAmenities.toList(),

        "imageUrls":     imageUrls,
        "coverImageUrl": coverImageUrl,

        "isActive": _isActive,

        "coordinates": GeoPoint(
          _selectedLatLng!.latitude,
          _selectedLatLng!.longitude,
        ),

        "minPrice":    minPrice,
        "minPricingMode": minPricingMode,
        "rating":      0,
        "reviewCount": 0,

        "ownerId":   uid,
        "createdAt": Timestamp.now(),
      });

      // ── Step 3: Batch-write all rooms to the subcollection ────────────
      // Each room document includes its own serviceFee AND securityDeposit.
      // This is the key architectural change — deposit is scoped to the room,
      // not the property, enabling different deposit per room type.
      final batch = FirebaseFirestore.instance.batch();

      for (final room in validRooms) {
final roomRef = propertyRef.collection('rooms').doc();

batch.set(roomRef, {
  "id": roomRef.id,
  ...room.toFirestoreMap(),
});
      }

      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (e is FirebaseException) {
        debugPrint('[PUBLISH LISTING] Firebase error [${e.code}]: ${e.message}');
      } else {
        debugPrint('[PUBLISH LISTING] Error: $e');
      }
      if (mounted) _showSnack('Failed to publish listing. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? Colors.redAccent : AppColors.textDark,
      behavior:        SnackBarBehavior.floating,
      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin:          const EdgeInsets.all(16),
    ));
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar:          _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _sectionLabel("Basic Info"),
            const SizedBox(height: 10),
            _card(child: _basicInfoSection()),
            const SizedBox(height: 24),

            _sectionLabel("Property Category"),
            const SizedBox(height: 10),
            _card(child: _categorySection()),
            const SizedBox(height: 24),

            _sectionLabel("Description"),
            const SizedBox(height: 10),
            _card(child: _descriptionSection()),
            const SizedBox(height: 24),

            _sectionLabel("Rental Terms"),
            const SizedBox(height: 4),
            const Text(
              "Minimum stay and advance payment policy that applies to all rooms. "
              "Security deposit is set individually per room.",
              style: TextStyle(fontSize: 12.5, color: AppColors.textMid, height: 1.5),
            ),
            const SizedBox(height: 10),
            _card(child: _rentalTermsSection()),
            const SizedBox(height: 24),

            _sectionLabel("House Rules"),
            const SizedBox(height: 10),
            _selectorCard(
              title:    "House Rules",
              hint:     "Select the rules guests should follow",
              selected: _selectedRules,
              onTap:    _openHouseRulesSheet,
            ),
            const SizedBox(height: 24),

            _sectionLabel("Availability"),
            const SizedBox(height: 10),
            _card(child: _availabilitySection()),
            const SizedBox(height: 24),

            _sectionLabel("Room Offers"),
            const SizedBox(height: 4),
            const Text(
              "Each offer is saved as its own room document with its own pricing, "
              "service fee, and security deposit.",
              style: TextStyle(fontSize: 12.5, color: AppColors.textMid, height: 1.5),
            ),
            const SizedBox(height: 10),
            _roomOffersSection(),
            const SizedBox(height: 24),

            _sectionLabel("Pin Location"),
            const SizedBox(height: 10),
            _card(child: _mapSection()),
            const SizedBox(height: 24),

            _sectionLabel("Amenities"),
            const SizedBox(height: 10),
            _selectorCard(
              title:    "Amenities",
              hint:     "Select what your property or room offers",
              selected: _selectedAmenities,
              onTap:    _openAmenitiesSheet,
            ),
            const SizedBox(height: 24),

            _sectionLabel("Photos"),
            const SizedBox(height: 10),
            _uploadPhotosWidget(),
            const SizedBox(height: 12),
            _previewImages(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  APP BAR
  // ════════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor:        AppColors.background(context),
      elevation:              0,
      centerTitle:            true,
      scrolledUnderElevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:        AppColors.card(context),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color:      Colors.black.withOpacity(.06),
                  blurRadius: 12,
                  offset:     const Offset(0, 4))
            ],
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.text(context), size: 18),
        ),
      ),
      title: Text(
        "New Listing",
        style: TextStyle(
          color:       AppColors.text(context),
          fontWeight:  FontWeight.w700,
          fontSize:    18,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BOTTOM BAR
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color:     AppColors.card(context),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(.06),
              blurRadius: 24,
              offset:     const Offset(0, -8))
        ],
      ),
      child: SizedBox(
        height: 58,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
            elevation:       0,
            shadowColor:     Colors.transparent,
            shape:           RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: _loading ? null : _publishApartment,
          child: _loading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rocket_launch_rounded, size: 18),
                    SizedBox(width: 8),
                    Text("Publish Listing",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            letterSpacing: 0.2)),
                  ],
                ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SHARED HELPERS
  // ════════════════════════════════════════════════════════════════════════

  Widget _sectionLabel(String label) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      fontSize:      11,
      fontWeight:    FontWeight.w700,
      color:         AppColors.textLight,
      letterSpacing: 1.4,
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color:        AppColors.card(context),
      borderRadius: BorderRadius.circular(24),
      border:       Border.all(color: AppColors.border, width: 1),
      boxShadow: [
        BoxShadow(
            color:      Colors.black.withOpacity(.04),
            blurRadius: 20,
            offset:     const Offset(0, 8))
      ],
    ),
    child: child,
  );

  Widget _input({
    required String hint,
    required TextEditingController ctrl,
    IconData? icon,
    bool      isNumber = false,
    String?   prefix,
    int?      maxLength,
    TextInputFormatter? formatter,
    int maxLines = 1,
  }) {
    return TextField(
      controller:      ctrl,
      keyboardType:    isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: [if (formatter != null) formatter],
      maxLength:       maxLength,
      maxLines:        maxLines,
      style: TextStyle(
          color: AppColors.text(context), fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText:    hint,
        hintStyle:   const TextStyle(color: AppColors.textLight, fontSize: 15),
        prefixText:  prefix,
        prefixStyle: const TextStyle(
            color: AppColors.primaryOrange, fontWeight: FontWeight.w600, fontSize: 15),
        prefixIcon:  icon != null
            ? Icon(icon, color: AppColors.textLight, size: 20)
            : null,
        counterText: '',
        filled:      true,
        fillColor:   AppColors.cardSoft(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:   const BorderSide(color: AppColors.border, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: AppColors.primaryOrange, width: 1.5)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:   BorderSide.none),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController ctrl,
    required String                hint,
    required ValueChanged<String>  onChanged,
    String?   prefix,
    IconData? icon,
  }) {
    return TextField(
      controller:      ctrl,
      keyboardType:    TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged:       onChanged,
      style: TextStyle(
          color: AppColors.text(context), fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText:    hint,
        hintStyle:   const TextStyle(color: AppColors.textLight, fontSize: 13),
        prefixText:  prefix,
        prefixStyle: const TextStyle(
            color: AppColors.primaryOrange, fontWeight: FontWeight.w600, fontSize: 14),
        prefixIcon:  icon != null
            ? Icon(icon, color: AppColors.textLight, size: 18)
            : null,
        filled:      true,
        fillColor:   AppColors.cardSoft(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   const BorderSide(color: AppColors.border, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.primaryOrange, width: 1.5)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   BorderSide.none),
      ),
    );
  }

  Widget _inlineDropdown<T>({
    required T?                    value,
    required List<T>               items,
    required String                hint,
    required ValueChanged<T?>      onChanged,
    String Function(T)?            labelBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color:        AppColors.cardSoft(context),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.border, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value:    value,
          hint:     Text(hint,
              style: TextStyle(color: AppColors.textLight, fontSize: 14)),
          icon:     const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textMid, size: 20),
          isExpanded: true,
          style: TextStyle(
              color: AppColors.text(context), fontSize: 14, fontWeight: FontWeight.w500),
          items: items
              .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(
                        labelBuilder != null ? labelBuilder(t) : t.toString()),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: BASIC INFO
  // ════════════════════════════════════════════════════════════════════════

Widget _basicInfoSection() {
  return Column(
    children: [
      _input(
        hint: "Property name",
        ctrl: titleCtrl,
        icon: Icons.apartment_rounded,
      ),
      const SizedBox(height: 12),

      _inlineDropdown<String>(
  value: _selectedCity,
  items: AppCities.list,
        hint: "Select city",
        onChanged: (val) {
          setState(() {
            _selectedCity = val;
            locationCtrl.text = val ?? '';
          });
        },
      ),
    ],
  );
}

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: CATEGORY
  // ════════════════════════════════════════════════════════════════════════

  Widget _categorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inlineDropdown<String>(
          value:    _selectedCategory,
          items:    _categories,
          hint:     "Select property category",
          onChanged: (val) => setState(() => _selectedCategory = val),
        ),
        if (_selectedCategory != null) ...[
          const SizedBox(height: 10),
          _summaryChip(
            icon:        Icons.category_rounded,
            text:        _selectedCategory!,
            color:       const Color(0xFF6366F1),
            bgColor:     const Color(0xFFEEF2FF),
            borderColor: const Color(0xFFC7D2FE),
          ),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: DESCRIPTION
  // ════════════════════════════════════════════════════════════════════════

  Widget _descriptionSection() {
    return TextField(
      controller: descCtrl,
      maxLines:   4,
      style: TextStyle(
          color: AppColors.text(context), fontSize: 15, height: 1.6),
      decoration: InputDecoration(
        hintText:  "Describe your property — highlights, rules, nearby spots...",
        hintStyle: const TextStyle(
            color: AppColors.textLight, fontSize: 14, height: 1.6),
        filled:      true,
        fillColor:   AppColors.cardSoft(context),
        contentPadding: const EdgeInsets.all(18),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:   const BorderSide(color: AppColors.border, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: AppColors.primaryOrange, width: 1.5)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:   BorderSide.none),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: RENTAL TERMS  (deposit field removed)
  // ════════════════════════════════════════════════════════════════════════

  Widget _rentalTermsSection() {
    return Row(
      children: [
        Expanded(
          child: _rentalTermTile(
            label:    "Min. Stay",
            sublabel: "months",
            ctrl:     _minStayCtrl,
            icon:     Icons.calendar_month_rounded,
            onChanged: (v) =>
                _rentalTerms.minimumStayMonths = int.tryParse(v) ?? 1,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _rentalTermTile(
            label:    "Advance",
            sublabel: "months required",
            ctrl:     _advanceMonthsCtrl,
            icon:     Icons.payments_outlined,
            onChanged: (v) =>
                _rentalTerms.advanceMonthsRequired = int.tryParse(v) ?? 1,
          ),
        ),
      ],
    );
  }

  Widget _rentalTermTile({
    required String                label,
    required String                sublabel,
    required TextEditingController ctrl,
    required IconData              icon,
    required ValueChanged<String>  onChanged,
    int min = 1,
    int max = 24,
  }) {
    final value = int.tryParse(ctrl.text) ?? min;
    final atMin = value <= min;
    final atMax = value >= max;

    void step(int delta) {
      final next = (value + delta).clamp(min, max);
      ctrl.text = next.toString();
      onChanged(ctrl.text);
      setState(() {});
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.cardSoft(context),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.primaryOrange.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.primaryOrange),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w700,
                    color:      AppColors.text(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stepper row: [−] value [+]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stepperBtn(
                icon:     Icons.remove_rounded,
                disabled: atMin,
                onTap:    atMin ? null : () => step(-1),
              ),
              Text(
                ctrl.text,
                style: const TextStyle(
                  fontSize:   24,
                  fontWeight: FontWeight.w800,
                  color:      AppColors.primaryOrange,
                ),
              ),
              _stepperBtn(
                icon:     Icons.add_rounded,
                disabled: atMax,
                onTap:    atMax ? null : () => step(1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(sublabel,
              style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
          const SizedBox(height: 2),
          const Text(
            'Tap + or − to adjust',
            style: TextStyle(fontSize: 10, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  Widget _stepperBtn({
    required IconData     icon,
    required bool         disabled,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width:  28,
        height: 28,
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.border
              : AppColors.primaryOrange.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: disabled
                ? AppColors.border
                : AppColors.primaryOrange.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size:  14,
          color: disabled ? AppColors.textLight : AppColors.primaryOrange,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SELECTOR CARD  (compact summary shown on the main form page)
  // ════════════════════════════════════════════════════════════════════════

  Widget _selectorCard({
    required String       title,
    required String       hint,
    required Set<String>  selected,
    required VoidCallback onTap,
  }) {
    final count   = selected.length;
    final preview = selected.take(3).toList();
    final extra   = count > 3 ? count - 3 : 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color:        AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: count > 0
                ? AppColors.primaryOrange.withOpacity(0.45)
                : AppColors.border,
            width: count > 0 ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(.04),
              blurRadius: 20,
              offset:     const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (count == 0)
                    Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 13,
                        color:    AppColors.textLight,
                      ),
                    )
                  else
                    Text(
                      preview.join(' · ') +
                          (extra > 0 ? '  +$extra more' : ''),
                      style: const TextStyle(
                        fontSize: 13,
                        color:    AppColors.textMid,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:        AppColors.primaryOrange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$count selected",
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: count > 0 ? AppColors.primaryOrange : AppColors.textLight,
              size:  20,
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BOTTOM SHEET OPENERS
  // ════════════════════════════════════════════════════════════════════════

  void _openAmenitiesSheet() {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _buildSelectionSheet(
          ctx:        ctx,
          setSheet:   setSheet,
          sheetTitle: "Select Amenities",
          helperText: "Select what your property or room offers.",
          groups:     _amenityGroups,
          selected:   _selectedAmenities,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _openHouseRulesSheet() {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _buildSelectionSheet(
          ctx:        ctx,
          setSheet:   setSheet,
          sheetTitle: "Select House Rules",
          helperText: "Select the rules guests should follow.",
          groups:     _ruleGroups,
          selected:   _selectedRules,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BOTTOM SHEET BUILDER
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildSelectionSheet({
    required BuildContext              ctx,
    required StateSetter               setSheet,
    required String                    sheetTitle,
    required String                    helperText,
    required Map<String, List<String>> groups,
    required Set<String>               selected,
  }) {
    final mq = MediaQuery.of(ctx);
    return Container(
      height: mq.size.height * 0.88,
      decoration: BoxDecoration(
        color:        AppColors.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Drag handle
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width:  44, height: 4,
                decoration: BoxDecoration(
                  color:        AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Title row + count badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  sheetTitle,
                  style: TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.w800,
                    color:      AppColors.text(context),
                    letterSpacing: -.3,
                  ),
                ),
                const Spacer(),
                if (selected.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:        AppColors.primaryOrange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${selected.length} selected",
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              helperText,
              style: const TextStyle(fontSize: 13, color: AppColors.textMid),
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),

          // Scrollable chip groups
          Expanded(
            child: SingleChildScrollView(
              padding:  const EdgeInsets.fromLTRB(20, 8, 20, 16),
              physics:  const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: groups.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          fontSize:      10,
                          fontWeight:    FontWeight.w700,
                          color:         AppColors.textLight,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing:    8,
                        runSpacing: 8,
                        children: entry.value.map((item) {
                          final active = selected.contains(item);
                          return GestureDetector(
                            onTap: () => setSheet(() {
                              active
                                  ? selected.remove(item)
                                  : selected.add(item);
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve:    Curves.easeOut,
                              padding:  const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.primaryOrange.withOpacity(0.10)
                                    : AppColors.cardSoft(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: active
                                      ? AppColors.primaryOrange
                                      : AppColors.border,
                                  width: active ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (active) ...[
                                    const Icon(Icons.check_rounded,
                                        color: AppColors.primaryOrange,
                                        size:  13),
                                    const SizedBox(width: 5),
                                  ],
                                  Text(
                                    item,
                                    style: TextStyle(
                                      color: active
                                          ? AppColors.primaryOrange
                                          : AppColors.textMid,
                                      fontWeight: active
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          // Done button
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, mq.padding.bottom + 20),
            child: SizedBox(
              height: 52,
              width:  double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  elevation:       0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  selected.isEmpty
                      ? "Done"
                      : "Done  ·  ${selected.length} selected",
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: PROPERTY AVAILABILITY
  // ════════════════════════════════════════════════════════════════════════

  Widget _availabilitySection() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _isActive
                ? const Color(0xFFECFDF5)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _isActive
                ? Icons.check_circle_rounded
                : Icons.pause_circle_rounded,
            color: _isActive
                ? const Color(0xFF059669)
                : AppColors.textLight,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isActive ? "Property is Active" : "Property is Hidden",
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   14,
                    color:      AppColors.text(context)),
              ),
              Text(
                _isActive
                    ? "Visible to renters and searchable"
                    : "Hidden from listings — not searchable",
                style: const TextStyle(fontSize: 12, color: AppColors.textMid),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value:      _isActive,
          onChanged:  (v) => setState(() => _isActive = v),
          activeColor: AppColors.primaryOrange,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: ROOM OFFERS
  // ════════════════════════════════════════════════════════════════════════

  Widget _roomOffersSection() {
    return Column(
      children: [
        ...List.generate(_roomOffers.length, (i) => _roomOfferCard(i)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _addRoomOffer,
          child: Container(
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkCardSoft
                  : AppColors.orangeLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(.3), width: 1.2),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline_rounded,
                    color: AppColors.primaryOrange, size: 18),
                SizedBox(width: 8),
                Text(
                  "Add Another Room Type",
                  style: TextStyle(
                      color:      AppColors.primaryOrange,
                      fontWeight: FontWeight.w700,
                      fontSize:   14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ROOM OFFER CARD
  //
  //  Field order inside each card:
  //    1. Header (number, availability toggle, delete)
  //    2. Room Type dropdown
  //    3. Pricing Mode toggle pill
  //    4. Price / Units (row)
  //    5. Service Fee
  //    6. Security Deposit   ← NEW position (below service fee)
  //    7. Max Occupants / Gender (row)
  //    8. Summary chip (when isValid)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _roomOfferCard(int index) {
    final offer     = _roomOffers[index];
    final canRemove = _roomOffers.length > 1;
    final isMonthly = offer.pricingMode == 'monthly';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(.04),
                blurRadius: 16,
                offset:     const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── 1. Header ─────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color:        AppColors.orangeLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.door_front_door_outlined,
                      color: AppColors.primaryOrange, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  "Room Offer ${index + 1}",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   14,
                    color:      AppColors.text(context),
                  ),
                ),
                const Spacer(),
                // Availability toggle
                Row(
                  children: [
                    Text(
                      offer.isAvailable ? "Available" : "Unavailable",
                      style: TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                        color:      offer.isAvailable
                            ? const Color(0xFF059669)
                            : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch.adaptive(
                        value:      offer.isAvailable,
                        onChanged:  (v) =>
                            setState(() => _roomOffers[index].isAvailable = v),
                        activeColor: AppColors.primaryOrange,
                      ),
                    ),
                  ],
                ),
                if (canRemove) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _removeRoomOffer(index),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color:        Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.delete_outline_rounded,
                          color: Colors.red.shade400, size: 16),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 14),

            // ── 2. Room type dropdown ─────────────────────────────────────
            _inlineDropdown<String>(
              value: offer.roomType.isEmpty ? null : offer.roomType,
              items: _roomTypes,
              hint:  "Room type",
              onChanged: (val) =>
                  setState(() => _roomOffers[index].roomType = val ?? ''),
            ),

            const SizedBox(height: 14),

            // ── 3. Pricing mode label ─────────────────────────────────────
            const Text(
              "PRICING MODE",
              style: TextStyle(
                fontSize:      10,
                fontWeight:    FontWeight.w700,
                color:         AppColors.textLight,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            // ── 3a. Toggle pill ───────────────────────────────────────────
            Container(
              height: 40,
              decoration: BoxDecoration(
                color:        AppColors.cardSoft(context),
                borderRadius: BorderRadius.circular(14),
                border:       Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                children: [
                  _pricingModeTab(
                    label:  "Monthly",
                    icon:   Icons.calendar_month_rounded,
                    active: isMonthly,
                    onTap:  () {
                      setState(() {
                        if (!isMonthly) {
                          _roomOffers[index].priceDaily =
                              _priceCtrlList[index].text;
                        } else {
                          _roomOffers[index].priceMonthly =
                              _priceCtrlList[index].text;
                        }
                        _roomOffers[index].pricingMode = 'monthly';
                        _priceCtrlList[index].text =
                            _roomOffers[index].priceMonthly == '0'
                                ? ''
                                : _roomOffers[index].priceMonthly;
                      });
                    },
                  ),
                  _pricingModeTab(
                    label:  "Daily",
                    icon:   Icons.today_rounded,
                    active: !isMonthly,
                    onTap:  () {
                      setState(() {
                        if (isMonthly) {
                          _roomOffers[index].priceMonthly =
                              _priceCtrlList[index].text;
                        } else {
                          _roomOffers[index].priceDaily =
                              _priceCtrlList[index].text;
                        }
                        _roomOffers[index].pricingMode = 'daily';
                        _priceCtrlList[index].text =
                            _roomOffers[index].priceDaily == '0'
                                ? ''
                                : _roomOffers[index].priceDaily;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── 4. Price + Units (row) ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _numberField(
                    ctrl:   _priceCtrlList[index],
                    hint:   isMonthly ? "Price / month" : "Price / day",
                    prefix: "₱ ",
                    icon:   Icons.payments_outlined,
                    onChanged: (v) {
                      if (isMonthly) {
                        _roomOffers[index].priceMonthly = v;
                      } else {
                        _roomOffers[index].priceDaily = v;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: _numberField(
                    ctrl:      _unitsCtrlList[index],
                    hint:      "Units",
                    icon:      Icons.meeting_room_outlined,
                    onChanged: (v) => _roomOffers[index].availableUnits = v,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── 5. Service Fee ────────────────────────────────────────────
            _numberField(
              ctrl:      _serviceFeeCtrlList[index],
              hint:      "Service fee (optional)",
              prefix:    "₱ ",
              icon:      Icons.receipt_outlined,
              onChanged: (v) => _roomOffers[index].serviceFee = v,
            ),

            const SizedBox(height: 10),

            // ── 6. Security Deposit ───────────────────────────────────────
            // Placed here (below service fee, above occupants) so all
            // financial fields are grouped together before capacity fields.
            _numberField(
              ctrl:      _securityDepCtrlList[index],
              hint:      "Security deposit (optional)",
              prefix:    "₱ ",
              icon:      Icons.shield_outlined,
              onChanged: (v) => _roomOffers[index].securityDeposit = v,
            ),

            const SizedBox(height: 10),

            // ── 7. Max Occupants + Gender (row) ───────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _numberField(
                    ctrl:      _occupantsCtrlList[index],
                    hint:      "Max occupants",
                    icon:      Icons.group_outlined,
                    onChanged: (v) => _roomOffers[index].maxOccupants = v,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: _inlineDropdown<String>(
                    value:    offer.genderRestriction,
                    items:    _genderOptions,
                    hint:     "Gender",
                    onChanged: (val) => setState(() =>
                        _roomOffers[index].genderRestriction = val ?? 'open'),
                    labelBuilder: (g) => _genderLabels[g] ?? g,
                  ),
                ),
              ],
            ),

            // ── 8. Summary chip ───────────────────────────────────────────
            if (offer.isValid) ...[
              const SizedBox(height: 10),
              _roomOfferSummaryChip(offer),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PRICING MODE TAB
  // ─────────────────────────────────────────────────────────────────────────

  Widget _pricingModeTab({
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
          margin:   const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color:        active ? AppColors.primaryOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color:      AppColors.primaryOrange.withOpacity(.28),
                      blurRadius: 8,
                      offset:     const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size:  13,
                  color: active ? Colors.white : AppColors.textMid),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize:   12.5,
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

  // ─────────────────────────────────────────────────────────────────────────
  //  ROOM OFFER SUMMARY CHIP
  //
  //  Example output:
  //    1 Bedroom · ₱8,990/mo · ₱3,000 deposit · ₱50 fee · 3 units · Max 2 · Female Only
  // ─────────────────────────────────────────────────────────────────────────

  Widget _roomOfferSummaryChip(RoomOffer offer) {
    final isMonthly = offer.pricingMode == 'monthly';

    String _fmtInt(String raw) {
      final val = double.tryParse(raw.trim()) ?? 0;
      return val
          .toInt()
          .toString()
          .replaceAllMapped(
              RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    }

    final priceFormatted = isMonthly
        ? _fmtInt(offer.priceMonthly)
        : _fmtInt(offer.priceDaily);
    final priceSuffix = isMonthly ? '/mo' : '/day';

    final fee     = double.tryParse(offer.serviceFee.trim())      ?? 0;
    final deposit = double.tryParse(offer.securityDeposit.trim()) ?? 0;

    final feeStr     = fee     > 0 ? '  ·  ₱${_fmtInt(offer.serviceFee)} fee'            : '';
    final depositStr = deposit > 0 ? '  ·  ₱${_fmtInt(offer.securityDeposit)} deposit'   : '';

    final genderLabel = offer.genderRestriction == 'open'
        ? 'Any gender'
        : _genderLabels[offer.genderRestriction] ?? offer.genderRestriction;

    final unitCount  = int.tryParse(offer.availableUnits.trim()) ?? 0;
    final unitSuffix = unitCount == 1 ? 'unit' : 'units';

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color:        const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: const Color(0xFF6EE7B7), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF059669), size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              "${offer.roomType}  ·  "
              "₱$priceFormatted$priceSuffix"
              "$depositStr"
              "$feeStr  ·  "
              "$unitCount $unitSuffix  ·  "
              "Max ${offer.maxOccupants}  ·  "
              "$genderLabel",
              style: const TextStyle(
                fontSize:   11.5,
                color:      Color(0xFF065F46),
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: MAP
  // ════════════════════════════════════════════════════════════════════════

  Widget _mapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color:        AppColors.orangeLight,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.location_on_rounded,
                  color: AppColors.primaryOrange, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Drop a Pin",
                    style: TextStyle(
                        fontSize:   15,
                        fontWeight: FontWeight.w700,
                        color:      AppColors.text(context))),
                const Text("Tap anywhere on the map",
                    style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 240,
            child: GoogleMap(
              initialCameraPosition: _initialPosition,
              zoomControlsEnabled:   false,
              myLocationEnabled:     true,
              myLocationButtonEnabled: true,
              onMapCreated: (c) => _mapController = c,
              onTap: (position) {
                setState(() => _selectedLatLng = position);
                _mapController
                    ?.animateCamera(CameraUpdate.newLatLng(position));
              },
              markers: _selectedLatLng != null
                  ? {
                      Marker(
                        markerId: const MarkerId("selected_location"),
                        position: _selectedLatLng!,
                        draggable: true,
                        onDragEnd: (p) => setState(() => _selectedLatLng = p),
                      ),
                    }
                  : {},
            ),
          ),
        ),
        if (_selectedLatLng != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color:        AppColors.orangeLight,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primaryOrange, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    "${_selectedLatLng!.latitude.toStringAsFixed(5)}, "
                    "${_selectedLatLng!.longitude.toStringAsFixed(5)}",
                    style: const TextStyle(
                        fontSize:   12,
                        color:      AppColors.primaryOrange,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: PHOTOS + COVER SELECTION
  // ════════════════════════════════════════════════════════════════════════

  Widget _uploadPhotosWidget() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: AppColors.primaryOrange.withOpacity(.35), width: 1.5),
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkCardSoft
              : AppColors.orangeLight,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color:      AppColors.primaryOrange.withOpacity(.15),
                        blurRadius: 16,
                        offset:     const Offset(0, 4))
                  ],
                ),
                child: const Icon(Icons.add_photo_alternate_rounded,
                    size: 28, color: AppColors.primaryOrange),
              ),
              const SizedBox(height: 10),
              const Text("Tap to add photos",
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize:   14,
                      color:      AppColors.primaryOrange)),
              const SizedBox(height: 2),
              const Text("JPG, PNG supported",
                  style: TextStyle(fontSize: 12, color: AppColors.textLight)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewImages() {
    if (_images.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(
                "${_images.length} photo${_images.length > 1 ? 's' : ''} selected",
                style: const TextStyle(
                    fontSize:   12,
                    color:      AppColors.textMid,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              const Text("· Tap a photo to set as cover",
                  style: TextStyle(fontSize: 11.5, color: AppColors.textLight)),
            ],
          ),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics:         const BouncingScrollPhysics(),
            itemCount:       _images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final isCover = i == _coverImageIndex;
              return GestureDetector(
                onTap: () => setState(() => _coverImageIndex = i),
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCover
                              ? AppColors.primaryOrange
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(_images[i],
                            width: 100, height: 100, fit: BoxFit.cover),
                      ),
                    ),
                    if (isCover)
                      Positioned(
                        bottom: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color:        AppColors.primaryOrange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text("Cover",
                              style: TextStyle(
                                  color:      Colors.white,
                                  fontSize:   10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      )
                    else
                      Positioned(
                        top: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color:        Colors.black.withOpacity(.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text("${i + 1}",
                              style: const TextStyle(
                                  color:      Colors.white,
                                  fontSize:   11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SHARED: GENERIC SUMMARY CHIP
  // ════════════════════════════════════════════════════════════════════════

  Widget _summaryChip({
    required IconData icon,
    required String   text,
    Color color       = const Color(0xFF059669),
    Color bgColor     = const Color(0xFFECFDF5),
    Color borderColor = const Color(0xFF6EE7B7),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}