import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:staynear/core/app_colors.dart';
import 'tenant_list_screen.dart';

class PropertyManagementScreen extends StatelessWidget {
  final String propertyId;
  final String propertyName;
  final Map<String, dynamic> propertyData;

  const PropertyManagementScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
    required this.propertyData,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = propertyData['status'] == 'active';

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.text(context), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              propertyName,
              style: TextStyle(
                color: AppColors.text(context),
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
            const Text(
              "Property Management",
              style: TextStyle(
                  color: AppColors.textMid,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border.withOpacity(0.4)),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _PropertySummaryHeader(
              data: propertyData,
              propertyId: propertyId,
              isActive: isActive,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: _SectionTitle(
                icon: Icons.meeting_room_rounded,
                label: "Rooms & Units",
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _RoomsList(propertyId: propertyId),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PROPERTY SUMMARY HEADER
// ─────────────────────────────────────────────────────────
class _PropertySummaryHeader extends StatelessWidget {
  final Map<String, dynamic> data;
  final String propertyId;
  final bool isActive;

  const _PropertySummaryHeader({
    required this.data,
    required this.propertyId,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _PropertyThumb(data: data),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? "Property",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text(context),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 11, color: AppColors.primaryOrange),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        data['location'] ?? "",
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMid,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StreamPriceTag(propertyId: propertyId),
                    const SizedBox(width: 8),
                    _OccupancySummary(propertyId: propertyId),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF22C55E) : AppColors.danger,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyThumb extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PropertyThumb({required this.data});

  @override
  Widget build(BuildContext context) {
    final image = (data['images'] != null &&
            (data['images'] as List).isNotEmpty)
        ? data['images'][0] as String
        : null;
    if (image != null) {
      return Image.network(image,
          width: 64, height: 64, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(context));
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) => Container(
        width: 64,
        height: 64,
        color: AppColors.cardSoft(context),
        child: const Icon(Icons.apartment_rounded,
            color: AppColors.primaryOrange, size: 26),
      );
}

class _OccupancySummary extends StatelessWidget {
  final String propertyId;
  const _OccupancySummary({required this.propertyId});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Text("");

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('room_occupancy')
          .where('apartmentId', isEqualTo: propertyId)
          .where('hostId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        final all = snap.data?.docs ?? [];
        final total = all.length;
        final occupied = all
            .where((d) => (d.data() as Map)['status'] == 'occupied')
            .length;
        return Text(
          "$occupied/$total occupied",
          style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMid,
              fontWeight: FontWeight.w600),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// ROOMS LIST
// ─────────────────────────────────────────────────────────
class _RoomsList extends StatelessWidget {
  final String propertyId;
  const _RoomsList({required this.propertyId});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('room_occupancy')
          .where('apartmentId', isEqualTo: propertyId)
          .where('hostId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(
                  color: AppColors.primaryOrange, strokeWidth: 2),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _EmptyRooms(),
          );
        }

        final allDocs = snapshot.data!.docs;

        // Group by roomType
        final Map<String, List<QueryDocumentSnapshot>> grouped = {};
        for (final doc in allDocs) {
          final d = doc.data() as Map<String, dynamic>;
          final roomType = d['roomType'] as String? ?? 'Standard Room';
          grouped.putIfAbsent(roomType, () => []).add(doc);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: grouped.entries
                .map((entry) => _RoomTypeCard(
                      roomType: entry.key,
                      occupancyDocs: entry.value,
                      propertyId: propertyId,
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// ROOM TYPE CARD
// ─────────────────────────────────────────────────────────
class _RoomTypeCard extends StatefulWidget {
  final String roomType;
  final List<QueryDocumentSnapshot> occupancyDocs;
  final String propertyId;

  const _RoomTypeCard({
    required this.roomType,
    required this.occupancyDocs,
    required this.propertyId,
  });

  @override
  State<_RoomTypeCard> createState() => _RoomTypeCardState();
}

class _RoomTypeCardState extends State<_RoomTypeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final occupied = widget.occupancyDocs
        .where((d) => (d.data() as Map)['status'] == 'occupied')
        .length;
    final total = widget.occupancyDocs.length;
    final ratio = total > 0 ? occupied / total : 0.0;

    final Color barColor;
    if (ratio >= 0.8) {
      barColor = const Color(0xFF22C55E);
    } else if (ratio >= 0.4) {
      barColor = AppColors.primaryOrange;
    } else {
      barColor = AppColors.danger;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // HEADER
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(20),
              bottom: Radius.circular(_expanded ? 0 : 20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.meeting_room_rounded,
                            size: 18, color: AppColors.primaryOrange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.roomType,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                      color: barColor,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "$occupied / $total Occupied",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMid,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textMid, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 5,
                      backgroundColor: AppColors.cardSoft(context),
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // EXPANDABLE CONTENT
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(
                    height: 1,
                    color: AppColors.border.withOpacity(0.4)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "TENANTS",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textLight,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TenantListScreen(
                                    roomType: widget.roomType,
                                    occupancyDocs: widget.occupancyDocs,
                                    propertyId: widget.propertyId,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.primaryOrange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "View All →",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryOrange,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (occupied == 0)
                        _EmptyTenantRow()
                      else
                        ...widget.occupancyDocs
                            .where((d) =>
                                (d.data() as Map)['status'] == 'occupied')
                            .take(2)
                            .map((d) => _TenantPreviewRow(doc: d)),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// TENANT PREVIEW ROW
// ─────────────────────────────────────────────────────────
class _TenantPreviewRow extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _TenantPreviewRow({required this.doc});

  String _fmt(dynamic v) {
    if (v == null) return "—";
    if (v is Timestamp) {
      final d = v.toDate();
      const m = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return "${m[d.month - 1]} ${d.day}";
    }
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final name = d['guestName'] ?? "Unknown";
    final checkIn = _fmt(d['checkIn']);
    final checkOut = _fmt(d['checkOut']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardSoft(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryOrange.withOpacity(0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : "?",
              style: const TextStyle(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            "$checkIn → $checkOut",
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textMid,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTenantRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSoft(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.person_off_rounded,
              size: 14, color: AppColors.textLight),
          SizedBox(width: 8),
          Text("No tenants in this room",
              style: TextStyle(
                  color: AppColors.textMid,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.meeting_room_rounded,
              size: 32, color: AppColors.textLight),
          const SizedBox(height: 10),
          Text("No rooms found",
              style: TextStyle(
                  color: AppColors.text(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text("Room occupancy data will appear here",
              style: TextStyle(color: AppColors.textLight, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// SECTION TITLE
// ─────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primaryOrange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 15, color: AppColors.primaryOrange),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.text(context),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
class _StreamPriceTag extends StatelessWidget {
  final String propertyId;

  const _StreamPriceTag({required this.propertyId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('properties')
          .doc(propertyId)
          .collection('rooms')
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _priceChip("₱0 / mo");
        }

        final room = snap.data!.docs.first.data() as Map<String, dynamic>;

        final pricingMode = room['pricingMode'] ?? 'monthly';

        final price = pricingMode == 'daily'
            ? room['priceDaily'] ?? 0
            : room['priceMonthly'] ?? 0;

        final label = pricingMode == 'daily' ? "/ day" : "/ mo";

        return _priceChip("₱$price $label");
      },
    );
  }

  Widget _priceChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryOrange,
        ),
      ),
    );
  }
}
