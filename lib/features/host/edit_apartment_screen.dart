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
//  minPrice recalculation:
//    Computed client-side from the final list of valid rooms before
//    writing, then stored on the property document as a convenience field
//    for list-card rendering. It is NEVER trusted as the source of truth
//    for individual room prices — those live in the subcollection.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ROOM EDIT MODEL
//  Tracks whether a room row is brand-new, pre-existing, or marked for deletion.
// ════════════════════════════════════════════════════════════════════════════

enum _RoomState { existing, added, removed }

class _EditableRoom {
  /// Firestore document ID. Null for brand-new rooms that haven't been saved yet.
  final String? docId;

  String roomType;
  String priceMonthly;
  String availableUnits;
  String maxOccupants;
  String genderRestriction;
  bool isAvailable;

  _RoomState state;

  _EditableRoom({
    this.docId,
    this.roomType = '',
    this.priceMonthly = '',
    this.availableUnits = '',
    this.maxOccupants = '',
    this.genderRestriction = 'open',
    this.isAvailable = true,
    this.state = _RoomState.added,
  });

  /// Populate from a Firestore document snapshot.
  factory _EditableRoom.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _EditableRoom(
      docId:             doc.id,
      roomType:          d['roomType'] ?? '',
      priceMonthly:      (d['priceMonthly'] ?? 0).toString(),
      availableUnits:    (d['availableUnits'] ?? 0).toString(),
      maxOccupants:      (d['maxOccupants'] ?? 0).toString(),
      genderRestriction: d['genderRestriction'] ?? 'open',
      isAvailable:       d['isAvailable'] ?? true,
      state:             _RoomState.existing,
    );
  }

  Map<String, dynamic> toFirestoreMap() => {
        'roomType':           roomType.trim(),
        'priceMonthly':       double.tryParse(priceMonthly.trim()) ?? 0.0,
        'availableUnits':     int.tryParse(availableUnits.trim()) ?? 0,
        'maxOccupants':       int.tryParse(maxOccupants.trim()) ?? 0,
        'genderRestriction':  genderRestriction,
        'isAvailable':        isAvailable,
        // updatedAt lets the future booking system detect stale cached data
        'updatedAt':          Timestamp.now(),
      };

  bool get isValid =>
      roomType.isNotEmpty &&
      (double.tryParse(priceMonthly.trim()) ?? 0) > 0 &&
      (int.tryParse(availableUnits.trim()) ?? 0) > 0 &&
      (int.tryParse(maxOccupants.trim()) ?? 0) > 0;

  bool get isVisible => state != _RoomState.removed;
}

// ════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════════════════════════

class EditApartmentScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditApartmentScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<EditApartmentScreen> createState() => _EditApartmentScreenState();
}

class _EditApartmentScreenState extends State<EditApartmentScreen> {

  // ── Design constants (identical to AddApartmentScreen) ───────────────────
  static const _orange      = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFFF0EB);
  static const _bg          = Color(0xFFF8F7F5);
  static const _cardBg      = Colors.white;
  static const _textDark    = Color(0xFF1A1A2E);
  static const _textMid     = Color(0xFF6B7280);
  static const _textLight   = Color(0xFF9CA3AF);
  static const _border      = Color(0xFFEEECE8);

  // ── Static option lists ───────────────────────────────────────────────────
  static const _categories = [
    'Apartment Building', 'Boarding House', 'Condo Unit', 'Whole House',
  ];
  static const _roomTypes = [
    'Studio', '1 Bedroom', '2 Bedroom', 'Bed Space', 'Entire Unit',
  ];
  static const _genderOptions  = ['open', 'female', 'male'];
  static const _genderLabels   = {'open': 'Open', 'female': 'Female Only', 'male': 'Male Only'};
  static const _allHouseRules  = [
    'No smoking', 'No pets', 'Visitors allowed',
    'Female only', 'Male only', 'Curfew required',
  ];
  static const _amenitiesList  = [
    'WiFi', 'Parking', 'Aircon', 'Balcony', 'CCTV', 'Gym', 'Pet Friendly',
  ];

  // ── Property-level controllers ────────────────────────────────────────────
  late TextEditingController titleCtrl;
  late TextEditingController locationCtrl;
  late TextEditingController descCtrl;

  // Category
  String? _selectedCategory;

  // Rental terms controllers
  late TextEditingController _minStayCtrl;
  late TextEditingController _depositCtrl;
  late TextEditingController _advanceMonthsCtrl;

  // Multi-select sets
  final Set<String> _selectedRules      = {};
  final Set<String> _selectedAmenities  = {};

  // Property availability
  bool _isActive = true;

  // ── Photos ────────────────────────────────────────────────────────────────
  List<String> _existingImageUrls = [];   // URLs already in Firestore
  List<File>   _newImageFiles     = [];   // Locally picked, not yet uploaded
  int          _coverIndex        = 0;    // Index into the COMBINED list
  // Combined list helpers — index 0..(existing-1) are network, rest are local
  int get _totalPhotoCount => _existingImageUrls.length + _newImageFiles.length;
  bool _isExistingIndex(int i) => i < _existingImageUrls.length;

  // ── Map ───────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  LatLng? _selectedLatLng;
  static const _fallbackPosition = CameraPosition(
    target: LatLng(15.9750, 120.5710), zoom: 14,
  );

  // ── Rooms ─────────────────────────────────────────────────────────────────
  // Rooms are prefetched in initState to avoid a StreamBuilder rebuild loop.
  List<_EditableRoom> _rooms = [];
  // Parallel controller lists — index mirrors _rooms (including removed)
  final List<TextEditingController> _priceCtrlList    = [];
  final List<TextEditingController> _unitsCtrlList    = [];
  final List<TextEditingController> _occupantsCtrlList = [];

  bool _roomsLoaded = false;

  // ── Misc ──────────────────────────────────────────────────────────────────
  bool _loading = false;
  final _picker = ImagePicker();

  // ════════════════════════════════════════════════════════════════════════
  //  initState — populate all fields from passed property data + fetch rooms
  // ════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _initPropertyFields();
    _prefetchRooms();
  }

  /// Reads widget.data (the property document snapshot) and populates all
  /// property-level controllers and state variables.
  void _initPropertyFields() {
    final d = widget.data;

    // Basic info
    titleCtrl    = TextEditingController(text: d['name'] ?? '');
    locationCtrl = TextEditingController(text: d['location'] ?? '');
    descCtrl     = TextEditingController(text: d['description'] ?? '');

    // Category
    _selectedCategory = d['category'];

    // Rental terms — nested map; use safe fallbacks for older documents
    final terms = (d['rentalTerms'] as Map<String, dynamic>?) ?? {};
    _minStayCtrl       = TextEditingController(text: (terms['minimumStayMonths']    ?? 1).toString());
    _depositCtrl       = TextEditingController(text: (terms['securityDepositAmount'] ?? 0).toString());
    _advanceMonthsCtrl = TextEditingController(text: (terms['advanceMonthsRequired']  ?? 1).toString());

    // House rules
    _selectedRules.addAll(List<String>.from(d['houseRules'] ?? []));

    // Amenities
    _selectedAmenities.addAll(List<String>.from(d['amenities'] ?? []));

    // Property availability
    _isActive = d['isActive'] ?? true;

    // Images — support both old 'images' key and new 'imageUrls' key
    _existingImageUrls = List<String>.from(d['imageUrls'] ?? d['images'] ?? []);

    // Cover index — find the existing coverImageUrl in the list
    final coverUrl = d['coverImageUrl'] as String?;
    if (coverUrl != null && _existingImageUrls.isNotEmpty) {
      final idx = _existingImageUrls.indexOf(coverUrl);
      _coverIndex = idx >= 0 ? idx : 0;
    }

    // Coordinates
    if (d['coordinates'] != null) {
      final geo = d['coordinates'] as GeoPoint;
      _selectedLatLng = LatLng(geo.latitude, geo.longitude);
    }
  }

  /// Fetches the rooms subcollection once on screen load.
  /// We use a one-time get() instead of a stream so that:
  ///  • The list doesn't jump while the user is editing
  ///  • We can track local mutation state (_RoomState) freely
  Future<void> _prefetchRooms() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.docId)
          .collection('rooms')
          .orderBy('createdAt')
          .get();

      final loaded = snapshot.docs
          .map((doc) => _EditableRoom.fromFirestore(doc))
          .toList();

      // Build parallel controller lists
      for (final room in loaded) {
        _priceCtrlList.add(TextEditingController(text: room.priceMonthly));
        _unitsCtrlList.add(TextEditingController(text: room.availableUnits));
        _occupantsCtrlList.add(TextEditingController(text: room.maxOccupants));
      }

      // Guarantee at least one editable row
      if (loaded.isEmpty) _appendNewRoomRow();

      setState(() {
        _rooms = loaded;
        _roomsLoaded = true;
      });
    } catch (e) {
      // If fetch fails, still show screen with one empty room row
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
    _depositCtrl.dispose();
    _advanceMonthsCtrl.dispose();
    for (final c in _priceCtrlList)     c.dispose();
    for (final c in _unitsCtrlList)     c.dispose();
    for (final c in _occupantsCtrlList) c.dispose();
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
  }

  void _addRoomOffer() => setState(_appendNewRoomRow);

  /// Mark a room as removed instead of splicing the list.
  /// This preserves index alignment with the controller lists.
  /// Rooms with a docId that are marked removed will be batch-deleted on save.
  void _markRoomRemoved(int index) {
    final visibleCount = _rooms.where((r) => r.isVisible).length;
    if (visibleCount <= 1) return; // always keep at least one visible row
    setState(() => _rooms[index].state = _RoomState.removed);
  }

  /// Sync text controller values → model before validation or save.
  void _syncRoomControllers() {
    for (int i = 0; i < _rooms.length; i++) {
      _rooms[i].priceMonthly   = _priceCtrlList[i].text;
      _rooms[i].availableUnits = _unitsCtrlList[i].text;
      _rooms[i].maxOccupants   = _occupantsCtrlList[i].text;
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
      // Shift cover index if needed
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
  //  UPDATE — property doc update + room subcollection batch write
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _updateApartment() async {
    // Step 0: sync controllers → models
    _syncRoomControllers();
    final int    minStay     = int.tryParse(_minStayCtrl.text)       ?? 1;
    final double deposit     = double.tryParse(_depositCtrl.text)    ?? 0.0;
    final int    advMonths   = int.tryParse(_advanceMonthsCtrl.text) ?? 1;

    // Rooms that will actually be saved (not removed, and valid)
    final activeRooms = _rooms
        .where((r) => r.state != _RoomState.removed && r.isValid)
        .toList();

    // Validation
    if (titleCtrl.text.isEmpty    ||
        locationCtrl.text.isEmpty ||
        _selectedCategory == null ||
        _selectedLatLng == null   ||
        activeRooms.isEmpty) {
      _showSnack(
        activeRooms.isEmpty
            ? "Add at least one valid room offer"
            : "Fill all required fields, select category, and pin location",
        isError: true,
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // ── Step 1: Upload new images ─────────────────────────────────────
      final List<String> newlyUploadedUrls = [];
      for (final img in _newImageFiles) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('apartments')
            .child('${widget.docId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        final task = await ref.putFile(img);
        newlyUploadedUrls.add(await task.ref.getDownloadURL());
      }

      // Final image list = kept existing + newly uploaded
      final List<String> finalImageUrls = [
        ..._existingImageUrls,
        ...newlyUploadedUrls,
      ];

      // Resolve cover URL from combined index
      String coverImageUrl = '';
      if (finalImageUrls.isNotEmpty) {
        final safeIndex = _coverIndex.clamp(0, finalImageUrls.length - 1);
        coverImageUrl = finalImageUrls[safeIndex];
      }

      // ── Step 2: Recalculate minPrice from active valid rooms ──────────
      // minPrice is a convenience field only — never the source of truth.
      // The real prices live in the rooms subcollection.
      final double minPrice = activeRooms
          .map((r) => double.tryParse(r.priceMonthly.trim()) ?? 0.0)
          .reduce((a, b) => a < b ? a : b);

      // ── Step 3: Update the property-level document ────────────────────
      final propertyRef = FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.docId);

      await propertyRef.update({
        'name':         titleCtrl.text.trim(),
        'location':     locationCtrl.text.trim(),
        'description':  descCtrl.text.trim(),
        'category':     _selectedCategory,
        'rentalTerms': {
          'minimumStayMonths':     minStay,
          'securityDepositAmount': deposit,
          'advanceMonthsRequired': advMonths,
        },
        'houseRules':   _selectedRules.toList(),
        'amenities':    _selectedAmenities.toList(),
        'imageUrls':    finalImageUrls,
        'coverImageUrl': coverImageUrl,
        'isActive':     _isActive,
        'coordinates':  GeoPoint(
          _selectedLatLng!.latitude,
          _selectedLatLng!.longitude,
        ),
        // Recalculated convenience field
        'minPrice':     minPrice,
        // updatedAt helps clients invalidate cached property data
        'updatedAt':    Timestamp.now(),
      });

      // ── Step 4: Batch-write room subcollection changes ────────────────
      //
      //  Three distinct operations in one atomic batch:
      //    UPDATE — rooms that existed before and are still active
      //    DELETE — rooms the landlord removed from the list
      //    SET    — brand-new rooms added during this edit session
      //
      //  ⚠️  BOOKING SAFETY RULE:
      //    We NEVER delete rooms that have existing booking documents.
      //    Deletion is safe here ONLY because the booking feature is not yet
      //    implemented. When bookings are added, replace batch.delete() with
      //    a soft-delete: batch.update(ref, {'isActive': false}).
      //    This preserves the room document and all its booking sub-documents.

      final batch        = FirebaseFirestore.instance.batch();
      final roomsColRef  = propertyRef.collection('rooms');

      for (final room in _rooms) {
        switch (room.state) {

          case _RoomState.existing:
            // Room was pre-loaded and not marked removed — update it in place.
            // We keep the same docId so any future booking references stay valid.
            final ref = roomsColRef.doc(room.docId!);
            batch.update(ref, room.toFirestoreMap());
            break;

          case _RoomState.removed:
            // Room was explicitly removed by the landlord.
            // Safe to delete now (no bookings yet). See booking safety note above.
            if (room.docId != null) {
              final ref = roomsColRef.doc(room.docId!);
              batch.delete(ref);
            }
            // If docId is null the room was never saved — just skip it.
            break;

          case _RoomState.added:
            // Brand-new room — only write if it passed validation.
            if (room.isValid) {
              final ref = roomsColRef.doc(); // auto-generated ID
              batch.set(ref, {
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
              "Applies to all rooms in this property.",
              style: TextStyle(fontSize: 12.5, color: _textMid, height: 1.5),
            ),
            const SizedBox(height: 10),
            _card(child: _rentalTermsSection()),
            const SizedBox(height: 24),

            _sectionLabel("House Rules"),
            const SizedBox(height: 10),
            _card(child: _houseRulesSection()),
            const SizedBox(height: 24),

            _sectionLabel("Availability"),
            const SizedBox(height: 10),
            _card(child: _availabilitySection()),
            const SizedBox(height: 24),

            _sectionLabel("Room Offers"),
            const SizedBox(height: 4),
            const Text(
              "Edit, add, or remove room types. Removed rooms will be deleted from the subcollection.",
              style: TextStyle(fontSize: 12.5, color: _textMid, height: 1.5),
            ),
            const SizedBox(height: 10),
            _roomsLoaded ? _roomOffersSection() : _roomsLoadingPlaceholder(),
            const SizedBox(height: 24),

            _sectionLabel("Update Location"),
            const SizedBox(height: 10),
            _card(child: _mapSection()),
            const SizedBox(height: 24),

            _sectionLabel("Amenities"),
            const SizedBox(height: 10),
            _card(child: _amenitiesSection()),
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
      backgroundColor: _bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
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
        "Edit Listing",
        style: TextStyle(color: _textDark, fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.3),
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
          onPressed: _loading ? null : _updateApartment,
          child: _loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_rounded, size: 18),
                    SizedBox(width: 8),
                    Text("Save Changes",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
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
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textLight, letterSpacing: 1.4),
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
    TextInputFormatter? formatter,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: [if (formatter != null) formatter],
      maxLines: maxLines,
      style: const TextStyle(color: _textDark, fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textLight, fontSize: 15),
        prefixText: prefix,
        prefixStyle: const TextStyle(color: _orange, fontWeight: FontWeight.w600, fontSize: 15),
        prefixIcon: icon != null ? Icon(icon, color: _textLight, size: 20) : null,
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
  //  SECTION: CATEGORY
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
        _input(
          hint: "Security deposit amount",
          ctrl: _depositCtrl,
          icon: Icons.shield_outlined,
          prefix: "₱ ",
          isNumber: true,
          formatter: FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _rentalTermTile(
                label: "Min. Stay",
                sublabel: "months",
                ctrl: _minStayCtrl,
                icon: Icons.calendar_month_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _rentalTermTile(
                label: "Advance",
                sublabel: "months required",
                ctrl: _advanceMonthsCtrl,
                icon: Icons.payments_outlined,
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
                Text(rule, style: TextStyle(
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
  //  SECTION: AVAILABILITY TOGGLE
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
  //  SECTION: ROOM OFFERS
  // ════════════════════════════════════════════════════════════════════════

  Widget _roomsLoadingPlaceholder() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: _orange, strokeWidth: 2.5),
      ),
    );
  }

  Widget _roomOffersSection() {
    // Only show rows that are not marked removed
    final visibleRooms = _rooms
        .asMap()
        .entries
        .where((e) => e.value.isVisible)
        .toList();

    return Column(
      children: [
        ...visibleRooms.map((e) => _roomOfferCard(e.key)),
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
                Text("Add Another Room Type",
                    style: TextStyle(color: _orange, fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _roomOfferCard(int index) {
    final room      = _rooms[index];
    final isNew     = room.state == _RoomState.added;
    final canRemove = _rooms.where((r) => r.isVisible).length > 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            // New rows get a subtle orange tint border to distinguish them
            color: isNew ? _orange.withOpacity(.35) : _border,
            width: 1,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Card header ─────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: _orangeLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.door_front_door_outlined, color: _orange, size: 16),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Room Offer ${index + 1}",
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _textDark),
                    ),
                    if (isNew)
                      const Text("New", style: TextStyle(fontSize: 10, color: _orange, fontWeight: FontWeight.w600))
                    else
                      const Text("Existing", style: TextStyle(fontSize: 10, color: _textLight)),
                  ],
                ),
                const Spacer(),
                // isAvailable toggle
                Row(
                  children: [
                    Text(
                      room.isAvailable ? "Available" : "Unavailable",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: room.isAvailable ? const Color(0xFF059669) : _textLight,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch.adaptive(
                        value: room.isAvailable,
                        onChanged: (v) => setState(() => _rooms[index].isAvailable = v),
                        activeColor: _orange,
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
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 16),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 14),

            // ── Room type dropdown ──────────────────────────────────────
            _inlineDropdown<String>(
              value: room.roomType.isEmpty ? null : room.roomType,
              items: _roomTypes,
              hint: "Room type",
              onChanged: (val) => setState(() => _rooms[index].roomType = val ?? ''),
            ),

            const SizedBox(height: 10),

            // ── Price + Units ───────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _numberField(
                    ctrl: _priceCtrlList[index],
                    hint: "Price / month",
                    prefix: "₱ ",
                    icon: Icons.payments_outlined,
                    onChanged: (v) => _rooms[index].priceMonthly = v,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: _numberField(
                    ctrl: _unitsCtrlList[index],
                    hint: "Units",
                    icon: Icons.meeting_room_outlined,
                    onChanged: (v) => _rooms[index].availableUnits = v,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Max Occupants + Gender ──────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _numberField(
                    ctrl: _occupantsCtrlList[index],
                    hint: "Max occupants",
                    icon: Icons.group_outlined,
                    onChanged: (v) => _rooms[index].maxOccupants = v,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: _inlineDropdown<String>(
                    value: room.genderRestriction,
                    items: _genderOptions,
                    hint: "Gender",
                    onChanged: (val) => setState(() =>
                        _rooms[index].genderRestriction = val ?? 'open'),
                    labelBuilder: (g) => _genderLabels[g] ?? g,
                  ),
                ),
              ],
            ),

            // ── Summary chip ────────────────────────────────────────────
            if (room.isValid) ...[
              const SizedBox(height: 10),
              _roomSummaryChip(room),
            ],
          ],
        ),
      ),
    );
  }

  Widget _roomSummaryChip(_EditableRoom room) {
    final gLabel = room.genderRestriction == 'open'
        ? 'Any gender'
        : _genderLabels[room.genderRestriction] ?? room.genderRestriction;

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
              "${room.roomType}  ·  ₱${room.priceMonthly}/mo  ·  "
              "${room.availableUnits} unit${int.tryParse(room.availableUnits) == 1 ? '' : 's'}  ·  "
              "Max ${room.maxOccupants}  ·  $gLabel",
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
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
              decoration: BoxDecoration(color: _orangeLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.location_on_rounded, color: _orange, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Update Pin", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
                Text("Tap to move the pin", style: TextStyle(fontSize: 12, color: _textLight)),
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
                        markerId: const MarkerId("selected"),
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
  //  SECTION: AMENITIES
  // ════════════════════════════════════════════════════════════════════════

  Widget _amenitiesSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _amenitiesList.map((e) {
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
  //  SECTION: PHOTOS
  // ════════════════════════════════════════════════════════════════════════

  Widget _photosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Header ────────────────────────────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _orangeLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.photo_library_rounded, color: _orange, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Listing Photos",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
                Text(
                  "$_totalPhotoCount photo${_totalPhotoCount != 1 ? 's' : ''}  ·  Tap to set cover",
                  style: const TextStyle(fontSize: 12, color: _textLight),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Photo grid (existing network + new local) ─────────────────
        if (_totalPhotoCount > 0) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Existing (network) images
              ...List.generate(_existingImageUrls.length, (i) {
                final globalIndex  = i;
                final isCover      = globalIndex == _coverIndex;
                return _photoTileNetwork(
                  url: _existingImageUrls[i],
                  isCover: isCover,
                  onSetCover: () => setState(() => _coverIndex = globalIndex),
                  onRemove: () => _removeExistingImage(i),
                );
              }),
              // New (local) images
              ...List.generate(_newImageFiles.length, (i) {
                final globalIndex = _existingImageUrls.length + i;
                final isCover     = globalIndex == _coverIndex;
                return _photoTileFile(
                  file: _newImageFiles[i],
                  isCover: isCover,
                  onSetCover: () => setState(() => _coverIndex = globalIndex),
                  onRemove: () => _removeNewImage(i),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── Add more photos button ─────────────────────────────────────
        GestureDetector(
          onTap: _pickNewImages,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: _orangeLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _orange.withOpacity(.35), width: 1.2),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_rounded, color: _orange, size: 20),
                SizedBox(width: 8),
                Text("Add More Photos",
                    style: TextStyle(color: _orange, fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoTileNetwork({
    required String url,
    required bool isCover,
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
              border: Border.all(color: isCover ? _orange : Colors.transparent, width: 2.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(url, width: 90, height: 90, fit: BoxFit.cover),
            ),
          ),
          // Cover badge
          if (isCover)
            Positioned(
              bottom: 6, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(6)),
                child: const Text("Cover",
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
          // Remove button
          Positioned(
            top: 5, right: 5,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.black.withOpacity(.55), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoTileFile({
    required File file,
    required bool isCover,
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
              border: Border.all(color: isCover ? _orange : Colors.transparent, width: 2.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(file, width: 90, height: 90, fit: BoxFit.cover),
            ),
          ),
          // Cover badge
          if (isCover)
            Positioned(
              bottom: 6, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(6)),
                child: const Text("Cover",
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
          // NEW badge (only when not cover)
          if (!isCover)
            Positioned(
              top: 5, left: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _textDark, borderRadius: BorderRadius.circular(6)),
                child: const Text("NEW",
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
            ),
          // Remove button
          Positioned(
            top: 5, right: 5,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.black.withOpacity(.55), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}