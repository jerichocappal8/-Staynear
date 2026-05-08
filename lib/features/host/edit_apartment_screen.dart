// ════════════════════════════════════════════════════════════════════════════
//  FILE: edit_apartment_screen.dart
//
//  Architecture: Edit flow for the scalable rental system.
//
//  Edit strategy:
//  ┌──────────────────────────────────────────────────────────────────────┐
//  │  PROPERTY DOCUMENT  →  single .update() call                        │
//  │  ROOM SUBCOLLECTION →  WriteBatch with three operations:            │
//  │    • batch.update()  — existing rooms that were edited              │
//  │    • batch.delete()  — rooms removed by the landlord                │
//  │    • batch.set()     — brand new rooms added during edit            │
//  │                                                                     │
//  │  WHY NOT DELETE-ALL-AND-RECREATE?                                   │
//  │  Rooms that already have bookings must NOT be deleted — their       │
//  │  booking subcollection would be orphaned. We only delete rooms      │
//  │  that the landlord explicitly removed. Existing room document IDs   │
//  │  are preserved so any future booking references remain valid.       │
//  └──────────────────────────────────────────────────────────────────────┘
//
//  CHANGE LOG:
//  • securityDeposit moved from rentalTerms (property-level) → per-room field
//  • _EditableRoom now has securityDeposit field
//  • _securityDepCtrlList added (parallel to _serviceFeeCtrlList)
//  • Deposit input field added inside each room card (below Service Fee)
//  • _syncRoomControllers() syncs deposit controller → model
//  • _EditableRoom.toFirestoreMap() writes securityDeposit
//  • _EditableRoom.fromFirestore() reads securityDeposit
//  • rentalTerms section now only shows minimumStayMonths + advanceMonthsRequired
//  • Room summary chip now shows deposit amount
//
//  minPrice recalculation:
//    Computed client-side from the final list of valid rooms before
//    writing using activePrice (respects monthly vs daily mode),
//    then stored on the property document as a convenience field
//    for list-card rendering.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:staynear/core/app_colors.dart';
import 'package:staynear/core/app_cities.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ROOM EDIT MODEL
//  Tracks whether a room row is brand-new, pre-existing, or marked for deletion.
// ════════════════════════════════════════════════════════════════════════════

enum _RoomState { existing, added, removed }

class _EditableRoom {
  /// Firestore document ID. Null for brand-new rooms that haven't been saved yet.
  final String? docId;

  String roomType           = '';
  String pricingMode        = 'monthly'; // 'monthly' | 'daily'
  String priceMonthly       = '';
  String priceDaily         = '';
  String serviceFee         = '';

  /// Per-room security deposit — replaces old property-level securityDepositAmount.
  /// Stored directly in the room document so different room types can require
  /// different deposit amounts (e.g. Bed Space → ₱500, Entire Unit → ₱8,000).
  String securityDeposit    = '';

  String availableUnits     = '';
  String maxOccupants       = '';
  String genderRestriction  = 'open';
  bool   isAvailable        = true;

  _RoomState state;

  _EditableRoom({
    this.docId,
    this.state = _RoomState.added,
  });

  /// Populate from a Firestore document snapshot.
  factory _EditableRoom.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _EditableRoom(
      docId: doc.id,
      state: _RoomState.existing,
    )
      ..roomType          = d['roomType']          ?? ''
      ..pricingMode       = d['pricingMode']        ?? 'monthly'
      ..priceMonthly      = (d['priceMonthly']      ?? 0).toString()
      ..priceDaily        = (d['priceDaily']        ?? 0).toString()
      ..serviceFee        = (d['serviceFee']        ?? 0).toString()
      ..securityDeposit   = (d['securityDeposit']   ?? 0).toString()
      ..availableUnits    = (d['availableUnits']    ?? 0).toString()
      ..maxOccupants      = (d['maxOccupants']      ?? 0).toString()
      ..genderRestriction = d['genderRestriction']  ?? 'open'
      ..isAvailable       = d['isAvailable']        ?? true;
  }

  Map<String, dynamic> toFirestoreMap() => {
    'roomType'          : roomType.trim(),
    'pricingMode'       : pricingMode,
    'priceMonthly'      : double.tryParse(priceMonthly.trim())    ?? 0.0,
    'priceDaily'        : double.tryParse(priceDaily.trim())      ?? 0.0,
    'serviceFee'        : double.tryParse(serviceFee.trim())      ?? 0.0,
    'securityDeposit'   : double.tryParse(securityDeposit.trim()) ?? 0.0,
    'availableUnits'    : int.tryParse(availableUnits.trim())     ?? 0,
    'maxOccupants'      : int.tryParse(maxOccupants.trim())       ?? 0,
    'genderRestriction' : genderRestriction,
    'isAvailable'       : isAvailable,
    'updatedAt'         : Timestamp.now(),
  };

  /// Validation: price requirement depends on active pricingMode.
  bool get isValid {
    final monthly   = double.tryParse(priceMonthly.trim()) ?? 0;
    final daily     = double.tryParse(priceDaily.trim())   ?? 0;
    final units     = int.tryParse(availableUnits.trim())  ?? 0;
    final occupants = int.tryParse(maxOccupants.trim())    ?? 0;
    final priceOk   = pricingMode == 'monthly' ? monthly > 0 : daily > 0;
    return roomType.isNotEmpty && priceOk && units > 0 && occupants > 0;
  }

  bool get isVisible => state != _RoomState.removed;

  /// Returns the currently active price based on pricingMode.
  double get activePrice => pricingMode == 'monthly'
      ? (double.tryParse(priceMonthly.trim()) ?? 0)
      : (double.tryParse(priceDaily.trim())   ?? 0);
}

// ════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════════════════════════

class EditApartmentScreen extends StatefulWidget {
  final String               docId;
  final Map<String, dynamic> data;

  const EditApartmentScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<EditApartmentScreen> createState() => _EditApartmentScreenState();
}

class _EditApartmentScreenState extends State<EditApartmentScreen>
    with TickerProviderStateMixin {

  // ── Static option lists ───────────────────────────────────────────────────
static const _categories = [
  'Boarding House',
  'Apartment',
  'Dorm',
  'Studio',
  'Condo',
  'Whole House',
  'Hotel',
];
  static const _roomTypes = [
    'Studio', '1 Bedroom', '2 Bedroom', 'Bed Space', 'Entire Unit',
  ];
  static const _genderOptions = ['open', 'female', 'male'];
  static const _genderLabels  = {
    'open':   'Open',
    'female': 'Female Only',
    'male':   'Male Only',
  };
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
  static const _amenitiesList = [
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

  // ── Property-level controllers ────────────────────────────────────────────
  late TextEditingController titleCtrl;
  late TextEditingController locationCtrl;
  late TextEditingController descCtrl;

  String? _selectedCategory;
  String? _selectedCity;

  // Rental terms — deposit intentionally removed (now per-room)
  late TextEditingController _minStayCtrl;
  late TextEditingController _advanceMonthsCtrl;

  final Set<String> _selectedRules     = {};
  final Set<String> _selectedAmenities = {};

  bool _isActive = true;

  // ── Photos ────────────────────────────────────────────────────────────────
  List<String> _existingImageUrls = [];
  List<File>   _newImageFiles     = [];
  int          _coverIndex        = 0;

  int get _totalPhotoCount => _existingImageUrls.length + _newImageFiles.length;

  // ── Map ───────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  LatLng? _selectedLatLng;
  static const _fallbackPosition = CameraPosition(
    target: LatLng(15.9750, 120.5710), zoom: 14,
  );

  // ── Rooms ─────────────────────────────────────────────────────────────────
  List<_EditableRoom> _rooms = [];

  // Parallel controller lists — index-synced with _rooms
  final List<TextEditingController> _priceCtrlList       = [];
  final List<TextEditingController> _unitsCtrlList       = [];
  final List<TextEditingController> _occupantsCtrlList   = [];
  final List<TextEditingController> _serviceFeeCtrlList  = [];
  final List<TextEditingController> _securityDepCtrlList = []; // ← NEW

  bool _roomsLoaded = false;

  // ── Misc ──────────────────────────────────────────────────────────────────
  bool _loading = false;
  final _picker = ImagePicker();

  // ════════════════════════════════════════════════════════════════════════
  //  initState
  // ════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _initPropertyFields();
    _prefetchRooms();
  }

  void _initPropertyFields() {
    final d = widget.data;

    titleCtrl    = TextEditingController(text: d['name']        ?? '');
    _selectedCity = d['city'];
    locationCtrl = TextEditingController(text: _selectedCity ?? '');
    descCtrl     = TextEditingController(text: d['description'] ?? '');

    _selectedCategory = d['category'];

    final terms = (d['rentalTerms'] as Map<String, dynamic>?) ?? {};
    // Deposit intentionally NOT read from rentalTerms — it is now per-room.
    _minStayCtrl       = TextEditingController(text: (terms['minimumStayMonths']     ?? 1).toString());
    _advanceMonthsCtrl = TextEditingController(text: (terms['advanceMonthsRequired'] ?? 1).toString());

    _selectedRules.addAll(List<String>.from(d['houseRules'] ?? []));
    _selectedAmenities.addAll(List<String>.from(d['amenities'] ?? []));

    _isActive = d['isActive'] ?? true;

    _existingImageUrls = List<String>.from(d['imageUrls'] ?? d['images'] ?? []);

    final coverUrl = d['coverImageUrl'] as String?;
    if (coverUrl != null && _existingImageUrls.isNotEmpty) {
      final idx = _existingImageUrls.indexOf(coverUrl);
      _coverIndex = idx >= 0 ? idx : 0;
    }

    if (d['coordinates'] != null) {
      final geo = d['coordinates'] as GeoPoint;
      _selectedLatLng = LatLng(geo.latitude, geo.longitude);
    }
  }

  Future<void> _prefetchRooms() async {
    try {
final snapshot = await FirebaseFirestore.instance
    .collection('properties')
    .doc(widget.docId)
    .collection('rooms')
    .orderBy('updatedAt', descending: true)
    .get();

      final loaded = snapshot.docs
          .map((doc) => _EditableRoom.fromFirestore(doc))
          .toList();

      for (final room in loaded) {
        // Seed the visible price field with the currently active mode's value.
        final seedPrice = room.pricingMode == 'monthly'
            ? (room.priceMonthly == '0' ? '' : room.priceMonthly)
            : (room.priceDaily   == '0' ? '' : room.priceDaily);

        _priceCtrlList.add(TextEditingController(text: seedPrice));
        _unitsCtrlList.add(TextEditingController(
            text: room.availableUnits  == '0' ? '' : room.availableUnits));
        _occupantsCtrlList.add(TextEditingController(
            text: room.maxOccupants    == '0' ? '' : room.maxOccupants));
        _serviceFeeCtrlList.add(TextEditingController(
            text: room.serviceFee      == '0' ? '' : room.serviceFee));
        _securityDepCtrlList.add(TextEditingController(
            text: room.securityDeposit == '0' ? '' : room.securityDeposit));
      }

      if (loaded.isEmpty) _appendNewRoomRow();

      setState(() {
        _rooms = loaded;
        _roomsLoaded = true;
      });
    } catch (e) {
      _appendNewRoomRow();
      setState(() => _roomsLoaded = true);
      _showSnack("Could not load rooms: $e", isError: true);
    }
  }

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
  //  ROOM HELPERS
  // ════════════════════════════════════════════════════════════════════════

  void _appendNewRoomRow() {
    _rooms.add(_EditableRoom(state: _RoomState.added));
    _priceCtrlList.add(TextEditingController());
    _unitsCtrlList.add(TextEditingController());
    _occupantsCtrlList.add(TextEditingController());
    _serviceFeeCtrlList.add(TextEditingController());
    _securityDepCtrlList.add(TextEditingController());
  }

  void _addRoomOffer() => setState(_appendNewRoomRow);

  void _markRoomRemoved(int index) {
    final visibleCount = _rooms.where((r) => r.isVisible).length;
    if (visibleCount <= 1) return;
    setState(() => _rooms[index].state = _RoomState.removed);
  }

  void _syncRoomControllers() {
    for (int i = 0; i < _rooms.length; i++) {
      _rooms[i].availableUnits  = _unitsCtrlList[i].text;
      _rooms[i].maxOccupants    = _occupantsCtrlList[i].text;
      _rooms[i].serviceFee      = _serviceFeeCtrlList[i].text;
      _rooms[i].securityDeposit = _securityDepCtrlList[i].text;
      // Route price to the correct slot based on active mode.
      if (_rooms[i].pricingMode == 'monthly') {
        _rooms[i].priceMonthly = _priceCtrlList[i].text;
      } else {
        _rooms[i].priceDaily = _priceCtrlList[i].text;
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PHOTO HELPERS
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _pickNewImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _newImageFiles.addAll(picked.map((e) => File(e.path)));
      });
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
      if (_coverIndex >= _existingImageUrls.length) {
        _coverIndex = (_existingImageUrls.length - 1).clamp(0, 999);
      }
    });
  }

  void _removeNewImage(int newFileIndex) {
    setState(() {
      _newImageFiles.removeAt(newFileIndex);
      final threshold = _existingImageUrls.length;
      if (_coverIndex >= threshold + _newImageFiles.length) {
        _coverIndex = (threshold + _newImageFiles.length - 1).clamp(0, 999);
      }
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  //  UPDATE
  // ════════════════════════════════════════════════════════════════════════

Future<void> _updateApartment() async {
  _syncRoomControllers();

  final int minStay   = int.tryParse(_minStayCtrl.text) ?? 1;
  final int advMonths = int.tryParse(_advanceMonthsCtrl.text) ?? 1;

  // ✅ Define active rooms
  final activeRooms = _rooms
      .where((r) => r.state != _RoomState.removed && r.isValid)
      .toList();

  if (titleCtrl.text.isEmpty ||
      locationCtrl.text.isEmpty ||
      _selectedCategory == null ||
      _selectedLatLng == null ||
      activeRooms.isEmpty) {
    _showSnack(
      activeRooms.isEmpty
          ? "Add at least one valid room offer"
          : "Fill all required fields, select category, and pin location",
      isError: true,
    );
    return;
  }

  // ✅ Safe min price calculation
  final double minPrice = activeRooms
      .map((r) => r.activePrice)
      .reduce((a, b) => a < b ? a : b);

    setState(() => _loading = true);

    try {
      // ── Step 1: Upload new images ─────────────────────────────────────
      final List<String> newlyUploadedUrls = [];
      final uid = FirebaseAuth.instance.currentUser!.uid;
      for (final img in _newImageFiles) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('apartments')
            .child('${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        final task = await ref.putFile(img);
        newlyUploadedUrls.add(await task.ref.getDownloadURL());
      }

      final List<String> finalImageUrls = [
        ..._existingImageUrls,
        ...newlyUploadedUrls,
      ];

      String coverImageUrl = '';
      if (finalImageUrls.isNotEmpty) {
        final safeIndex = _coverIndex.clamp(0, finalImageUrls.length - 1);
        coverImageUrl = finalImageUrls[safeIndex];
      }

      // ── Step 2: Recalculate minPrice using activePrice ────────────────
      final double minPrice = activeRooms
          .map((r) => r.activePrice)
          .reduce((a, b) => a < b ? a : b);

      // ── Step 3: Update property document ─────────────────────────────
      final propertyRef = FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.docId);

      await propertyRef.update({
        'name':        titleCtrl.text.trim(),
        'location':    locationCtrl.text.trim(),
        'city': _selectedCity,
        'description': descCtrl.text.trim(),
        'category':    _selectedCategory,

        // Rental terms — deposit intentionally excluded (now per-room)
        'rentalTerms': {
          'minimumStayMonths':     minStay,
          'advanceMonthsRequired': advMonths,
        },

        'houseRules':    _selectedRules.toList(),
        'amenities':     _selectedAmenities.toList(),
        'imageUrls':     finalImageUrls,
        'coverImageUrl': coverImageUrl,
        'isActive':      _isActive,
        'coordinates':   GeoPoint(
          _selectedLatLng!.latitude,
          _selectedLatLng!.longitude,
        ),
        'minPrice':  minPrice,
        'updatedAt': Timestamp.now(),
      });

      // ── Step 4: Batch-write room subcollection ────────────────────────
      // Existing rooms → batch.update()
      // Removed rooms  → batch.delete()
      // New rooms      → batch.set()
      // toFirestoreMap() now includes securityDeposit per room.
      final batch       = FirebaseFirestore.instance.batch();
      final roomsColRef = propertyRef.collection('rooms');

      for (final room in _rooms) {
        switch (room.state) {
          case _RoomState.existing:
            batch.update(roomsColRef.doc(room.docId!), room.toFirestoreMap());
            break;
          case _RoomState.removed:
            if (room.docId != null) {
              batch.delete(roomsColRef.doc(room.docId!));
            }
            break;
          case _RoomState.added:
            if (room.isValid) {
              batch.set(roomsColRef.doc(), {
                ...room.toFirestoreMap(),
                'createdAt': Timestamp.now(),
              });
            }
            break;
        }
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
      appBar: _buildAppBar(),
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
              "Each offer is saved as its own room document — enabling per-room filtering, availability tracking, and future bookings.",
              style: TextStyle(fontSize: 12.5, color: AppColors.textMid, height: 1.5),
            ),
            const SizedBox(height: 10),
            _roomsLoaded ? _roomOffersSection() : _roomsLoadingPlaceholder(),
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
            _card(child: _photosSection()),
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
      scrolledUnderElevation: 0,
      centerTitle:            true,
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
        "Edit Listing",
        style: TextStyle(
          color:         AppColors.text(context),
          fontWeight:    FontWeight.w700,
          fontSize:      18,
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: _loading ? null : _updateApartment,
          child: _loading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_rounded, size: 18),
                    SizedBox(width: 8),
                    Text("Save Changes",
                        style: TextStyle(
                            fontSize:      16,
                            fontWeight:    FontWeight.w700,
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
    required String                hint,
    required TextEditingController ctrl,
    IconData?                      icon,
    bool                           isNumber = false,
    String?                        prefix,
    TextInputFormatter?            formatter,
    int                            maxLines = 1,
  }) {
    return TextField(
      controller:      ctrl,
      keyboardType:    isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: [if (formatter != null) formatter],
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
        filled:         true,
        fillColor:      AppColors.cardSoft(context),
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
        filled:         true,
        fillColor:      AppColors.cardSoft(context),
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
    required T?               value,
    required List<T>          items,
    required String           hint,
    required ValueChanged<T?> onChanged,
    String Function(T)?       labelBuilder,
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
          value:      value,
          hint:       Text(hint,
              style: const TextStyle(color: AppColors.textLight, fontSize: 14)),
          icon:       const Icon(Icons.keyboard_arrow_down_rounded,
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
Widget _categorySection() {
  return Column(
    children: [

      _inlineDropdown<String>(
        value: _selectedCategory,
        items: _categories,
        hint: "Select property category",
        onChanged: (val) {
          setState(() {
            _selectedCategory = val;
          });
        },
      ),

    ],
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
        filled:         true,
        fillColor:      AppColors.cardSoft(context),
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
  //  SECTION: RENTAL TERMS  (deposit field removed — now per-room)
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
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _rentalTermTile(
            label:    "Advance",
            sublabel: "months required",
            ctrl:     _advanceMonthsCtrl,
            icon:     Icons.payments_outlined,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.cardSoft(context),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primaryOrange),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.text(context))),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller:      ctrl,
            keyboardType:    TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign:       TextAlign.center,
            style: const TextStyle(
                fontSize:   22,
                fontWeight: FontWeight.w800,
                color:      AppColors.primaryOrange),
            decoration: const InputDecoration(
              border:         InputBorder.none,
              isDense:        true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          Text(sublabel,
              style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
        ],
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
                    fontSize:      18,
                    fontWeight:    FontWeight.w800,
                    color:         AppColors.text(context),
                    letterSpacing: -.3,
                  ),
                ),
                const Spacer(),
                if (selected.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              physics: const BouncingScrollPhysics(),
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
  //  SECTION: AVAILABILITY TOGGLE
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
            _isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
            color: _isActive ? const Color(0xFF059669) : AppColors.textLight,
            size:  20,
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
          value:       _isActive,
          onChanged:   (v) => setState(() => _isActive = v),
          activeColor: AppColors.primaryOrange,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SECTION: ROOM OFFERS
  // ════════════════════════════════════════════════════════════════════════

  Widget _roomsLoadingPlaceholder() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color:        AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: AppColors.border, width: 1),
      ),
      child: const Center(
        child: CircularProgressIndicator(
            color: AppColors.primaryOrange, strokeWidth: 2.5),
      ),
    );
  }

  Widget _roomOffersSection() {
    return Column(
      children: [
        ...List.generate(_rooms.length, (i) {
          if (!_rooms[i].isVisible) return const SizedBox.shrink();
          return _roomOfferCard(i);
        }),
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
  //  Field order:
  //    1. Header (number, New/Existing badge, availability toggle, delete)
  //    2. Room Type dropdown
  //    3. Pricing Mode label
  //    4. Toggle pill (Monthly | Daily)
  //    5. Price / Units (row)
  //    6. Service Fee
  //    7. Security Deposit   ← NEW (below service fee, above occupants)
  //    8. Max Occupants / Gender (row)
  //    9. Summary chip (when isValid)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _roomOfferCard(int index) {
    final room      = _rooms[index];
    final isMonthly = room.pricingMode == 'monthly';
    final isNew     = room.state == _RoomState.added;
    final canRemove = _rooms.where((r) => r.isVisible).length > 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isNew
                ? AppColors.primaryOrange.withOpacity(.35)
                : AppColors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(.04),
                blurRadius: 16,
                offset:     const Offset(0, 6))
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
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.door_front_door_outlined,
                      color: AppColors.primaryOrange, size: 16),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Room Offer ${index + 1}",
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   14,
                          color:      AppColors.text(context)),
                    ),
                    if (isNew)
                      const Text("New",
                          style: TextStyle(
                              fontSize:   10,
                              color:      AppColors.primaryOrange,
                              fontWeight: FontWeight.w600))
                    else
                      const Text("Existing",
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textLight)),
                  ],
                ),
                const Spacer(),
                // isAvailable toggle
                Row(
                  children: [
                    Text(
                      room.isAvailable ? "Available" : "Unavailable",
                      style: TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                        color:      room.isAvailable
                            ? const Color(0xFF059669)
                            : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch.adaptive(
                        value:      room.isAvailable,
                        onChanged:  (v) =>
                            setState(() => _rooms[index].isAvailable = v),
                        activeColor: AppColors.primaryOrange,
                      ),
                    ),
                  ],
                ),
                if (canRemove) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _markRoomRemoved(index),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color:        Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8)),
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
              value:    room.roomType.isEmpty ? null : room.roomType,
              items:    _roomTypes,
              hint:     "Room type",
              onChanged: (val) =>
                  setState(() => _rooms[index].roomType = val ?? ''),
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

            // ── 4. Toggle pill ────────────────────────────────────────────
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
                    onTap: () {
                      setState(() {
                        if (!isMonthly) {
                          _rooms[index].priceDaily = _priceCtrlList[index].text;
                        } else {
                          _rooms[index].priceMonthly = _priceCtrlList[index].text;
                        }
                        _rooms[index].pricingMode = 'monthly';
                        _priceCtrlList[index].text =
                            _rooms[index].priceMonthly == '0'
                                ? ''
                                : _rooms[index].priceMonthly;
                      });
                    },
                  ),
                  _pricingModeTab(
                    label:  "Daily",
                    icon:   Icons.today_rounded,
                    active: !isMonthly,
                    onTap: () {
                      setState(() {
                        if (isMonthly) {
                          _rooms[index].priceMonthly = _priceCtrlList[index].text;
                        } else {
                          _rooms[index].priceDaily = _priceCtrlList[index].text;
                        }
                        _rooms[index].pricingMode = 'daily';
                        _priceCtrlList[index].text =
                            _rooms[index].priceDaily == '0'
                                ? ''
                                : _rooms[index].priceDaily;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── 5. Price + Units (row) ────────────────────────────────────
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
                        _rooms[index].priceMonthly = v;
                      } else {
                        _rooms[index].priceDaily = v;
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
                    onChanged: (v) => _rooms[index].availableUnits = v,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── 6. Service Fee ────────────────────────────────────────────
            _numberField(
              ctrl:      _serviceFeeCtrlList[index],
              hint:      "Service fee (optional)",
              prefix:    "₱ ",
              icon:      Icons.receipt_outlined,
              onChanged: (v) => _rooms[index].serviceFee = v,
            ),

            const SizedBox(height: 10),

            // ── 7. Security Deposit ───────────────────────────────────────
            // Placed below service fee so all financial fields are grouped
            // together before capacity fields (occupants / gender).
            _numberField(
              ctrl:      _securityDepCtrlList[index],
              hint:      "Security deposit (optional)",
              prefix:    "₱ ",
              icon:      Icons.shield_outlined,
              onChanged: (v) => _rooms[index].securityDeposit = v,
            ),

            const SizedBox(height: 10),

            // ── 8. Max Occupants + Gender (row) ───────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _numberField(
                    ctrl:      _occupantsCtrlList[index],
                    hint:      "Max occupants",
                    icon:      Icons.group_outlined,
                    onChanged: (v) => _rooms[index].maxOccupants = v,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: _inlineDropdown<String>(
                    value:    room.genderRestriction,
                    items:    _genderOptions,
                    hint:     "Gender",
                    onChanged: (val) => setState(() =>
                        _rooms[index].genderRestriction = val ?? 'open'),
                    labelBuilder: (g) => _genderLabels[g] ?? g,
                  ),
                ),
              ],
            ),

            // ── 9. Summary chip ───────────────────────────────────────────
            if (room.isValid) ...[
              const SizedBox(height: 10),
              _roomSummaryChip(room),
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
  //  ROOM SUMMARY CHIP
  //
  //  Example:
  //    1 Bedroom · ₱8,990/mo · ₱3,000 deposit · ₱50 fee · 3 units · Max 2 · Female Only
  // ─────────────────────────────────────────────────────────────────────────

  Widget _roomSummaryChip(_EditableRoom room) {
    final isMonthly = room.pricingMode == 'monthly';

    String _fmtInt(String raw) {
      final val = double.tryParse(raw.trim()) ?? 0;
      return val
          .toInt()
          .toString()
          .replaceAllMapped(
              RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    }

    final priceFormatted = isMonthly
        ? _fmtInt(room.priceMonthly)
        : _fmtInt(room.priceDaily);
    final priceSuffix = isMonthly ? '/mo' : '/day';

    final fee     = double.tryParse(room.serviceFee.trim())      ?? 0;
    final deposit = double.tryParse(room.securityDeposit.trim()) ?? 0;

    final depositStr = deposit > 0
        ? '  ·  ₱${_fmtInt(room.securityDeposit)} deposit'
        : '';
    final feeStr = fee > 0
        ? '  ·  ₱${_fmtInt(room.serviceFee)} fee'
        : '';

    final genderLabel = room.genderRestriction == 'open'
        ? 'Any gender'
        : _genderLabels[room.genderRestriction] ?? room.genderRestriction;

    final unitCount  = int.tryParse(room.availableUnits.trim()) ?? 0;
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
              "${room.roomType}  ·  "
              "₱$priceFormatted$priceSuffix"
              "$depositStr"
              "$feeStr  ·  "
              "$unitCount $unitSuffix  ·  "
              "Max ${room.maxOccupants}  ·  "
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
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textLight)),
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
              initialCameraPosition: _selectedLatLng != null
                  ? CameraPosition(target: _selectedLatLng!, zoom: 14)
                  : _fallbackPosition,
              zoomControlsEnabled:     false,
              myLocationEnabled:       true,
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
                        markerId: const MarkerId("selected"),
                        position: _selectedLatLng!,
                        draggable: true,
                        onDragEnd: (p) =>
                            setState(() => _selectedLatLng = p),
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
  //  SECTION: PHOTOS
  // ════════════════════════════════════════════════════════════════════════

  Widget _photosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Header ────────────────────────────────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color:        AppColors.orangeLight,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.photo_library_rounded,
                  color: AppColors.primaryOrange, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Listing Photos",
                    style: TextStyle(
                        fontSize:   15,
                        fontWeight: FontWeight.w700,
                        color:      AppColors.text(context))),
                Text(
                  "$_totalPhotoCount photo${_totalPhotoCount != 1 ? 's' : ''}  ·  Tap to set cover",
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Photo grid ────────────────────────────────────────────────────
        if (_totalPhotoCount > 0) ...[
          Wrap(
            spacing:    10,
            runSpacing: 10,
            children: [
              // Existing (network) images
              ...List.generate(_existingImageUrls.length, (i) {
                final globalIndex = i;
                final isCover     = globalIndex == _coverIndex;
                return _photoTileNetwork(
                  url:        _existingImageUrls[i],
                  isCover:    isCover,
                  onSetCover: () => setState(() => _coverIndex = globalIndex),
                  onRemove:   () => _removeExistingImage(i),
                );
              }),
              // New (local) images
              ...List.generate(_newImageFiles.length, (i) {
                final globalIndex = _existingImageUrls.length + i;
                final isCover     = globalIndex == _coverIndex;
                return _photoTileFile(
                  file:       _newImageFiles[i],
                  isCover:    isCover,
                  onSetCover: () => setState(() => _coverIndex = globalIndex),
                  onRemove:   () => _removeNewImage(i),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── Add more photos button ─────────────────────────────────────────
        GestureDetector(
          onTap: _pickNewImages,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkCardSoft
                  : AppColors.orangeLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(.35), width: 1.2),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_rounded,
                    color: AppColors.primaryOrange, size: 20),
                SizedBox(width: 8),
                Text("Add More Photos",
                    style: TextStyle(
                        color:      AppColors.primaryOrange,
                        fontWeight: FontWeight.w700,
                        fontSize:   14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoTileNetwork({
    required String       url,
    required bool         isCover,
    required VoidCallback onSetCover,
    required VoidCallback onRemove,
  }) {
    return GestureDetector(
      onTap: onSetCover,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isCover ? AppColors.primaryOrange : Colors.transparent,
                  width: 2.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(url,
                  width: 90, height: 90, fit: BoxFit.cover),
            ),
          ),
          if (isCover)
            Positioned(
              bottom: 6, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color:        AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(6)),
                child: const Text("Cover",
                    style: TextStyle(
                        color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
          Positioned(
            top: 5, right: 5,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.55),
                    shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                    size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoTileFile({
    required File         file,
    required bool         isCover,
    required VoidCallback onSetCover,
    required VoidCallback onRemove,
  }) {
    return GestureDetector(
      onTap: onSetCover,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isCover ? AppColors.primaryOrange : Colors.transparent,
                  width: 2.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(file,
                  width: 90, height: 90, fit: BoxFit.cover),
            ),
          ),
          if (isCover)
            Positioned(
              bottom: 6, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color:        AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(6)),
                child: const Text("Cover",
                    style: TextStyle(
                        color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
          if (!isCover)
            Positioned(
              top: 5, left: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color:        AppColors.textDark,
                    borderRadius: BorderRadius.circular(6)),
                child: const Text("NEW",
                    style: TextStyle(
                        color:         Colors.white,
                        fontSize:      9,
                        fontWeight:    FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
            ),
          Positioned(
            top: 5, right: 5,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.55),
                    shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                    size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}