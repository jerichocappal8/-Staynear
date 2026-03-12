import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../booking/checkout_screen.dart';
import '../../models/apartment_model.dart';
import '../../models/room_offer.dart';
import '../../models/rental_terms.dart';
import '../../models/nearby_facility.dart';
import '../../models/testimonial.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  CONSTANTS
// ══════════════════════════════════════════════════════════════════════════════
const Color _successGreen = Color(0xFF22C55E);
const Color _errorRed = Color(0xFFEF4444);
// ══════════════════════════════════════════════════════════════════════════════
//  MODELS
// ══════════════════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════════════════
//  PAGE
// ══════════════════════════════════════════════════════════════════════════════

class ApartmentDetailPage extends StatefulWidget {
  final String apartmentId;
  const ApartmentDetailPage({Key? key, required this.apartmentId}) : super(key: key);

  @override
  State<ApartmentDetailPage> createState() => _ApartmentDetailPageState();
}

class _ApartmentDetailPageState extends State<ApartmentDetailPage> {
  final PageController _pageController = PageController();
  int  _currentImageIndex = 0;
  bool _isFavorite        = false;

  String  hostName           = '';
  String  hostPhoto          = '';
  String hostPhone = '';
  String? _lastLoadedOwnerId;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _loadHost(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('host_requests')
        .doc(uid)
        .get();

    if (!doc.exists || !mounted) return;

    final data = doc.data()!;

    setState(() {
      hostName  = data['fullName'] ?? 'Host';
      hostPhoto = data['photo'] ?? '';
      hostPhone = data['phone'] ?? ''; // ✅ ADD THIS
    });
  }
Future<void> _callHost() async {
  if (hostPhone.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phone number not available')),
    );
    return;
  }

  final Uri uri = Uri(
    scheme: 'tel',
    path: hostPhone,
  );

  final bool launched = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );

  if (!launched) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open phone dialer')),
    );
  }
}

  String _fmt(double p) => p
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

void _showRoomSelectionSheet(
  BuildContext context,
  ApartmentModel apt,
  List<RoomOffer> rooms,
) {
  final available =
      rooms.where((r) =>
  r.isAvailable && (int.tryParse(r.availableUnits) ?? 0) > 0
).toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RoomSelectionSheet(
      apt: apt,
      rooms: available,
      onConfirm: (room) {
        // close the modal sheet first
        Navigator.pop(context);

        // open checkout screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutScreen(
              apartment: apt,
              room: room,
            ),
          ),
        );
      },
    ),
  );
}

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('properties').doc(widget.apartmentId).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)));
        }
        if (snap.hasError || !snap.hasData || !snap.data!.exists) {
          return const Scaffold(body: Center(child: Text('Property not found.')));
        }

        final apt = ApartmentModel.fromFirestore(snap.data!);
        if (_lastLoadedOwnerId != apt.ownerId) {
          _lastLoadedOwnerId = apt.ownerId;
          _loadHost(apt.ownerId);
        }

        // ── Rooms subcollection StreamBuilder ─────────────────────────────
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('properties')
              .doc(widget.apartmentId)
              .collection('rooms')
              .snapshots(),
          builder: (context, roomSnap) {
            final rooms = roomSnap.hasData
    ? roomSnap.data!.docs.map((doc) =>
        RoomOffer.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)
      ).toList()
    : <RoomOffer>[];
            final roomsLoading = !roomSnap.hasData;

            return Scaffold(
              backgroundColor: AppColors.background(context),
              bottomNavigationBar: _BottomBar(
                apt:    apt,
                rooms:  rooms,
                fmt:    _fmt,
                onRent: () => _showRoomSelectionSheet(context, apt, rooms),
              ),
              body: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Gallery ────────────────────────────────────
                        _ImageGallery(
                        images: apt.images,
                        controller: _pageController,
                        onBack: () => Navigator.pop(context),
                        ),

                        // ── View Photos ────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: _ViewPhotosButton(primaryOrange: AppColors.primaryOrange,images: apt.images,),
                        ),

                        // ── Title + category + favourite ───────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(apt.name,
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    if (apt.category.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      _CategoryBadge(label: apt.category),
                                    ],
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _isFavorite = !_isFavorite),
                                child: Icon(
                                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: _isFavorite ? Colors.red : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ── Rating ─────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(children: [
                            Icon(Icons.star, color: AppColors.primaryOrange, size: 16),
                            const SizedBox(width: 4),
                            Text('${apt.rating} (${apt.reviewCount} reviews)',
                                style: TextStyle(fontSize: 13)),
                          ]),
                        ),

                        const SizedBox(height: 6),

                        // ── Address ────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(children: [
                            Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(child: Text(apt.address,
                                style: TextStyle(fontSize: 12, color: Colors.grey))),
                          ]),
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // ── Owner row ──────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _OwnerRow(apt: apt, name: hostName, photo: hostPhoto, onCall: _callHost, onChat: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Chat feature coming soon!'),
                              backgroundColor: AppColors.primaryOrange,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                            ));
                          }
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // ── Available Rooms ────────────────────────────
                        _RoomsSection(
                          rooms:     rooms,
                          isLoading: roomsLoading,
                          fmt:       _fmt,
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // ── Rental Terms ───────────────────────────────
                        _RentalTermsSection(terms: apt.rentalTerms, fmt: _fmt),

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // ── Facilities ─────────────────────────────────
                        _FacilitiesSection(
                            facilities: apt.facilities, primaryOrange: AppColors.primaryOrange),

                        const SizedBox(height: 16),

                        // ── Map ────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _MapPreview(lat: apt.lat, lng: apt.lng, name: apt.name),
                        ),

                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // ── Nearby facilities ──────────────────────────
                        if (apt.nearbyFacilities.isNotEmpty)
                          _NearbyFacilitiesSection(nearbyFacilities: apt.nearbyFacilities),

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // ── About ──────────────────────────────────────
                        _AboutSection(description: apt.description),

                        // ── House Rules ────────────────────────────────
                        if (apt.houseRules.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          _HouseRulesSection(rules: apt.houseRules),
                        ],

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // ── Testimonials ───────────────────────────────
                        if (apt.testimonials.isNotEmpty)
                          _TestimonialsSection(testimonials: apt.testimonials),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  NEW — AVAILABLE ROOMS SECTION
// ══════════════════════════════════════════════════════════════════════════════

class _RoomsSection extends StatelessWidget {
  final List<RoomOffer> rooms;
  final bool isLoading;
  final String Function(double) fmt;

  const _RoomsSection({required this.rooms, required this.isLoading, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Available Rooms',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (!isLoading && rooms.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.orangeLight, borderRadius: BorderRadius.circular(20)),
                  child: Text('${rooms.length} type${rooms.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.primaryOrange, fontWeight: FontWeight.w600)),
                ),
            ],
          ),

          const SizedBox(height: 14),

          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: AppColors.primaryOrange, strokeWidth: 2),
              ),
            )
          else if (rooms.isEmpty)
            _EmptyRoomsState()
          else
            ...rooms.map((r) => _RoomTile(room: r, fmt: fmt)),
        ],
      ),
    );
  }
}

class _EmptyRoomsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.background(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: const [
          Icon(Icons.meeting_room_outlined, size: 36, color: AppColors.textLight),
          SizedBox(height: 8),
          Text('No rooms listed yet',
              style: TextStyle(color: AppColors.textMid, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('Check back later or contact the host',
              style: TextStyle(color: AppColors.textLight, fontSize: 12)),
        ]),
      );
}

class _RoomTile extends StatelessWidget {
  final RoomOffer room;
  final String Function(double) fmt;
  const _RoomTile({required this.room, required this.fmt});

  static const _typeIcons = <String, IconData>{
    'Studio':      Icons.single_bed_rounded,
    '1 Bedroom':   Icons.bed_rounded,
    '2 Bedroom':   Icons.bedroom_parent_rounded,
    'Bed Space':   Icons.airline_seat_individual_suite_rounded,
    'Entire Unit': Icons.home_rounded,
  };
  static const _genderColors = {
    'Male':   Color(0xFF3B82F6),
    'Female': Color(0xFFEC4899),
    'Any':    AppColors.textMid,
  };
  static const _genderIcons = {
    'Male':   Icons.male_rounded,
    'Female': Icons.female_rounded,
    'Any':    Icons.people_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final available =
    room.isAvailable && (int.tryParse(room.availableUnits) ?? 0) > 0;
    final icon        = _typeIcons[room.roomType]    ?? Icons.meeting_room_outlined;
    final gColor      = _genderColors[room.genderRestriction] ?? AppColors.textMid;
    final gIcon       = _genderIcons[room.genderRestriction]  ?? Icons.people_outline_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(.04), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: available ? AppColors.orangeLight : AppColors.background(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: available ? AppColors.primaryOrange : AppColors.textLight, size: 22),
          ),

          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
  children: [
    Expanded(
      child: Text(
        room.roomType,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: AppColors.text(context),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    ),
    const SizedBox(width: 8),
    _AvailabilityBadge(
      available: available,
      units: int.tryParse(room.availableUnits) ?? 0,
    ),
  ],
),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _MetaChip(
                      icon: Icons.people_outline_rounded,
                      label: 'Max ${room.maxOccupants} pax',
                      color: AppColors.textMid),
                  _MetaChip(icon: gIcon, label: room.genderRestriction, color: gColor),
                ]),
              ],
            ),
          ),

          const SizedBox(width: 8),

// Price + Fees
Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  mainAxisSize: MainAxisSize.min,
  children: [

    // Price
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '₱${fmt(room.activePrice)}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: AppColors.primaryOrange,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          room.pricingMode == 'daily' ? '/day' : '/mo',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMid,
          ),
        ),
      ],
    ),

    // Service Fee
    if ((double.tryParse(room.serviceFee) ?? 0) > 0) ...[
      const SizedBox(height: 2),
      Text(
        '+ ₱${fmt(double.parse(room.serviceFee))} service fee',
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textLight,
        ),
      ),
    ],

    // Security Deposit
    if ((double.tryParse(room.securityDeposit) ?? 0) > 0) ...[
      const SizedBox(height: 2),
      Text(
        '₱${fmt(double.parse(room.securityDeposit))} deposit',
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textLight,
        ),
      ),
    ],

  ],
),
        ],
      ),
    );
  }
}
class _AvailabilityBadge extends StatelessWidget {
  final bool available;
  final int units;

  const _AvailabilityBadge({
    required this.available,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: available
            ? const Color(0xFF22C55E).withOpacity(.12)
            : const Color(0xFFEF4444).withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: available
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            available
                ? '$units unit${units == 1 ? '' : 's'} left'
                : 'Full',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: available
                  ? const Color(0xFF059669)
                  : const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(.08), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ]),
      );
}

class _CategoryBadge extends StatelessWidget {
  final String label;
  const _CategoryBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: AppColors.orangeLight, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5, color: AppColors.primaryOrange, fontWeight: FontWeight.w600)),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  NEW — RENTAL TERMS SECTION
// ══════════════════════════════════════════════════════════════════════════════

class _RentalTermsSection extends StatelessWidget {
  final RentalTerms terms;
  final String Function(double) fmt;
  const _RentalTermsSection({required this.terms, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rental Terms',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              _TermRow(
                icon:  Icons.calendar_month_outlined,
                label: 'Minimum Stay',
                value: '${terms.minimumStayMonths} month${terms.minimumStayMonths == 1 ? '' : 's'}',
              ),
              Divider(height: 1, color: AppColors.border),
              _TermRow(
                icon:  Icons.payments_outlined,
                label: 'Advance Payment',
                value: '${terms.advanceMonthsRequired} month${terms.advanceMonthsRequired == 1 ? '' : 's'} advance',
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _TermRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _TermRow(
      {required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.primaryOrange),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13.5, color: AppColors.textMid))),
          Text(value,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.text(context))),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  NEW — HOUSE RULES SECTION
// ══════════════════════════════════════════════════════════════════════════════

class _HouseRulesSection extends StatelessWidget {
  final List<String> rules;
  const _HouseRulesSection({required this.rules});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('House Rules',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rules.map((rule) => _RuleChip(label: rule)).toList(),
            ),
          ],
        ),
      );
}

class _RuleChip extends StatelessWidget {
  final String label;
  const _RuleChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 14, color: AppColors.primaryOrange),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5, color: AppColors.text(context), fontWeight: FontWeight.w500)),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  NEW — ROOM SELECTION MODAL SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _RoomSelectionSheet extends StatefulWidget {
  final ApartmentModel apt;
  final List<RoomOffer> rooms;
  final ValueChanged<RoomOffer> onConfirm;

  const _RoomSelectionSheet(
      {required this.apt, required this.rooms, required this.onConfirm});

  @override
  State<_RoomSelectionSheet> createState() => _RoomSelectionSheetState();
}

class _RoomSelectionSheetState extends State<_RoomSelectionSheet> {
  RoomOffer? _selected;

  String _fmt(double p) => p
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          Text('Select a Room',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text(context))),
          const SizedBox(height: 4),
          Text(
            'Choose the room type you\'d like to rent at ${widget.apt.name}',
            style: TextStyle(fontSize: 13, color: AppColors.textMid),
          ),

          const SizedBox(height: 16),

          // No rooms available
          if (widget.rooms.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(children: const [
                  Icon(Icons.do_not_disturb_on_outlined, size: 40, color: AppColors.textLight),
                  SizedBox(height: 8),
                  Text('No rooms available right now',
                      style:
                          TextStyle(color: AppColors.textMid, fontWeight: FontWeight.w500)),
                ]),
              ),
            )
          else
            ...widget.rooms.map((room) {
              final sel = _selected?.id == room.id;
              return GestureDetector(
                onTap: () => setState(() => _selected = room),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.orangeLight : AppColors.background(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: sel ? AppColors.primaryOrange : AppColors.border,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Row(children: [
                    // Radio indicator
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sel ? AppColors.primaryOrange : Colors.transparent,
                        border: Border.all(
                            color: sel ? AppColors.primaryOrange : AppColors.textLight, width: 1.5),
                      ),
                      child: sel
                          ? Icon(Icons.check_rounded, size: 14, color: Colors.white)
                          : null,
                    ),

                    const SizedBox(width: 12),

                    // Info
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(room.roomType,
                            style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14,
                              color: sel ? AppColors.primaryOrange : AppColors.text(context),
                            )),
                        const SizedBox(height: 2),
                        Text(
                          '${room.availableUnits} unit${room.availableUnits == 1 ? '' : 's'} · '
                          'max ${room.maxOccupants} pax · ${room.genderRestriction}',
                          style: TextStyle(fontSize: 12, color: AppColors.textMid),
                        ),
                      ]),
                    ),

// Price + Service Fee
// Price + Fees
Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  mainAxisSize: MainAxisSize.min,
  children: [

    // Price
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '₱${_fmt(room.activePrice)}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: sel ? AppColors.primaryOrange : AppColors.text(context),
          ),
        ),
        const SizedBox(width: 2),
        Text(
          room.pricingMode == 'daily' ? '/day' : '/mo',
          style: TextStyle(
            fontSize: 11,
            color: sel ? AppColors.primaryOrange : AppColors.textMid,
          ),
        ),
      ],
    ),

    // Service Fee
    if ((double.tryParse(room.serviceFee) ?? 0) > 0) ...[
      const SizedBox(height: 2),
      Text(
        '+ ₱${_fmt(double.parse(room.serviceFee))} service fee',
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textLight,
        ),
      ),
    ],

    // Security Deposit
    if ((double.tryParse(room.securityDeposit) ?? 0) > 0) ...[
      const SizedBox(height: 2),
      Text(
        '₱${_fmt(double.parse(room.securityDeposit))} refundable deposit',
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textLight,
        ),
      ),
    ],

  ],
)
                  ]),
                ),
              );
            }),

          const SizedBox(height: 8),

          // Confirm
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: _selected == null ? null : () => widget.onConfirm(_selected!),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _selected == null ? 'Select a room to continue' : 'Proceed to Book',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  UPDATED — BOTTOM BAR
// ══════════════════════════════════════════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  final ApartmentModel apt;
  final List<RoomOffer> rooms;
  final String Function(double) fmt;
  final VoidCallback onRent;

  const _BottomBar({
    required this.apt,
    required this.rooms,
    required this.fmt,
    required this.onRent,
  });

  @override
  Widget build(BuildContext context) {

    // Filter available rooms
    final available = rooms.where((r) {
      final units = int.tryParse(r.availableUnits) ?? 0;
      return r.isAvailable && units > 0;
    }).toList();

    // Get lowest room price
RoomOffer? cheapestRoom;

if (available.isNotEmpty) {
  cheapestRoom = available.reduce(
    (a, b) => a.activePrice < b.activePrice ? a : b,
  );
}

final displayPrice =
    cheapestRoom != null ? cheapestRoom.activePrice : apt.minPrice;

    final hasRooms = available.isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        boxShadow: [
          BoxShadow(
              blurRadius: 10,
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(0, -2))
        ],
      ),
      child: Row(children: [
        // From price
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'from ₱${fmt(displayPrice)}',
              style: TextStyle(
                  color: AppColors.primaryOrange, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
  cheapestRoom?.pricingMode == 'daily'
      ? '/day'
      : '/month',
  style: const TextStyle(
    fontSize: 11,
    color: AppColors.textLight,
  ),
)
          ],
        ),

        const SizedBox(width: 16),

        Expanded(
          child: ElevatedButton(
            onPressed: hasRooms ? onRent : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: Text(
              hasRooms ? 'Rent' : 'Unavailable',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SUB-WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

// ── UPDATED: play button overlay removed ──────────────────────────────────────
class _ImageGallery extends StatefulWidget {
  final List<String> images;
  final PageController controller;
  final VoidCallback onBack;

  const _ImageGallery({
    required this.images,
    required this.controller,
    required this.onBack,
  });

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 240,
          child: widget.images.isEmpty
              ? Container(
                  color: Colors.grey[200],
                  child: Icon(Icons.image, size: 80, color: Colors.grey),
                )
              : PageView.builder(
                  controller: widget.controller,
                  onPageChanged: (i) {
                    setState(() {
                      _currentIndex = i;
                    });
                  },
                  itemCount: widget.images.length,
                  itemBuilder: (_, i) => Image.network(
                    widget.images[i],
                    fit: BoxFit.cover,
                  ),
                ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: widget.onBack,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.chevron_left),
              ),
            ),
          ),
        ),

        if (widget.images.isNotEmpty)
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentIndex + 1}/${widget.images.length}',
                style: TextStyle(color: AppColors.card(context), fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}

// ── UPDATED: replaces _Watch360Button ────────────────────────────────────────
class _ViewPhotosButton extends StatelessWidget {
  final Color primaryOrange;
  final List<String> images;

  const _ViewPhotosButton({
    required this.primaryOrange,
    required this.images,
  });

@override
Widget build(BuildContext context) => OutlinedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenGalleryPage(images: images),
      ),
    );
  },
  icon: Icon(Icons.photo_library_outlined, color: primaryOrange, size: 18),
  label: Text(
    'View Photos',
    style: TextStyle(
      color: primaryOrange,
      fontWeight: FontWeight.w600,
    ),
  ),
  style: OutlinedButton.styleFrom(
    side: BorderSide(color: primaryOrange),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    ),
    minimumSize: const Size(double.infinity, 48),
  ),
);
}

class _OwnerRow extends StatelessWidget {
  final ApartmentModel apt;
  final String name;
  final String photo;
  final VoidCallback onCall;
  final VoidCallback onChat;

  const _OwnerRow({
    required this.apt,
    required this.name,
    required this.photo,
    required this.onCall,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 22,
        backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
        child: photo.isEmpty ? Icon(Icons.person) : null,
      ),
      const SizedBox(width: 10),
      Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        name.isNotEmpty ? name : 'Host',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 2),
      const Text(
        'Property Owner',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    ],
  ),
),
      IconButton(
        onPressed: onChat,
        icon: Icon(Icons.chat_bubble_outline),
      ),
      const SizedBox(width: 8),
      IconButton(
        onPressed: onCall,
        icon: Icon(Icons.phone_outlined),
      ),
    ],
  );
}

class _FacilitiesSection extends StatelessWidget {
  final List<String> facilities;
  final Color primaryOrange;
  const _FacilitiesSection(
      {required this.facilities, required this.primaryOrange});

  static const _facilityIcons = <String, IconData>{
    'Air conditioner': Icons.ac_unit,       'Aircon':       Icons.ac_unit,
    'Kitchen':         Icons.kitchen,        'Free WiFi':    Icons.wifi,
    'WiFi':            Icons.wifi,           'Parking':      Icons.local_parking,
    'Free parking':    Icons.local_parking,  'Washing machine': Icons.local_laundry_service,
    'Swimming pool':   Icons.pool,           'Gym':          Icons.fitness_center,
    'TV':              Icons.tv,             'Balcony':      Icons.deck,
    'CCTV':            Icons.videocam_outlined, 'Pet Friendly': Icons.pets,
  };

  @override
  Widget build(BuildContext context) {
    if (facilities.isEmpty) return const SizedBox();
    final displayed = facilities.take(4).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Home facilities',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () => _showAll(context),
              child: Text('See all facilities',
                  style: TextStyle(
                      color: primaryOrange,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...displayed.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Icon(_facilityIcons[f] ?? Icons.check_circle_outline,
                    size: 20, color: Colors.grey[700]),
                const SizedBox(width: 12),
                Text(f, style: TextStyle(fontSize: 14)),
              ]),
            )),
      ]),
    );
  }

  void _showAll(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('All Facilities',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...facilities.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Icon(_facilityIcons[f] ?? Icons.check_circle_outline,
                        size: 20, color: Colors.grey[700]),
                    const SizedBox(width: 12),
                    Text(f, style: TextStyle(fontSize: 14)),
                  ]),
                )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  final double lat;
  final double lng;
  final String name;
  const _MapPreview({required this.lat, required this.lng, required this.name});

  @override
  Widget build(BuildContext context) {
    if (lat == 0 && lng == 0) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
            color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text('Map preview unavailable')),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 160,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 15),
          markers: {
            Marker(markerId: const MarkerId('location'), position: LatLng(lat, lng))
          },
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
        ),
      ),
    );
  }
}

class _NearbyFacilitiesSection extends StatelessWidget {
  final List<NearbyFacility> nearbyFacilities;
  const _NearbyFacilitiesSection({required this.nearbyFacilities});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nearest public facilities',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8),
              itemCount: nearbyFacilities.length,
              itemBuilder: (_, i) {
                final f = nearbyFacilities[i];
                return Row(children: [
                  Icon(f.icon, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(f.name,
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(f.distance,
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ]);
              },
            ),
          ],
        ),
      );
}

class _AboutSection extends StatefulWidget {
  final String description;
  const _AboutSection({required this.description});

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            "About location's neighborhood",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            widget.description,
            maxLines: _expanded ? null : 5,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMid,
              height: 1.5,
            ),
          ),

          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Show less' : 'Read more',
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestimonialsSection extends StatelessWidget {
  final List<Testimonial> testimonials;
  const _TestimonialsSection({required this.testimonials});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Testimonials',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...testimonials.map((t) => _TestimonialCard(testimonial: t)),
        ]),
      );
}

class _TestimonialCard extends StatefulWidget {
  final Testimonial testimonial;
  const _TestimonialCard({required this.testimonial});
  @override
  State<_TestimonialCard> createState() => _TestimonialCardState();
}

class _TestimonialCardState extends State<_TestimonialCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: widget.testimonial.photoUrl.isNotEmpty
                  ? NetworkImage(widget.testimonial.photoUrl) : null,
              child: widget.testimonial.photoUrl.isEmpty
                  ? Icon(Icons.person, size: 20) : null,
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.testimonial.name,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(Icons.star, size: 14,
                      color: i < widget.testimonial.rating
                          ? AppColors.primaryOrange : Colors.grey[300]),
                ),
              ),
            ]),
          ]),
          const SizedBox(height: 8),
          Text(widget.testimonial.comment,
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, color: Colors.black87, height: 1.5)),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Show less' : 'Read more',
                style: TextStyle(
                    color: AppColors.primaryOrange, fontWeight: FontWeight.w500)),
          ),
        ]),
      );
}

// ─── Usage ────────────────────────────────────────────────────────────────────
// Navigator.push(context, MaterialPageRoute(
//   builder: (_) => ApartmentDetailPage(apartmentId: 'your_doc_id'),
// ));
class FullscreenGalleryPage extends StatefulWidget {
  final List<String> images;

  const FullscreenGalleryPage({
    Key? key,
    required this.images,
  }) : super(key: key);

  @override
  State<FullscreenGalleryPage> createState() =>
      _FullscreenGalleryPageState();
}

class _FullscreenGalleryPageState
    extends State<FullscreenGalleryPage> {

  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) {
              setState(() => _index = i);
            },
            itemBuilder: (_, i) {
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    widget.images[i],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),

          // Close button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.close, color: AppColors.card(context)),
                ),
              ),
            ),
          ),

          // Image counter
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${_index + 1} / ${widget.images.length}',
                style: TextStyle(
                  color: AppColors.card(context),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  } 
}