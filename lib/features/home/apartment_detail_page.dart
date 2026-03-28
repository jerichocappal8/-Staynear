// ════════════════════════════════════════════════════════════════════════════
//  apartment_detail_page.dart  — StayNear  (UI redesign, logic unchanged)
//  Drop-in replacement for the original file.
//  All Firestore queries, models, and Navigator calls are identical.
// ════════════════════════════════════════════════════════════════════════════
//
//  ANIMATIONS AT A GLANCE
//  ┌──────────────────────────────────────────────────────────────────────┐
//  │  Hero             → cover image (tag = 'apt_img_<id>')              │
//  │  Staggered fade   → 6 page sections, 80 ms apart                    │
//  │  Bounce scale     → favourite heart (TweenSequence)                 │
//  │  AnimatedContainer→ pill page-indicator width                        │
//  │  AnimatedSwitcher → availability badge text                          │
//  │  AnimatedScale    → room tile press (0.975×)                         │
//  │  AnimatedContainer→ room selection tile bg + border                  │
//  │  AnimatedScale    → CTA button press (0.97×)                         │
//  │  AnimatedContainer→ CTA button gradient ↔ disabled state             │
//  │  AnimatedCrossFade→ "About" + testimonial expand/collapse             │
//  └──────────────────────────────────────────────────────────────────────┘

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'dart:async';
import '../chat/chat_service.dart';
import '../chat/chat_room_screen.dart';

// ── palette helpers (unchanged values) ────────────────────────────────────────
const Color _green = Color(0xFF22C55E);
const Color _red   = Color(0xFFEF4444);


// ════════════════════════════════════════════════════════════════════════════
//  PAGE
// ════════════════════════════════════════════════════════════════════════════

class ApartmentDetailPage extends StatefulWidget {
  final String apartmentId;
  const ApartmentDetailPage({Key? key, required this.apartmentId})
      : super(key: key);

  @override
  State<ApartmentDetailPage> createState() => _ApartmentDetailPageState();
}

class _ApartmentDetailPageState extends State<ApartmentDetailPage>
    with TickerProviderStateMixin {

  // ── gallery ────────────────────────────────────────────────────────────────
  final PageController _pageController = PageController(
    viewportFraction: 1,
  keepPage: true,
  );
  int  _currentImageIndex = 0;
  bool _isFavorite        = false;

  // ── host ───────────────────────────────────────────────────────────────────
  String  hostName           = '';
  String  hostPhoto          = '';
  String  hostPhone          = '';
  String? _lastLoadedOwnerId;

  // ── staggered section anims (0=gallery 1=title 2=host 3=rooms 4=terms 5=reviews)
  late final List<AnimationController> _sectionCtrl;
  late final List<Animation<double>>   _sectionFade;
  late final List<Animation<Offset>>   _sectionSlide;

  // ── favourite bounce ───────────────────────────────────────────────────────
  late final AnimationController _favCtrl;
  late final Animation<double>   _favScale;

  @override
  void initState() {
    super.initState();

    // 6 staggered section controllers
    _sectionCtrl = List.generate(
      6,
      (_) => AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520),
      ),
    );
    _sectionFade = _sectionCtrl
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();
    _sectionSlide = _sectionCtrl.map((c) =>
      Tween<Offset>(begin: const Offset(0, .055), end: Offset.zero)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic))
    ).toList();

    for (int i = 0; i < _sectionCtrl.length; i++) {
      Future.delayed(Duration(milliseconds: 80 + i * 80), () {
        if (mounted) _sectionCtrl[i].forward();
      });
    }

    // Favourite heart — bouncy TweenSequence
    _favCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 360));
    _favScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45), weight: 38),
      TweenSequenceItem(tween: Tween(begin: 1.45, end: .88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: .88,  end: 1.0),  weight: 32),
    ]).animate(CurvedAnimation(parent: _favCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _sectionCtrl) c.dispose();
    _favCtrl.dispose();
    super.dispose();
  }

  // ── logic (UNCHANGED) ─────────────────────────────────────────────────────

Future<void> _loadHost(String uid) async {

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();

  if (!doc.exists || !mounted) return;

  final d = doc.data()!;

  setState(() {

    hostName =
        '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim();

    hostPhoto = d['photo'] ?? '';

    hostPhone = d['phone'] ?? '';

  });
}

  Future<void> _callHost() async {
    if (hostPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number not available')));
      return;
    }
    final launched = await launchUrl(
        Uri(scheme: 'tel', path: hostPhone),
        mode: LaunchMode.externalApplication);
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer')));
    }
  }

  String _fmt(double p) => p
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  void _showRoomSelectionSheet(
      BuildContext context, ApartmentModel apt, List<RoomOffer> rooms) {
    final available = rooms
        .where((r) => r.isAvailable && (int.tryParse(r.availableUnits) ?? 0) > 0)
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoomSelectionSheet(
        apt: apt,
        rooms: available,
        onConfirm: (room) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (ctx) =>
                    CheckoutScreen(apartment: apt, room: room)),
          );
        },
      ),
    );
  }

  // ── section wrapper ────────────────────────────────────────────────────────
  Widget _s(int i, Widget child) => FadeTransition(
        opacity: _sectionFade[i],
        child: SlideTransition(position: _sectionSlide[i], child: child),
      );

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.apartmentId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primaryOrange)));
        }
        if (snap.hasError || !snap.hasData || !snap.data!.exists) {
          return const Scaffold(
              body: Center(child: Text('Property not found.')));
        }

        final apt = ApartmentModel.fromFirestore(snap.data!);
        if (_lastLoadedOwnerId != apt.ownerId) {
          _lastLoadedOwnerId = apt.ownerId;
          _loadHost(apt.ownerId);
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('properties')
              .doc(widget.apartmentId)
              .collection('rooms')
              .snapshots(),
          builder: (context, roomSnap) {
            final rooms = roomSnap.hasData
                ? roomSnap.data!.docs
                    .map((doc) => RoomOffer.fromFirestore(
                        doc.id, doc.data() as Map<String, dynamic>))
                    .toList()
                : <RoomOffer>[];
            final roomsLoading = !roomSnap.hasData;

            return Scaffold(
              backgroundColor: AppColors.background(context),
              extendBodyBehindAppBar: true,
              bottomNavigationBar: _s(5, _BottomBar(
                apt:    apt,
                rooms:  rooms,
                fmt:    _fmt,
                onRent: () =>
                    _showRoomSelectionSheet(context, apt, rooms),
              )),
              body: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── 0 · Gallery ──────────────────────────────
                        _ImageGallery(
  apartmentId: widget.apartmentId,
  images: apt.images,
  controller: _pageController,
  currentIndex: _currentImageIndex,
  onPageChanged: (i) => setState(() => _currentImageIndex = i),
  onBack: () => Navigator.pop(context),
  isFavorite: _isFavorite,
  onFavorite: () {
    _favCtrl.forward(from: 0);
    HapticFeedback.lightImpact();
    setState(() => _isFavorite = !_isFavorite);
  },
  favScale: _favScale,
),

                        // View photos button
                        _s(0, Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          child: _ViewPhotosButton(
                              primaryOrange: AppColors.primaryOrange,
                              images: apt.images),
                        )),

                        const SizedBox(height: 20),

                        // ── 1 · Title + rating + address ─────────────
                        _s(1, _TitleSection(apt: apt)),

                        const SizedBox(height: 20),
                        _Div(),
                        const SizedBox(height: 20),

                        // ── 2 · Host card ─────────────────────────────
                        // ── 2 · Host card ─────────────────────────────
_s(2, Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: _HostCard(
    apt: apt,
    name: hostName,
    photo: hostPhoto,
    onCall: _callHost,
    onChat: () async {

      final chatService = ChatService();

      final conversationId =
          await chatService.getOrCreateConversation(
        propertyId: apt.id,
        propertyName: apt.name,
        hostId: apt.ownerId,
      );

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            conversationId: conversationId,
            otherParticipantId: apt.ownerId,
            otherParticipantName: hostName,
            otherParticipantPhoto: hostPhoto,
            propertyName: apt.name,
          ),
        ),
      );
    },
  ),
)),

                        const SizedBox(height: 20),
                        _Div(),
                        const SizedBox(height: 20),

                        // ── 3 · Rooms ─────────────────────────────────
                        _s(3, _RoomsSection(
                          rooms:     rooms,
                          isLoading: roomsLoading,
                          fmt:       _fmt,
                        )),

                        const SizedBox(height: 20),
                        _Div(),
                        const SizedBox(height: 20),

                        // ── 4a · Rental terms ─────────────────────────
                        _s(4, _RentalTermsSection(
                            terms: apt.rentalTerms, fmt: _fmt)),

                        const SizedBox(height: 20),
                        _Div(),
                        const SizedBox(height: 20),

                        // ── 4b · Facilities ───────────────────────────
                        _s(4, _FacilitiesSection(
                            facilities: apt.facilities,
                            primaryOrange: AppColors.primaryOrange)),

                        const SizedBox(height: 20),

                        // ── 4c · Map ──────────────────────────────────
                        _s(4, Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: _MapPreview(
                              lat: apt.lat,
                              lng: apt.lng,
                              name: apt.name),
                        )),

                        const SizedBox(height: 20),
                        _Div(),
                        const SizedBox(height: 20),

                        // ── 4d · Nearby ───────────────────────────────
                        if (apt.nearbyFacilities.isNotEmpty)
                          _s(4, _NearbyFacilitiesSection(
                              nearbyFacilities: apt.nearbyFacilities)),

                        const SizedBox(height: 20),
                        _Div(),
                        const SizedBox(height: 20),

                        // ── 4e · About ────────────────────────────────
                        _s(4, _AboutSection(description: apt.description)),

                        // ── 4f · House rules ──────────────────────────
                        if (apt.houseRules.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _Div(),
                          const SizedBox(height: 20),
                          _s(4, _HouseRulesSection(rules: apt.houseRules)),
                        ],

                        const SizedBox(height: 20),
                        _Div(),
                        const SizedBox(height: 20),

                        // ── 5 · Testimonials ──────────────────────────
                        StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('reviews')
      .where('apartmentId', isEqualTo: widget.apartmentId)
      .snapshots(),
  builder: (context, reviewSnap) {
    print("Apartment ID: ${widget.apartmentId}");
  print("Review docs: ${reviewSnap.data?.docs.length}");
    if (!reviewSnap.hasData || reviewSnap.data!.docs.isEmpty) {
      return const SizedBox.shrink();
    }

final testimonials = reviewSnap.data!.docs.map((doc) {
  return Testimonial.fromReviewDoc(
    doc.data() as Map<String, dynamic>,
  );
}).toList();

    return _s(5, _TestimonialsSection(testimonials: testimonials));
  },
),
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


// ════════════════════════════════════════════════════════════════════════════
//  THIN DIVIDER
// ════════════════════════════════════════════════════════════════════════════

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: AppColors.border,
      );
}


// ════════════════════════════════════════════════════════════════════════════
//  IMAGE GALLERY
//  • Hero on first image
//  • Animated pill-dot indicator
//  • Gradient scrim for legibility
//  • Animated favourite button (scale bounce + icon switch)
// ════════════════════════════════════════════════════════════════════════════

class _ImageGallery extends StatefulWidget {
  final String apartmentId;
  final List<String> images;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onBack;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final Animation<double> favScale;

  const _ImageGallery({
    required this.apartmentId,
    required this.images,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onBack,
    required this.isFavorite,
    required this.onFavorite,
    required this.favScale,
  });

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    if (widget.images.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;

        setState(() {
          _index = (_index + 1) % widget.images.length;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      height: 300,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [

          /// IMAGE
          widget.images.isEmpty
              ? Container(
                  color: AppColors.orangeLight,
                  child: const Center(
                    child: Icon(
                      Icons.apartment_rounded,
                      size: 80,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                )
              : Hero(
                  tag: 'apt_img_${widget.apartmentId}',
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: Image.network(
                      widget.images[_index],
                      key: ValueKey(widget.images[_index]),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 300,
                    ),
                  ),
                ),

          /// BOTTOM GRADIENT
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 100,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xBB000000), Colors.transparent],
                ),
              ),
            ),
          ),

          /// BACK BUTTON
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _GlassButton(
                onTap: widget.onBack,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),

          /// FAVORITE BUTTON
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 12,
            child: GestureDetector(
              onTap: widget.onFavorite,
              child: AnimatedBuilder(
                animation: widget.favScale,
                builder: (_, child) => Transform.scale(
                  scale: widget.favScale.value,
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// small frosted glass icon button used in gallery overlay
class _GlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _GlassButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width:  38,
          height: 38,
          decoration: BoxDecoration(
            color:         Colors.black.withOpacity(.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withOpacity(.18), width: 1),
          ),
          child: Center(child: child),
        ),
      );
}


// ════════════════════════════════════════════════════════════════════════════
//  VIEW PHOTOS BUTTON  (logic unchanged)
// ════════════════════════════════════════════════════════════════════════════

class _ViewPhotosButton extends StatelessWidget {
  final Color        primaryOrange;
  final List<String> images;
  const _ViewPhotosButton(
      {required this.primaryOrange, required this.images});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => FullscreenGalleryPage(images: images)),
        ),
        icon: Icon(Icons.photo_library_outlined,
            color: primaryOrange, size: 16),
        label: Text(
          'View all ${images.length} photo${images.length == 1 ? '' : 's'}',
          style: TextStyle(
              color:      primaryOrange,
              fontWeight: FontWeight.w600,
              fontSize:   13),
        ),
        style: OutlinedButton.styleFrom(
          side:        BorderSide(color: primaryOrange, width: 1.2),
          shape:       RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30)),
          minimumSize: const Size(double.infinity, 44),
        ),
      );
}


// ════════════════════════════════════════════════════════════════════════════
//  TITLE SECTION  — name · category badge · rating · address · verified pill
// ════════════════════════════════════════════════════════════════════════════

class _TitleSection extends StatelessWidget {
  final ApartmentModel apt;
  const _TitleSection({required this.apt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // category badge + favourite (favourite moved to gallery overlay)
        if (apt.category.isNotEmpty) ...[
          _CategoryBadge(label: apt.category),
          const SizedBox(height: 8),
        ],

        // name
        Text(
          apt.name,
          style: TextStyle(
            fontSize:      24,
            fontWeight:    FontWeight.w800,
            color:         AppColors.text(context),
            height:        1.15,
            letterSpacing: -.5,
          ),
        ),

        const SizedBox(height: 10),

        // rating row
        Row(children: [
          const Icon(Icons.star_rounded,
              color: AppColors.primaryOrange, size: 15),
          const SizedBox(width: 4),
          Text(
            '${apt.rating}',
            style: TextStyle(
              fontSize:   13.5,
              fontWeight: FontWeight.w700,
              color:      AppColors.text(context),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '(${apt.reviewCount} reviews)',
            style: const TextStyle(fontSize: 13, color: AppColors.textMid),
          ),
          const Spacer(),
          // verified pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:         _green.withOpacity(.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.verified_rounded, size: 12, color: _green),
              const SizedBox(width: 4),
              Text('Verified',
                  style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                      color:      _green)),
            ]),
          ),
        ]),

        const SizedBox(height: 7),

        // address
        Row(children: [
          const Icon(Icons.location_on_outlined,
              size: 13, color: AppColors.textLight),
          const SizedBox(width: 4),
          Expanded(
            child: Text(apt.address,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textMid)),
          ),
        ]),
      ]),
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
//  HOST CARD  — elevated card, animated action buttons
// ════════════════════════════════════════════════════════════════════════════

class _HostCard extends StatelessWidget {
  final ApartmentModel apt;
  final String       name;
  final String       photo;
  final VoidCallback onCall;
  final VoidCallback onChat;
  const _HostCard({
    required this.apt,
    required this.name,
    required this.photo,
    required this.onCall,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:         AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border:        Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(.05),
              blurRadius: 16,
              offset:     const Offset(0, 4)),
        ],
      ),
      child: Row(children: [

        // avatar + online dot
        Stack(children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            backgroundColor: AppColors.orangeLight,
            child: photo.isEmpty
                ? const Icon(Icons.person_rounded,
                    color: AppColors.primaryOrange)
                : null,
          ),
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width:  14,
              height: 14,
              decoration: BoxDecoration(
                color:  _green,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.card(context), width: 2),
              ),
            ),
          ),
        ]),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Host',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   14.5,
                    color:      AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 2),
                const Text('Property Owner',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMid)),
              ]),
        ),

        // chat button
        _ActionBtn(
            icon:   Icons.chat_bubble_outline_rounded,
            filled: false,
            onTap:  onChat),
        const SizedBox(width: 8),
        // call button
        _ActionBtn(
            icon:   Icons.phone_rounded,
            filled: true,
            onTap:  onCall),
      ]),
    );
  }
}

// small press-animated icon button used in host card
class _ActionBtn extends StatefulWidget {
  final IconData     icon;
  final bool         filled;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.filled, required this.onTap});

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _scale = .90),
      onTapUp:     (_) { setState(() => _scale = 1.0); widget.onTap(); },
      onTapCancel: ()  => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale:    _scale,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width:  40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.filled
                ? AppColors.primaryOrange
                : AppColors.orangeLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(widget.icon,
              size:  18,
              color: widget.filled ? Colors.white : AppColors.primaryOrange),
        ),
      ),
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
//  ROOMS SECTION
// ════════════════════════════════════════════════════════════════════════════

class _RoomsSection extends StatelessWidget {
  final List<RoomOffer>       rooms;
  final bool                  isLoading;
  final String Function(double) fmt;
  const _RoomsSection(
      {required this.rooms,
      required this.isLoading,
      required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Available Rooms',
                style: TextStyle(
                  fontSize:      17,
                  fontWeight:    FontWeight.w800,
                  color:         AppColors.text(context),
                  letterSpacing: -.3,
                )),
            if (!isLoading && rooms.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color:         AppColors.orangeLight,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${rooms.length} type${rooms.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize:   12,
                      color:      AppColors.primaryOrange,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),

        const SizedBox(height: 14),

        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(
                  color: AppColors.primaryOrange, strokeWidth: 2),
            ),
          )
        else if (rooms.isEmpty)
          _EmptyRoomsState()
        else
          ...rooms.map((r) => _RoomTile(room: r, fmt: fmt)),
      ]),
    );
  }
}

class _EmptyRoomsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color:         AppColors.background(context),
          borderRadius: BorderRadius.circular(16),
          border:        Border.all(color: AppColors.border),
        ),
        child: Column(children: const [
          Icon(Icons.meeting_room_outlined,
              size: 36, color: AppColors.textLight),
          SizedBox(height: 8),
          Text('No rooms listed yet',
              style: TextStyle(
                  color:      AppColors.textMid,
                  fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('Check back later or contact the host',
              style:
                  TextStyle(color: AppColors.textLight, fontSize: 12)),
        ]),
      );
}

// ── Room tile — press-scale animation ─────────────────────────────────────────

class _RoomTile extends StatefulWidget {
  final RoomOffer             room;
  final String Function(double) fmt;
  const _RoomTile({required this.room, required this.fmt});

  @override
  State<_RoomTile> createState() => _RoomTileState();
}

class _RoomTileState extends State<_RoomTile> {
  double _scale = 1.0;

  static const _typeIcons = <String, IconData>{
    'Studio':      Icons.single_bed_rounded,
    '1 Bedroom':   Icons.bed_rounded,
    '2 Bedroom':   Icons.bedroom_parent_rounded,
    'Bed Space':   Icons.airline_seat_individual_suite_rounded,
    'Entire Unit': Icons.home_rounded,
  };
  static const _genderColors = <String, Color>{
    'Male':   Color(0xFF3B82F6),
    'Female': Color(0xFFEC4899),
    'Any':    AppColors.textMid,
  };
  static const _genderIcons = <String, IconData>{
    'Male':   Icons.male_rounded,
    'Female': Icons.female_rounded,
    'Any':    Icons.people_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final room      = widget.room;
    final available = room.isAvailable &&
        (int.tryParse(room.availableUnits) ?? 0) > 0;
    final icon   = _typeIcons[room.roomType]           ?? Icons.meeting_room_outlined;
    final gColor = _genderColors[room.genderRestriction] ?? AppColors.textMid;
    final gIcon  = _genderIcons[room.genderRestriction]  ?? Icons.people_outline_rounded;

    return GestureDetector(
      onTapDown:   (_) => setState(() => _scale = .975),
      onTapUp:     (_) => setState(() => _scale = 1.0),
      onTapCancel: ()  => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale:    _scale,
        duration: const Duration(milliseconds: 130),
        curve:    Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:         AppColors.card(context),
            borderRadius: BorderRadius.circular(20),
            border:        Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                  color:      Colors.black.withOpacity(.04),
                  blurRadius: 14,
                  offset:     const Offset(0, 4))
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // type icon container
              Container(
                width:  50,
                height: 50,
                decoration: BoxDecoration(
                  color: available
                      ? AppColors.orangeLight
                      : AppColors.background(context),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon,
                    color: available
                        ? AppColors.primaryOrange
                        : AppColors.textLight,
                    size: 24),
              ),

              const SizedBox(width: 12),

              // info column
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            room.roomType,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize:   15,
                              color:      AppColors.text(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _AvailabilityBadge(
                          available: available,
                          units: int.tryParse(room.availableUnits) ?? 0,
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        _MetaChip(
                            icon:  Icons.people_outline_rounded,
                            label: 'Max ${room.maxOccupants} pax',
                            color: AppColors.textMid),
                        _MetaChip(
                            icon:  gIcon,
                            label: room.genderRestriction,
                            color: gColor),
                      ]),
                    ]),
              ),

              const SizedBox(width: 8),

              // price + fees
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      '₱${widget.fmt(room.activePrice)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize:   15,
                          color:      AppColors.primaryOrange),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      room.pricingMode == 'daily' ? '/day' : '/mo',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMid),
                    ),
                  ]),
                  if ((double.tryParse(room.serviceFee) ?? 0) > 0) ...[
                    const SizedBox(height: 2),
                    Text('+ ₱${widget.fmt(double.parse(room.serviceFee))} service fee',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textLight)),
                  ],
                  if ((double.tryParse(room.securityDeposit) ?? 0) > 0) ...[
                    const SizedBox(height: 2),
                    Text('₱${widget.fmt(double.parse(room.securityDeposit))} deposit',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textLight)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated availability badge ───────────────────────────────────────────────

class _AvailabilityBadge extends StatelessWidget {
  final bool available;
  final int  units;
  const _AvailabilityBadge(
      {required this.available, required this.units});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Container(
        key:     ValueKey('$available$units'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: available
              ? _green.withOpacity(.12)
              : _red.withOpacity(.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width:  6,
            height: 6,
            decoration: BoxDecoration(
                color: available ? _green : _red, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            available ? '$units unit${units == 1 ? '' : 's'} left' : 'Full',
            style: TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.w600,
              color: available ? const Color(0xFF059669) : _red,
            ),
          ),
        ]),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _MetaChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color:         color.withOpacity(.08),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize:   11,
                  color:      color,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}

class _CategoryBadge extends StatelessWidget {
  final String label;
  const _CategoryBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
            color:         AppColors.orangeLight,
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: const TextStyle(
                fontSize:   12,
                color:      AppColors.primaryOrange,
                fontWeight: FontWeight.w700)),
      );
}


// ════════════════════════════════════════════════════════════════════════════
//  RENTAL TERMS  — two-column chip cards
// ════════════════════════════════════════════════════════════════════════════

class _RentalTermsSection extends StatelessWidget {
  final RentalTerms             terms;
  final String Function(double) fmt;
  const _RentalTermsSection({required this.terms, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Rental Terms',
            style: TextStyle(
              fontSize:      17,
              fontWeight:    FontWeight.w800,
              color:         AppColors.text(context),
              letterSpacing: -.3,
            )),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _TermChip(
            icon:  Icons.calendar_month_outlined,
            title: 'Min. Stay',
            value: '${terms.minimumStayMonths} mo${terms.minimumStayMonths == 1 ? '' : 's'}',
          )),
          const SizedBox(width: 10),
          Expanded(child: _TermChip(
            icon:  Icons.payments_outlined,
            title: 'Advance',
            value: '${terms.advanceMonthsRequired} mo${terms.advanceMonthsRequired == 1 ? '' : 's'}',
          )),
        ]),
      ]),
    );
  }
}

class _TermChip extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   value;
  const _TermChip(
      {required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:         AppColors.card(context),
          borderRadius: BorderRadius.circular(18),
          border:        Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(.04),
                blurRadius: 12,
                offset:     const Offset(0, 3))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width:  36,
            height: 36,
            decoration: BoxDecoration(
                color:         AppColors.orangeLight,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.primaryOrange),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMid)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                fontSize:      16,
                fontWeight:    FontWeight.w800,
                color:         AppColors.text(context),
                letterSpacing: -.2,
              )),
        ]),
      );
}


// ════════════════════════════════════════════════════════════════════════════
//  HOUSE RULES  (logic unchanged)
// ════════════════════════════════════════════════════════════════════════════

class _HouseRulesSection extends StatelessWidget {
  final List<String> rules;
  const _HouseRulesSection({required this.rules});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('House Rules',
              style: TextStyle(
                fontSize:      17,
                fontWeight:    FontWeight.w800,
                color:         AppColors.text(context),
                letterSpacing: -.3,
              )),
          const SizedBox(height: 12),
          Wrap(
            spacing:   8,
            runSpacing: 8,
            children: rules.map((r) => _RuleChip(label: r)).toList(),
          ),
        ]),
      );
}

class _RuleChip extends StatelessWidget {
  final String label;
  const _RuleChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:         AppColors.card(context),
          borderRadius: BorderRadius.circular(30),
          border:        Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(.03),
                blurRadius: 6,
                offset:     const Offset(0, 2))
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 14, color: AppColors.primaryOrange),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize:   12.5,
                  color:      AppColors.text(context),
                  fontWeight: FontWeight.w500)),
        ]),
      );
}


// ════════════════════════════════════════════════════════════════════════════
//  FACILITIES  — icon grid with colour-coded chips + see-all sheet
// ════════════════════════════════════════════════════════════════════════════

class _FacilitiesSection extends StatelessWidget {
  final List<String> facilities;
  final Color        primaryOrange;
  const _FacilitiesSection(
      {required this.facilities, required this.primaryOrange});

  static const _icons = <String, IconData>{
    'Air conditioner':  Icons.ac_unit,
    'Aircon':           Icons.ac_unit,
    'Kitchen':          Icons.kitchen,
    'Free WiFi':        Icons.wifi,
    'WiFi':             Icons.wifi,
    'Parking':          Icons.local_parking,
    'Free parking':     Icons.local_parking,
    'Washing machine':  Icons.local_laundry_service,
    'Swimming pool':    Icons.pool,
    'Gym':              Icons.fitness_center,
    'TV':               Icons.tv,
    'Balcony':          Icons.deck,
    'CCTV':             Icons.videocam_outlined,
    'Pet Friendly':     Icons.pets,
  };
  static const _colors = <String, Color>{
    'Air conditioner':  Color(0xFF3B82F6),
    'Aircon':           Color(0xFF3B82F6),
    'Free WiFi':        Color(0xFF8B5CF6),
    'WiFi':             Color(0xFF8B5CF6),
    'Swimming pool':    Color(0xFF06B6D4),
    'Gym':              Color(0xFFEF4444),
    'CCTV':             Color(0xFF64748B),
  };

  @override
  Widget build(BuildContext context) {
    if (facilities.isEmpty) return const SizedBox();
    final displayed = facilities.take(6).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Home Facilities',
                style: TextStyle(
                  fontSize:      17,
                  fontWeight:    FontWeight.w800,
                  color:         AppColors.text(context),
                  letterSpacing: -.3,
                )),
            GestureDetector(
              onTap: () => _showAll(context),
              child: Text('See all',
                  style: TextStyle(
                      color:      primaryOrange,
                      fontSize:   13,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount:   3,
          crossAxisSpacing: 10,
          mainAxisSpacing:  10,
          childAspectRatio: 1.15,
          children: displayed.map((f) {
            final icon  = _icons[f]  ?? Icons.check_circle_outline;
            final color = _colors[f] ?? primaryOrange;
            return Container(
              decoration: BoxDecoration(
                color:         color.withOpacity(.08),
                borderRadius: BorderRadius.circular(14),
                border:        Border.all(
                    color: color.withOpacity(.20), width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(height: 6),
                  Text(f,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize:   10.5,
                          color:      color,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  void _showAll(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: AppColors.card(context),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('All Facilities',
                style: TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.w800,
                  color:      AppColors.text(context),
                )),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: facilities.map((f) {
                final icon  = _icons[f]  ?? Icons.check_circle_outline;
                final color = _colors[f] ?? AppColors.primaryOrange;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:         color.withOpacity(.08),
                    borderRadius: BorderRadius.circular(12),
                    border:        Border.all(
                        color: color.withOpacity(.20)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(f,
                        style: TextStyle(
                            fontSize:   13,
                            color:      color,
                            fontWeight: FontWeight.w600)),
                  ]),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
//  MAP  (logic unchanged, rounded card wrapper)
// ════════════════════════════════════════════════════════════════════════════

class _MapPreview extends StatelessWidget {
  final double lat;
  final double lng;
  final String name;
  const _MapPreview(
      {required this.lat, required this.lng, required this.name});

  @override
  Widget build(BuildContext context) {
    if (lat == 0 && lng == 0) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
            color:         AppColors.background(context),
            borderRadius: BorderRadius.circular(18),
            border:        Border.all(color: AppColors.border)),
        child: const Center(
            child: Text('Map preview unavailable',
                style: TextStyle(color: AppColors.textMid))),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text('Location',
            style: TextStyle(
              fontSize:      17,
              fontWeight:    FontWeight.w800,
              color:         AppColors.text(context),
              letterSpacing: -.3,
            )),
      ),
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 170,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
                target: LatLng(lat, lng), zoom: 15),
            markers: {
              Marker(
                  markerId: const MarkerId('location'),
                  position: LatLng(lat, lng))
            },
            zoomControlsEnabled:     false,
            myLocationButtonEnabled: false,
          ),
        ),
      ),
    ]);
  }
}


// ════════════════════════════════════════════════════════════════════════════
//  NEARBY FACILITIES  (logic unchanged, card grid)
// ════════════════════════════════════════════════════════════════════════════

class _NearbyFacilitiesSection extends StatelessWidget {
  final List<NearbyFacility> nearbyFacilities;
  const _NearbyFacilitiesSection({required this.nearbyFacilities});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Nearby Places',
              style: TextStyle(
                fontSize:      17,
                fontWeight:    FontWeight.w800,
                color:         AppColors.text(context),
                letterSpacing: -.3,
              )),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:   2,
                    childAspectRatio: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing:  8),
            itemCount: nearbyFacilities.length,
            itemBuilder: (_, i) {
              final f = nearbyFacilities[i];
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color:         AppColors.card(context),
                  borderRadius: BorderRadius.circular(10),
                  border:        Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Icon(f.icon,
                      size:  16,
                      color: AppColors.primaryOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(f.name,
                            style: TextStyle(
                              fontSize:   11.5,
                              fontWeight: FontWeight.w600,
                              color:      AppColors.text(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(f.distance,
                            style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textMid)),
                      ],
                    ),
                  ),
                ]),
              );
            },
          ),
        ]),
      );
}


// ════════════════════════════════════════════════════════════════════════════
//  ABOUT  — AnimatedCrossFade expand (logic unchanged)
// ════════════════════════════════════════════════════════════════════════════

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("About location's neighborhood",
            style: TextStyle(
              fontSize:      17,
              fontWeight:    FontWeight.w800,
              color:         AppColors.text(context),
              letterSpacing: -.3,
            )),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 260),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Text(
            widget.description,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13.5, color: AppColors.textMid, height: 1.6),
          ),
          secondChild: Text(
            widget.description,
            style: const TextStyle(
                fontSize: 13.5, color: AppColors.textMid, height: 1.6),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? 'Show less' : 'Read more',
            style: const TextStyle(
              color:      AppColors.primaryOrange,
              fontWeight: FontWeight.w600,
              fontSize:   13,
            ),
          ),
        ),
      ]),
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
//  TESTIMONIALS  — card layout + animated expand
// ════════════════════════════════════════════════════════════════════════════

class _TestimonialsSection extends StatelessWidget {
  final List<Testimonial> testimonials;
  const _TestimonialsSection({required this.testimonials});

  double get _average {
    if (testimonials.isEmpty) return 0;
    return testimonials.map((t) => t.rating).reduce((a, b) => a + b) /
        testimonials.length;
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header row ────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Reviews',
                  style: TextStyle(
                    fontSize:      17,
                    fontWeight:    FontWeight.w800,
                    color:         AppColors.text(context),
                    letterSpacing: -.3,
                  )),
              const Spacer(),
              // Average score pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color:         AppColors.orangeLight,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded,
                      size: 13, color: AppColors.primaryOrange),
                  const SizedBox(width: 4),
                  Text(
                    _average > 0
                        ? _average.toStringAsFixed(1)
                        : '—',
                    style: const TextStyle(
                        fontSize:   12,
                        color:      AppColors.primaryOrange,
                        fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '  ·  ${testimonials.length} review'
                    '${testimonials.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize:   12,
                        color:      AppColors.primaryOrange,
                        fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
            ],
          ),

          const SizedBox(height: 14),
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

  // ── tiny helpers ──────────────────────────────────────────────────────────
  static String _fmtDate(DateTime? dt) {
    if (dt == null) return '';
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  static String _stayDuration(DateTime? i, DateTime? o) {
    if (i == null || o == null) return '';
    final nights = o.difference(i).inDays;
    if (nights <= 0) return '';
    // Show as months if ≥ 28 days, else nights
    if (nights >= 28) {
      final months = (nights / 30).round();
      return '$months month${months == 1 ? '' : 's'}';
    }
    return '$nights night${nights == 1 ? '' : 's'}';
  }

  static String _fmtPrice(double v) =>
      '₱${v.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')
          }';

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final t        = widget.testimonial;
    final duration = _stayDuration(t.checkIn, t.checkOut);
    final dateStr  = _fmtDate(t.createdAt);
    final fullInt  = t.rating.floor();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:         AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border:        Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(.04),
              blurRadius: 14,
              offset:     const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Row 1: avatar · name/date · stars ───────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Avatar — photo or initials fallback
              Container(
                width:  46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.primaryOrange.withOpacity(.25),
                      width: 2),
                ),
                child: ClipOval(
                  child: FutureBuilder<DocumentSnapshot>(
  future: FirebaseFirestore.instance
      .collection('users')
      .doc(t.userId)
      .get(),
  builder: (context, snap) {
    if (snap.hasData && snap.data!.exists) {
      final data = snap.data!.data() as Map<String, dynamic>;
      final photo = data['photo'] ?? '';

      if (photo != '') {
        return Image.network(photo, fit: BoxFit.cover);
      }
    }
    return _InitialsAvatar(name: t.name);
  },
),
                ),
              ),

              const SizedBox(width: 11),

              // Name + review date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   14,
                          color:      AppColors.text(context),
                        )),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(dateStr,
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textLight)),
                    ],
                  ],
                ),
              ),

              // Star rating (numeric + icons)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) => Padding(
                      padding: const EdgeInsets.only(left: 1),
                      child: Icon(
                        i < fullInt
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size:  13,
                        color: i < fullInt
                            ? AppColors.primaryOrange
                            : AppColors.border,
                      ),
                    )),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.primaryOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Row 2: stay chips ────────────────────────────────────────
          if (duration.isNotEmpty || t.amountPaid > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (duration.isNotEmpty)
                  _ReviewChip(
                    icon:  Icons.nights_stay_outlined,
                    label: duration,
                  ),
                if (t.checkIn != null && t.checkOut != null)
                  _ReviewChip(
                    icon:  Icons.calendar_today_outlined,
                    label: '${_fmtDate(t.checkIn)} – ${_fmtDate(t.checkOut)}',
                  ),
                if (t.amountPaid > 0)
                  _ReviewChip(
                    icon:  Icons.payments_outlined,
                    label: _fmtPrice(t.amountPaid),
                    faint: true,
                  ),
              ],
            ),
          ],

          // ── Row 3: divider ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
                height: 1,
                thickness: 0.8,
                color: AppColors.border),
          ),

          // ── Row 4: comment with animated expand ──────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(t.comment,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    color:    AppColors.textMid,
                    height:   1.6)),
            secondChild: Text(t.comment,
                style: const TextStyle(
                    fontSize: 13.5,
                    color:    AppColors.textMid,
                    height:   1.6)),
          ),

          // Read more / less toggle
          if (t.comment.length > 120)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _expanded ? 'Show less' : 'Read more',
                  style: const TextStyle(
                    color:      AppColors.primaryOrange,
                    fontWeight: FontWeight.w600,
                    fontSize:   12.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Initials avatar fallback ──────────────────────────────────────────────────

class _InitialsAvatar extends StatelessWidget {
  final String name;
  const _InitialsAvatar({required this.name});

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.orangeLight,
        child: Center(
          child: Text(
            _initials,
            style: const TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w800,
              color:      AppColors.primaryOrange,
            ),
          ),
        ),
      );
}

// ── Small info chip used inside review cards ──────────────────────────────────

class _ReviewChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     faint;

  const _ReviewChip({
    required this.icon,
    required this.label,
    this.faint = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: faint
              ? AppColors.border.withOpacity(.5)
              : AppColors.orangeLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size:  11,
              color: faint
                  ? AppColors.textLight
                  : AppColors.primaryOrange),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w600,
                color: faint
                    ? AppColors.textLight
                    : AppColors.primaryOrange,
              )),
        ]),
      );
}
// ════════════════════════════════════════════════════════════════════════════
//  ROOM SELECTION BOTTOM SHEET
//  • AnimatedContainer tile bg + border
//  • Animated radio check
//  • Animated CTA button
// ════════════════════════════════════════════════════════════════════════════

class _RoomSelectionSheet extends StatefulWidget {
  final ApartmentModel          apt;
  final List<RoomOffer>         rooms;
  final ValueChanged<RoomOffer> onConfirm;
  const _RoomSelectionSheet(
      {required this.apt,
      required this.rooms,
      required this.onConfirm});

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
        color:         AppColors.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(.14),
              blurRadius: 30,
              offset:     const Offset(0, -6)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width:  40,
              height: 4,
              decoration: BoxDecoration(
                  color:         AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          Text('Select a Room',
              style: TextStyle(
                fontSize:      19,
                fontWeight:    FontWeight.w800,
                color:         AppColors.text(context),
                letterSpacing: -.4,
              )),
          const SizedBox(height: 4),
          Text(
            "Choose the room type you'd like to rent at ${widget.apt.name}",
            style: const TextStyle(fontSize: 13, color: AppColors.textMid),
          ),

          const SizedBox(height: 16),

          if (widget.rooms.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(children: const [
                  Icon(Icons.do_not_disturb_on_outlined,
                      size: 40, color: AppColors.textLight),
                  SizedBox(height: 8),
                  Text('No rooms available right now',
                      style: TextStyle(
                          color:      AppColors.textMid,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            )
          else
            ...widget.rooms.map((room) {
              final sel = _selected?.id == room.id;
              return GestureDetector(
                onTap: () => setState(() => _selected = room),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve:    Curves.easeOutCubic,
                  margin:   const EdgeInsets.only(bottom: 10),
                  padding:  const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.orangeLight
                        : AppColors.background(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: sel
                          ? AppColors.primaryOrange
                          : AppColors.border,
                      width: sel ? 1.5 : 1,
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                              color:      AppColors.primaryOrange
                                  .withOpacity(.12),
                              blurRadius: 12,
                              offset:     const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Row(children: [

                    // animated radio circle
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width:  22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sel
                            ? AppColors.primaryOrange
                            : Colors.transparent,
                        border: Border.all(
                            color: sel
                                ? AppColors.primaryOrange
                                : AppColors.textLight,
                            width: 1.5),
                      ),
                      child: sel
                          ? const Icon(Icons.check_rounded,
                              size: 13, color: Colors.white)
                          : null,
                    ),

                    const SizedBox(width: 12),

                    // info
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(room.roomType,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize:   14.5,
                                  color: sel
                                      ? AppColors.primaryOrange
                                      : AppColors.text(context),
                                )),
                            const SizedBox(height: 2),
                            Text(
                              '${room.availableUnits} unit${room.availableUnits == 1 ? '' : 's'} · '
                              'max ${room.maxOccupants} pax · ${room.genderRestriction}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMid),
                            ),
                          ]),
                    ),

                    // price + fees
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            '₱${_fmt(room.activePrice)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize:   14.5,
                              color: sel
                                  ? AppColors.primaryOrange
                                  : AppColors.text(context),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            room.pricingMode == 'daily' ? '/day' : '/mo',
                            style: TextStyle(
                                fontSize: 11,
                                color: sel
                                    ? AppColors.primaryOrange
                                    : AppColors.textMid),
                          ),
                        ]),
                        if ((double.tryParse(room.serviceFee) ?? 0) > 0) ...[
                          const SizedBox(height: 2),
                          Text('+ ₱${_fmt(double.parse(room.serviceFee))} service fee',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textLight)),
                        ],
                        if ((double.tryParse(room.securityDeposit) ?? 0) >
                            0) ...[
                          const SizedBox(height: 2),
                          Text('₱${_fmt(double.parse(room.securityDeposit))} refundable deposit',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textLight)),
                        ],
                      ],
                    ),
                  ]),
                ),
              );
            }),

          const SizedBox(height: 8),

          // Animated CTA
          _CTAButton(
            enabled: _selected != null,
            label: _selected == null
                ? 'Select a room to continue'
                : 'Proceed to Book',
            onTap: () {
              if (_selected != null) widget.onConfirm(_selected!);
            },
          ),
        ],
      ),
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
//  ANIMATED CTA BUTTON  — gradient, press-scale, disabled state
// ════════════════════════════════════════════════════════════════════════════

class _CTAButton extends StatefulWidget {
  final bool         enabled;
  final String       label;
  final VoidCallback onTap;
  const _CTAButton(
      {required this.enabled,
      required this.label,
      required this.onTap});

  @override
  State<_CTAButton> createState() => _CTAButtonState();
}

class _CTAButtonState extends State<_CTAButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   widget.enabled ? (_) => setState(() => _scale = .97) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _scale = 1.0);
              widget.onTap();
            }
          : null,
      onTapCancel: widget.enabled ? () => setState(() => _scale = 1.0) : null,
      child: AnimatedScale(
        scale:    _scale,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width:    double.infinity,
          height:   54,
          decoration: BoxDecoration(
            gradient: widget.enabled
                ? const LinearGradient(
                    colors: [Color(0xFFFF8C00), AppColors.primaryOrange],
                    begin:  Alignment.centerLeft,
                    end:    Alignment.centerRight,
                  )
                : null,
            color:         widget.enabled ? null : AppColors.border,
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color:      AppColors.primaryOrange.withOpacity(.35),
                      blurRadius: 18,
                      offset:     const Offset(0, 6),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize:   15,
                fontWeight: FontWeight.w700,
                color:      widget.enabled
                    ? Colors.white
                    : AppColors.textMid,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
//  BOTTOM BAR  — frosted card, gradient CTA
// ════════════════════════════════════════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  final ApartmentModel          apt;
  final List<RoomOffer>         rooms;
  final String Function(double) fmt;
  final VoidCallback            onRent;
  const _BottomBar({
    required this.apt,
    required this.rooms,
    required this.fmt,
    required this.onRent,
  });

  @override
  Widget build(BuildContext context) {
    final available = rooms.where((r) {
  final units = int.tryParse(r.availableUnits) ?? 0;
  return units > 0;
}).toList();

    RoomOffer? cheapest;
    if (available.isNotEmpty) {
      cheapest = available
          .reduce((a, b) => a.activePrice < b.activePrice ? a : b);
    }

    final displayPrice =
        cheapest != null ? cheapest.activePrice : apt.minPrice;
    final hasRooms = available.isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(.07),
              blurRadius: 16,
              offset:     const Offset(0, -3)),
        ],
      ),
      child: Row(children: [

        // from-price column
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'from ₱${fmt(displayPrice)}',
              style: const TextStyle(
                color:      AppColors.primaryOrange,
                fontSize:   20,
                fontWeight: FontWeight.w900,
                letterSpacing: -.4,
              ),
            ),
            Text(
              cheapest?.pricingMode == 'daily' ? '/day' : '/month',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textLight),
            ),
          ],
        ),

        const SizedBox(width: 16),

        Expanded(
          child: _CTAButton(
            enabled: hasRooms,
            label:   hasRooms ? 'Rent Now' : 'Unavailable',
            onTap:   onRent,
          ),
        ),
      ]),
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
//  FULLSCREEN GALLERY  — animated dot indicator (logic unchanged)
// ════════════════════════════════════════════════════════════════════════════

class FullscreenGalleryPage extends StatefulWidget {
  final List<String> images;
  const FullscreenGalleryPage({Key? key, required this.images})
      : super(key: key);

  @override
  State<FullscreenGalleryPage> createState() =>
      _FullscreenGalleryPageState();
}

class _FullscreenGalleryPageState extends State<FullscreenGalleryPage> {
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
      body: Stack(children: [

        PageView.builder(
          controller:    _controller,
          itemCount:     widget.images.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(widget.images[i],
                  fit: BoxFit.contain),
            ),
          ),
        ),

        // close button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width:  40,
                height: 40,
                decoration: BoxDecoration(
                    color:         Colors.black54,
                    borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
        ),

        // counter + animated dots
        Positioned(
          bottom: 40, left: 0, right: 0,
          child: Column(children: [
            Text('${_index + 1} / ${widget.images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.images.length > 10 ? 10 : widget.images.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  margin:   const EdgeInsets.symmetric(horizontal: 3),
                  width:    i == _index ? 18 : 5,
                  height:   5,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppColors.primaryOrange
                        : Colors.white.withOpacity(.40),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}