// ════════════════════════════════════════════════════════════════════════════
//  FILE: add_apartment_screen.dart
//
//  Architecture: Scalable Rental System — Property + Rooms (Subcollection)
//
//  ┌─────────────────────────────────────────────────────────────────────┐
//  │  WHY SUBCOLLECTION INSTEAD OF ARRAY FOR ROOMS?                      │
//  │                                                                     │
//  │  1. FILTERING BY PRICE                                              │
//  │     Firestore cannot query inside arrays. With subcollections,      │
//  │     you can do: rooms.where('priceMonthly', isLessThan: 5000)       │
//  │     This is essential for a "Filter by budget" feature.             │
//  │                                                                     │
//  │  2. SCALABILITY                                                     │
//  │     Firestore documents have a 1 MB size limit. A property with     │
//  │     50+ rooms stored as an array hits this limit. Subcollections    │
//  │     have no such constraint.                                        │
//  │                                                                     │
//  │  3. FUTURE BOOKING SYSTEM                                           │
//  │     Each room document will hold its own bookings subcollection:    │
//  │     properties/{id}/rooms/{roomId}/bookings/{bookingId}             │
//  │     This makes booking history per room trivial to implement.       │
//  │                                                                     │
//  │  4. UPDATING AVAILABILITY                                           │
//  │     When a booking is made, only ONE room document is updated,      │
//  │     not the entire property document. This avoids write conflicts   │
//  │     and keeps operations atomic at the room level.                  │
//  │                                                                     │
//  │  5. PERFORMANCE                                                     │
//  │     When loading a property list/card, the property document is     │
//  │     fetched without loading all room data. Room details are loaded  │
//  │     only when the user opens a property — lazy loading by design.   │
//  └─────────────────────────────────────────────────────────────────────┘
//
//  Firestore Structure:
//
//  properties/{propertyId}           ← property-level document
//  ├── name, location, description
//  ├── category                      ← Apartment Building / Boarding House / etc.
//  ├── amenities[]
//  ├── houseRules[]
//  ├── rentalTerms {}                ← minimumStay, securityDeposit, advanceMonths
//  ├── coverImageUrl                 ← single URL of the selected cover photo
//  ├── imageUrls[]                   ← all uploaded photo URLs
//  ├── isActive                      ← property availability toggle
//  ├── rating, reviewCount
//  ├── ownerId, createdAt, coordinates
//  └── minPrice                      ← convenience field: lowest room price
//
//  properties/{propertyId}/rooms/{roomId}   ← room-level subcollection
//  ├── roomType
//  ├── priceMonthly
//  ├── availableUnits
//  ├── maxOccupants
//  ├── genderRestriction             ← open / female / male
//  └── isAvailable
//
//  Future Booking Structure (not implemented yet — structure prepared):
//  properties/{propertyId}/rooms/{roomId}/bookings/{bookingId}
//  ├── tenantId
//  ├── startDate, endDate
//  ├── status                        ← pending / confirmed / cancelled
//  └── createdAt
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
// ════════════════════════════════════════════════════════════════════════════
//  MODELS
// ════════════════════════════════════════════════════════════════════════════

// ─── Room Offer Model ────────────────────────────────────────────────────────
// Represents one rentable room type inside a property.
// Stored as a DOCUMENT in the rooms subcollection, NOT as an array element.
// ─── Rental Terms Model ──────────────────────────────────────────────────────
// Property-level terms that apply to ALL rooms in this property.
class RentalTerms {
  int minimumStayMonths;
  double securityDepositAmount;
  int advanceMonthsRequired;

  RentalTerms({
    this.minimumStayMonths = 1,
    this.securityDepositAmount = 0.0,
    this.advanceMonthsRequired = 1,
  });

  Map<String, dynamic> toFirestoreMap() => {
        'minimumStayMonths':    minimumStayMonths,
        'securityDepositAmount': securityDepositAmount,
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

  // ── Design Constants (unchanged from original) ───────────────────────────
  static const _orange      = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFFF0EB);
  static const _bg          = Color(0xFFF8F7F5);
  static const _cardBg      = Colors.white;
  static const _textDark    = Color(0xFF1A1A2E);
  static const _textMid     = Color(0xFF6B7280);
  static const _textLight   = Color(0xFF9CA3AF);
  static const _border      = Color(0xFFEEECE8);

  // ── Property-level Controllers ───────────────────────────────────────────
  final titleCtrl    = TextEditingController();
  final locationCtrl = TextEditingController(text: "Urdaneta City, Pangasinan");
  final descCtrl     = TextEditingController();

  // ── Property Category ────────────────────────────────────────────────────
  static const _categories = [
    'Apartment Building',
    'Boarding House',
    'Condo Unit',
    'Whole House',
  ];
  String? _selectedCategory;

  // ── Rental Terms ─────────────────────────────────────────────────────────
  final RentalTerms _rentalTerms = RentalTerms();
  final _minStayCtrl        = TextEditingController(text: '1');
  final _depositCtrl        = TextEditingController();
  final _advanceMonthsCtrl  = TextEditingController(text: '1');

  // ── House Rules ──────────────────────────────────────────────────────────
  static const _allHouseRules = [
    'No smoking',
    'No pets',
    'Visitors allowed',
    'Female only',
    'Male only',
    'Curfew required',
  ];
  final Set<String> _selectedRules = {};

  // ── Property Availability ────────────────────────────────────────────────
  bool _isActive = true;

  // ── Amenities ────────────────────────────────────────────────────────────
  static const _amenities = [
    "WiFi", "Parking", "Aircon", "Balcony", "CCTV", "Gym", "Pet Friendly",
  ];
  final Set<String> _selectedAmenities = {};

  // ── Photos ───────────────────────────────────────────────────────────────
  List<File> _images = [];
  int _coverImageIndex = 0; // Index of the image selected as cover

  // ── Room Offers (subcollection rows) ─────────────────────────────────────
  final List<RoomOffer> _roomOffers = [RoomOffer()];
  // Parallel controller lists — same index as _roomOffers
  final List<TextEditingController> _priceCtrlList   = [TextEditingController()];
  final List<TextEditingController> _unitsCtrlList   = [TextEditingController()];
  final List<TextEditingController> _occupantsCtrlList = [TextEditingController()];

  // ── Room type options ─────────────────────────────────────────────────────
  static const _roomTypes = [
    'Studio', '1 Bedroom', '2 Bedroom', 'Bed Space', 'Entire Unit',
  ];

  // ── Gender Restriction options ────────────────────────────────────────────
  static const _genderOptions = ['open', 'female', 'male'];
  static const _genderLabels  = {'open': 'Open', 'female': 'Female Only', 'male': 'Male Only'};

  // ── Map ───────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  LatLng? _selectedLatLng;
  static const _initialPosition = CameraPosition(
    target: LatLng(15.9750, 120.5710),
    zoom: 14,
  );

  // ── State ─────────────────────────────────────────────────────────────────
  bool _loading = false;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  final _picker = ImagePicker();

  // ════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    titleCtrl.dispose();
    locationCtrl.dispose();
    descCtrl.dispose();
    _minStayCtrl.dispose();
    _depositCtrl.dispose();
    _advanceMonthsCtrl.dispose();
    for (final c in _priceCtrlList)    c.dispose();
    for (final c in _unitsCtrlList)    c.dispose();
    for (final c in _occupantsCtrlList) c.dispose();
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
    });
  }

  void _removeRoomOffer(int index) {
    if (_roomOffers.length == 1) return;
    setState(() {
      _roomOffers.removeAt(index);
      _priceCtrlList[index].dispose();
      _unitsCtrlList[index].dispose();
      _occupantsCtrlList[index].dispose();
      _priceCtrlList.removeAt(index);
      _unitsCtrlList.removeAt(index);
      _occupantsCtrlList.removeAt(index);
    });
  }

  /// Syncs text controller values back into the model objects before save/validate.
  void _syncRoomOfferControllers() {
    for (int i = 0; i < _roomOffers.length; i++) {
      _roomOffers[i].priceMonthly   = _priceCtrlList[i].text;
      _roomOffers[i].availableUnits = _unitsCtrlList[i].text;
      _roomOffers[i].maxOccupants   = _occupantsCtrlList[i].text;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PHOTO HELPERS
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _images = picked.map((e) => File(e.path)).toList();
        _coverImageIndex = 0; // default cover = first image
      });
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PUBLISH — Two-step write: property doc → room subcollection docs
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _publishApartment() async {
    // Step 0: Sync controller text → models
    _syncRoomOfferControllers();
    _rentalTerms.minimumStayMonths    = int.tryParse(_minStayCtrl.text)       ?? 1;
    _rentalTerms.securityDepositAmount = double.tryParse(_depositCtrl.text)   ?? 0.0;
    _rentalTerms.advanceMonthsRequired = int.tryParse(_advanceMonthsCtrl.text) ?? 1;

    final validRooms = _roomOffers.where((r) => r.isValid).toList();

    // Validation
    if (titleCtrl.text.isEmpty      ||
        locationCtrl.text.isEmpty   ||
        _selectedCategory == null   ||
        _images.isEmpty             ||
        _selectedLatLng == null     ||
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
      // ── Step 1: Upload all images to Firebase Storage ─────────────────
      final List<String> imageUrls = [];
      for (final img in _images) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('apartments')
            .child('${_uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        final task = await ref.putFile(img);
        imageUrls.add(await task.ref.getDownloadURL());
      }

      // The cover image is whichever was selected by the user (index-based)
      final String coverImageUrl = imageUrls.isNotEmpty
          ? imageUrls[_coverImageIndex.clamp(0, imageUrls.length - 1)]
          : '';

      // ── Step 2: Create the property-level document ────────────────────
      // Room offers are NOT stored here — they live in the subcollection.
      // We only store a convenience minPrice field for list card rendering.
      final double minPrice = validRooms
          .map((r) => double.tryParse(r.priceMonthly.trim()) ?? 0.0)
          .reduce((a, b) => a < b ? a : b);

      final propertyRef = await FirebaseFirestore.instance
          .collection("properties")
          .add({
        // ── Basic info ───────────────────────────────────────────────────
        "name":         titleCtrl.text.trim(),
        "location":     locationCtrl.text.trim(),
        "description":  descCtrl.text.trim(),
        "category":     _selectedCategory,

        // ── Rental terms (property-wide policy) ─────────────────────────
        "rentalTerms":  _rentalTerms.toFirestoreMap(),

        // ── House rules ──────────────────────────────────────────────────
        "houseRules":   _selectedRules.toList(),

        // ── Amenities ────────────────────────────────────────────────────
        "amenities":    _selectedAmenities.toList(),

        // ── Photos ───────────────────────────────────────────────────────
        "imageUrls":      imageUrls,        // all uploaded photo URLs
        "coverImageUrl":  coverImageUrl,    // single cover image for list cards

        // ── Availability ─────────────────────────────────────────────────
        "isActive":     _isActive,

        // ── Location ────────────────────────────────────────────────────
        "coordinates":  GeoPoint(
          _selectedLatLng!.latitude,
          _selectedLatLng!.longitude,
        ),

        // ── Convenience fields (derived, not duplicated from rooms) ──────
        "minPrice":     minPrice,  // Lowest room price — used in property list cards
        "rating":       0,
        "reviewCount":  0,

        // ── Metadata ─────────────────────────────────────────────────────
        "ownerId":    _uid,
        "createdAt":  Timestamp.now(),

        // ── Prepared for future booking system ───────────────────────────
        // bookings will live at: properties/{id}/rooms/{roomId}/bookings/{bookingId}
        // No booking fields stored at property level — all booking state is room-scoped.
      });

      // ── Step 3: Write each room as its own document in the subcollection ──
      // Using a batch write ensures atomicity — either all rooms are created
      // or none are, preventing partial property states.
      final batch = FirebaseFirestore.instance.batch();

      for (final room in validRooms) {
        // Auto-generated document ID per room — allows individual room updates
        // without touching the property document or any other room.
        final roomRef = propertyRef.collection('rooms').doc();
        batch.set(roomRef, room.toFirestoreMap());
      }

      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : _textDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Basic Info ──────────────────────────────────────────────
            _sectionLabel("Basic Info"),
            const SizedBox(height: 10),
            _card(child: _basicInfoSection()),
            const SizedBox(height: 24),

            // ── Property Category ───────────────────────────────────────
            _sectionLabel("Property Category"),
            const SizedBox(height: 10),
            _card(child: _categorySection()),
            const SizedBox(height: 24),

            // ── Description ─────────────────────────────────────────────
            _sectionLabel("Description"),
            const SizedBox(height: 10),
            _card(child: _descriptionSection()),
            const SizedBox(height: 24),

            // ── Rental Terms ────────────────────────────────────────────
            _sectionLabel("Rental Terms"),
            const SizedBox(height: 4),
            const Text(
              "Deposit, advance payment, and minimum stay that apply to all rooms.",
              style: TextStyle(fontSize: 12.5, color: _textMid, height: 1.5),
            ),
            const SizedBox(height: 10),
            _card(child: _rentalTermsSection()),
            const SizedBox(height: 24),

            // ── House Rules ─────────────────────────────────────────────
            _sectionLabel("House Rules"),
            const SizedBox(height: 10),
            _card(child: _houseRulesSection()),
            const SizedBox(height: 24),

            // ── Property Availability ───────────────────────────────────
            _sectionLabel("Availability"),
            const SizedBox(height: 10),
            _card(child: _availabilitySection()),
            const SizedBox(height: 24),

            // ── Room Offers (subcollection rows) ────────────────────────
            _sectionLabel("Room Offers"),
            const SizedBox(height: 4),
            const Text(
              "Each offer is saved as its own room document — enabling per-room filtering, availability tracking, and future bookings.",
              style: TextStyle(fontSize: 12.5, color: _textMid, height: 1.5),
            ),
            const SizedBox(height: 10),
            _roomOffersSection(),
            const SizedBox(height: 24),

            // ── Pin Location ────────────────────────────────────────────
            _sectionLabel("Pin Location"),
            const SizedBox(height: 10),
            _card(child: _mapSection()),
            const SizedBox(height: 24),

            // ── Amenities ───────────────────────────────────────────────
            _sectionLabel("Amenities"),
            const SizedBox(height: 10),
            _card(child: _amenitiesSection()),
            const SizedBox(height: 24),

            // ── Photos + Cover Selection ────────────────────────────────
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
  //  APP BAR  (unchanged)
  // ════════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: _textDark, size: 18),
        ),
      ),
      title: const Text(
        "New Listing",
        style: TextStyle(color: _textDark, fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.3),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BOTTOM BAR  (unchanged)
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 24, offset: const Offset(0, -8))],
      ),
      child: SizedBox(
        height: 58,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _orange,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: _loading ? null : _publishApartment,
          child: _loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rocket_launch_rounded, size: 18),
                    SizedBox(width: 8),
                    Text("Publish Listing",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                  ],
                ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SHARED HELPERS  (unchanged)
  // ════════════════════════════════════════════════════════════════════════

  Widget _sectionLabel(String label) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700, color: _textLight, letterSpacing: 1.4,
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _cardBg,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _border, width: 1),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 20, offset: const Offset(0, 8))],
    ),
    child: child,
  );

  Widget _input({
    required String hint,
    required TextEditingController ctrl,
    IconData? icon,
    bool isNumber = false,
    String? prefix,
    int? maxLength,
    TextInputFormatter? formatter,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: [if (formatter != null) formatter],
      maxLength: maxLength,
      maxLines: maxLines,
      style: const TextStyle(color: _textDark, fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textLight, fontSize: 15),
        prefixText: prefix,
        prefixStyle: const TextStyle(color: _orange, fontWeight: FontWeight.w600, fontSize: 15),
        prefixIcon: icon != null ? Icon(icon, color: _textLight, size: 20) : null,
        counterText: '',
        filled: true,
        fillColor: const Color(0xFFFAFAF9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _border, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _orange, width: 1.5)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController ctrl,
    required String hint,
    required ValueChanged<String> onChanged,
    String? prefix,
    IconData? icon,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      style: const TextStyle(color: _textDark, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textLight, fontSize: 13),
        prefixText: prefix,
        prefixStyle: const TextStyle(color: _orange, fontWeight: FontWeight.w600, fontSize: 14),
        prefixIcon: icon != null ? Icon(icon, color: _textLight, size: 18) : null,
        filled: true,
        fillColor: const Color(0xFFFAFAF9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _border, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _orange, width: 1.5)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _inlineDropdown<T>({
    required T? value,
    required List<T> items,
    required String hint,
    required ValueChanged<T?> onChanged,
    String Function(T)? labelBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: _textLight, fontSize: 14)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textMid, size: 20),
          isExpanded: true,
          style: const TextStyle(color: _textDark, fontSize: 14, fontWeight: FontWeight.w500),
          items: items.map((t) => DropdownMenuItem(
            value: t,
            child: Text(labelBuilder != null ? labelBuilder(t) : t.toString()),
          )).toList(),
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
        _input(hint: "Property name", ctrl: titleCtrl, icon: Icons.apartment_rounded),
        const SizedBox(height: 12),
        _input(hint: "Location / City", ctrl: locationCtrl, icon: Icons.location_on_rounded),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: PROPERTY CATEGORY
  // ════════════════════════════════════════════════════════════════════════

  Widget _categorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inlineDropdown<String>(
          value: _selectedCategory,
          items: _categories,
          hint: "Select property category",
          onChanged: (val) => setState(() => _selectedCategory = val),
        ),
        if (_selectedCategory != null) ...[
          const SizedBox(height: 10),
          _summaryChip(
            icon: Icons.category_rounded,
            text: _selectedCategory!,
            color: const Color(0xFF6366F1),
            bgColor: const Color(0xFFEEF2FF),
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
      maxLines: 4,
      style: const TextStyle(color: _textDark, fontSize: 15, height: 1.6),
      decoration: InputDecoration(
        hintText: "Describe your property — highlights, rules, nearby spots...",
        hintStyle: const TextStyle(color: _textLight, fontSize: 14, height: 1.6),
        filled: true,
        fillColor: const Color(0xFFFAFAF9),
        contentPadding: const EdgeInsets.all(18),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _border, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _orange, width: 1.5)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: RENTAL TERMS
  // ════════════════════════════════════════════════════════════════════════

  Widget _rentalTermsSection() {
    return Column(
      children: [
        // Security deposit
        _input(
          hint: "Security deposit amount",
          ctrl: _depositCtrl,
          icon: Icons.shield_outlined,
          prefix: "₱ ",
          isNumber: true,
          formatter: FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ),
        const SizedBox(height: 12),

        // Minimum stay + advance months on same row
        Row(
          children: [
            Expanded(
              child: _rentalTermTile(
                label: "Min. Stay",
                sublabel: "months",
                ctrl: _minStayCtrl,
                icon: Icons.calendar_month_rounded,
                onChanged: (v) => _rentalTerms.minimumStayMonths = int.tryParse(v) ?? 1,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _rentalTermTile(
                label: "Advance",
                sublabel: "months required",
                ctrl: _advanceMonthsCtrl,
                icon: Icons.payments_outlined,
                onChanged: (v) => _rentalTerms.advanceMonthsRequired = int.tryParse(v) ?? 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _rentalTermTile({
    required String label,
    required String sublabel,
    required TextEditingController ctrl,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _orange),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textDark)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onChanged,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _orange),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          Text(sublabel, style: const TextStyle(fontSize: 11, color: _textLight)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: HOUSE RULES
  // ════════════════════════════════════════════════════════════════════════

  Widget _houseRulesSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _allHouseRules.map((rule) {
        final active = _selectedRules.contains(rule);
        return GestureDetector(
          onTap: () => setState(() =>
              active ? _selectedRules.remove(rule) : _selectedRules.add(rule)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: active ? _textDark : const Color(0xFFFAFAF9),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: active ? _textDark : _border, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active) ...[
                  const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                ],
                Text(
                  rule,
                  style: TextStyle(
                    color: active ? Colors.white : _textMid,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: PROPERTY AVAILABILITY TOGGLE
  // ════════════════════════════════════════════════════════════════════════

  Widget _availabilitySection() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _isActive ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
            color: _isActive ? const Color(0xFF059669) : _textLight,
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
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _textDark),
              ),
              Text(
                _isActive
                    ? "Visible to renters and searchable"
                    : "Hidden from listings — not searchable",
                style: const TextStyle(fontSize: 12, color: _textMid),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: _isActive,
          onChanged: (v) => setState(() => _isActive = v),
          activeColor: _orange,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: ROOM OFFERS (subcollection rows)
  // ════════════════════════════════════════════════════════════════════════

  Widget _roomOffersSection() {
    return Column(
      children: [
        ...List.generate(_roomOffers.length, (i) => _roomOfferCard(i)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _addRoomOffer,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _orangeLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _orange.withOpacity(.3), width: 1.2),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline_rounded, color: _orange, size: 18),
                SizedBox(width: 8),
                Text(
                  "Add Another Room Type",
                  style: TextStyle(color: _orange, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _roomOfferCard(int index) {
    final offer    = _roomOffers[index];
    final canRemove = _roomOffers.length > 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Card header row ─────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: _orangeLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.door_front_door_outlined, color: _orange, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  "Room Offer ${index + 1}",
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _textDark),
                ),
                const Spacer(),
                // isAvailable toggle per room
                Row(
                  children: [
                    Text(
                      offer.isAvailable ? "Available" : "Unavailable",
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: offer.isAvailable ? const Color(0xFF059669) : _textLight,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch.adaptive(
                        value: offer.isAvailable,
                        onChanged: (v) => setState(() => _roomOffers[index].isAvailable = v),
                        activeColor: _orange,
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
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 16),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 14),

            // ── Room type dropdown ──────────────────────────────────────
            _inlineDropdown<String>(
              value: offer.roomType.isEmpty ? null : offer.roomType,
              items: _roomTypes,
              hint: "Room type",
              onChanged: (val) => setState(() => _roomOffers[index].roomType = val ?? ''),
            ),

            const SizedBox(height: 10),

            // ── Price + Available Units ─────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _numberField(
                    ctrl: _priceCtrlList[index],
                    hint: "Price / month",
                    prefix: "₱ ",
                    icon: Icons.payments_outlined,
                    onChanged: (v) => _roomOffers[index].priceMonthly = v,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: _numberField(
                    ctrl: _unitsCtrlList[index],
                    hint: "Units",
                    icon: Icons.meeting_room_outlined,
                    onChanged: (v) => _roomOffers[index].availableUnits = v,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Max Occupants + Gender Restriction ─────────────────────
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _numberField(
                    ctrl: _occupantsCtrlList[index],
                    hint: "Max occupants",
                    icon: Icons.group_outlined,
                    onChanged: (v) => _roomOffers[index].maxOccupants = v,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: _inlineDropdown<String>(
                    value: offer.genderRestriction,
                    items: _genderOptions,
                    hint: "Gender",
                    onChanged: (val) => setState(() =>
                        _roomOffers[index].genderRestriction = val ?? 'open'),
                    labelBuilder: (g) => _genderLabels[g] ?? g,
                  ),
                ),
              ],
            ),

            // ── Summary chip when row is fully filled ───────────────────
            if (offer.isValid) ...[
              const SizedBox(height: 10),
              _roomOfferSummaryChip(offer),
            ],
          ],
        ),
      ),
    );
  }

  Widget _roomOfferSummaryChip(RoomOffer offer) {
    final genderLabel = offer.genderRestriction == 'open'
        ? 'Any gender'
        : _genderLabels[offer.genderRestriction] ?? offer.genderRestriction;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6EE7B7), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              "${offer.roomType}  ·  ₱${offer.priceMonthly}/mo  ·  "
              "${offer.availableUnits} unit${int.tryParse(offer.availableUnits) == 1 ? '' : 's'}  ·  "
              "Max ${offer.maxOccupants}  ·  $genderLabel",
              style: const TextStyle(
                fontSize: 11.5, color: Color(0xFF065F46), fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: MAP  (unchanged)
  // ════════════════════════════════════════════════════════════════════════

  Widget _mapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _orangeLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.location_on_rounded, color: _orange, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Drop a Pin", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
                Text("Tap anywhere on the map", style: TextStyle(fontSize: 12, color: _textLight)),
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
              zoomControlsEnabled: false,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (c) => _mapController = c,
              onTap: (position) {
                setState(() => _selectedLatLng = position);
                _mapController?.animateCamera(CameraUpdate.newLatLng(position));
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
              decoration: BoxDecoration(color: _orangeLight, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: _orange, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    "${_selectedLatLng!.latitude.toStringAsFixed(5)}, "
                    "${_selectedLatLng!.longitude.toStringAsFixed(5)}",
                    style: const TextStyle(fontSize: 12, color: _orange, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: AMENITIES  (unchanged)
  // ════════════════════════════════════════════════════════════════════════

  Widget _amenitiesSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _amenities.map((e) {
        final active = _selectedAmenities.contains(e);
        return GestureDetector(
          onTap: () => setState(() =>
              active ? _selectedAmenities.remove(e) : _selectedAmenities.add(e)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: active ? _orange : const Color(0xFFFAFAF9),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: active ? _orange : _border, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active) ...[
                  const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                ],
                Text(e, style: TextStyle(
                  color: active ? Colors.white : _textMid,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                )),
              ],
            ),
          ),
        );
      }).toList(),
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
          border: Border.all(color: _orange.withOpacity(.35), width: 1.5),
          color: _orangeLight,
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
                  boxShadow: [BoxShadow(color: _orange.withOpacity(.15), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.add_photo_alternate_rounded, size: 28, color: _orange),
              ),
              const SizedBox(height: 10),
              const Text("Tap to add photos",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _orange)),
              const SizedBox(height: 2),
              const Text("JPG, PNG supported",
                  style: TextStyle(fontSize: 12, color: _textLight)),
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
        // Count + cover hint
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(
                "${_images.length} photo${_images.length > 1 ? 's' : ''} selected",
                style: const TextStyle(fontSize: 12, color: _textMid, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              const Text(
                "· Tap a photo to set as cover",
                style: TextStyle(fontSize: 11.5, color: _textLight),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final isCover = i == _coverImageIndex;
              return GestureDetector(
                onTap: () => setState(() => _coverImageIndex = i),
                child: Stack(
                  children: [
                    // Image thumbnail
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCover ? _orange : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(_images[i], width: 100, height: 100, fit: BoxFit.cover),
                      ),
                    ),
                    // Cover badge
                    if (isCover)
                      Positioned(
                        bottom: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "Cover",
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                    else
                      // Photo index badge
                      Positioned(
                        top: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${i + 1}",
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
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
    required String text,
    Color color = const Color(0xFF059669),
    Color bgColor = const Color(0xFFECFDF5),
    Color borderColor = const Color(0xFF6EE7B7),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  APARTMENT DETAIL PAGE — Room Offers Display (Read from Subcollection)
//
//  Usage in ApartmentDetailPage:
//
//  StreamBuilder<QuerySnapshot>(
//    stream: FirebaseFirestore.instance
//        .collection('properties')
//        .doc(propertyId)
//        .collection('rooms')
//        .where('isAvailable', isEqualTo: true)  // ← only possible with subcollection
//        .orderBy('priceMonthly')                 // ← only possible with subcollection
//        .snapshots(),
//    builder: (context, snapshot) {
//      final offers = snapshot.data?.docs
//          .map((d) => RoomOfferData.fromMap(d.data() as Map<String, dynamic>))
//          .toList() ?? [];
//      return RoomOffersSection(offers: offers);
//    },
//  )
// ════════════════════════════════════════════════════════════════════════════

/// Parsed room offer read from Firestore subcollection.
class RoomOfferData {
  final String roomType;
  final double priceMonthly;
  final int availableUnits;
  final int maxOccupants;
  final String genderRestriction;
  final bool isAvailable;

  const RoomOfferData({
    required this.roomType,
    required this.priceMonthly,
    required this.availableUnits,
    required this.maxOccupants,
    required this.genderRestriction,
    required this.isAvailable,
  });

  factory RoomOfferData.fromMap(Map<String, dynamic> map) => RoomOfferData(
        roomType:           map['roomType'] ?? '',
        priceMonthly:       (map['priceMonthly'] ?? 0).toDouble(),
        availableUnits:     (map['availableUnits'] ?? 0) as int,
        maxOccupants:       (map['maxOccupants'] ?? 0) as int,
        genderRestriction:  map['genderRestriction'] ?? 'open',
        isAvailable:        map['isAvailable'] ?? true,
      );
}

/// Drop-in section widget for ApartmentDetailPage.
class RoomOffersSection extends StatelessWidget {
  final List<RoomOfferData> offers;
  const RoomOffersSection({super.key, required this.offers});

  static const _orange      = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFFF0EB);
  static const _textDark    = Color(0xFF1A1A2E);
  static const _textMid     = Color(0xFF6B7280);
  static const _border      = Color(0xFFEEECE8);

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Available Rooms',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _orangeLight, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${offers.length} type${offers.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: _orange, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...offers.map((offer) => _RoomOfferTile(offer: offer)),
        ],
      ),
    );
  }
}

class _RoomOfferTile extends StatelessWidget {
  final RoomOfferData offer;
  const _RoomOfferTile({required this.offer});

  static const _orange      = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFFF0EB);
  static const _textDark    = Color(0xFF1A1A2E);
  static const _textMid     = Color(0xFF6B7280);
  static const _border      = Color(0xFFEEECE8);

  static const _typeIcons = <String, IconData>{
    'Studio':       Icons.single_bed_rounded,
    '1 Bedroom':    Icons.bed_rounded,
    '2 Bedroom':    Icons.bedroom_parent_rounded,
    'Bed Space':    Icons.airline_seat_individual_suite_rounded,
    'Entire Unit':  Icons.home_rounded,
  };

  static const _genderIcons = <String, IconData>{
    'open':   Icons.people_rounded,
    'female': Icons.female_rounded,
    'male':   Icons.male_rounded,
  };

  static const _genderLabels = <String, String>{
    'open':   'Any gender',
    'female': 'Female only',
    'male':   'Male only',
  };

  @override
  Widget build(BuildContext context) {
    final available = offer.availableUnits > 0 && offer.isAvailable;
    final icon      = _typeIcons[offer.roomType]  ?? Icons.meeting_room_outlined;
    final gIcon     = _genderIcons[offer.genderRestriction] ?? Icons.people_rounded;
    final gLabel    = _genderLabels[offer.genderRestriction] ?? offer.genderRestriction;

    // Format price with commas: 12500 → 12,500
    final priceFormatted = offer.priceMonthly
        .toInt()
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          // Room type icon badge
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: _orangeLight, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: _orange, size: 22),
          ),
          const SizedBox(width: 14),

          // Room type + details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.roomType,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _textDark)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Availability dot
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: available ? const Color(0xFF34C759) : Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      available
                          ? '${offer.availableUnits} unit${offer.availableUnits == 1 ? '' : 's'} available'
                          : 'Fully occupied',
                      style: TextStyle(
                        fontSize: 12,
                        color: available ? const Color(0xFF059669) : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Max occupants + gender in a row
                Row(
                  children: [
                    Icon(Icons.group_outlined, size: 12, color: _textMid),
                    const SizedBox(width: 3),
                    Text('Max ${offer.maxOccupants}',
                        style: const TextStyle(fontSize: 11.5, color: _textMid)),
                    const SizedBox(width: 10),
                    Icon(gIcon, size: 12, color: _textMid),
                    const SizedBox(width: 3),
                    Text(gLabel, style: const TextStyle(fontSize: 11.5, color: _textMid)),
                  ],
                ),
              ],
            ),
          ),

          // WAG KA MAG ALALA, DI AKO GUMAWA NITO. CLAUDE AI SALAMAT
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱$priceFormatted',
                style: const TextStyle(
                  color: _orange, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3,
                ),
              ),
              const Text('/month', style: TextStyle(fontSize: 11, color: _textMid)),
            ],
          ),
        ],
      ),
    );
  }
}