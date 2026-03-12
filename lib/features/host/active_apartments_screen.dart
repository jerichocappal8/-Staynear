import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:staynear/core/app_colors.dart';
import 'presentation/property_management_screen.dart';

class ActiveApartmentsScreen extends StatelessWidget {
  const ActiveApartmentsScreen({super.key});

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('properties')
        .where('ownerId', isEqualTo: uid)
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        centerTitle: true,
        title: Text(
          "My Listings",
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.4,
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.text(context)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border.withOpacity(0.4)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryOrange,
                strokeWidth: 2,
              ),
            );
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const _EmptyState();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _PropertyCard(
                doc: doc,
                data: data,
                propertyId: doc.id,
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.apartment_rounded,
                  size: 38, color: AppColors.primaryOrange),
            ),
            const SizedBox(height: 20),
            Text(
              "No listings yet",
              style: TextStyle(
                color: AppColors.text(context),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Add your first property to start\nmanaging your rentals",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMid,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PROPERTY CARD — Level 1
// ─────────────────────────────────────────────────────────
class _PropertyCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final String propertyId;

  const _PropertyCard({
    required this.doc,
    required this.data,
    required this.propertyId,
  });

  @override
  Widget build(BuildContext context) {
    final image = (data['images'] != null &&
            (data['images'] as List).isNotEmpty)
        ? data['images'][0] as String
        : null;
    final isActive = (data['isActive'] ?? true) == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HERO IMAGE
          _PropertyImage(image: image, isActive: isActive),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NAME + STATUS badge (no-image fallback)
                if (image == null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          data['name'] ?? "Unnamed Property",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text(context),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusPill(isActive: isActive),
                    ],
                  )
                else
                  Text(
                    data['name'] ?? "Unnamed Property",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text(context),
                      letterSpacing: -0.3,
                    ),
                  ),

                const SizedBox(height: 5),

                // LOCATION
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 12, color: AppColors.primaryOrange),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        data['location'] ?? "No location",
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMid,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // PRICE + STATS
                Row(
                  children: [
                    _StreamPriceTag(propertyId: propertyId),
                    const SizedBox(width: 8),
                    _MiniStat(
                        icon: Icons.visibility_rounded,
                        label: "${data['views'] ?? 0}"),
                    const SizedBox(width: 6),
                    _MiniStat(
                        icon: Icons.chat_bubble_rounded,
                        label: "${data['inquiries'] ?? 0}"),
                    const Spacer(),
                    _OccupiedCountBadge(propertyId: propertyId),
                  ],
                ),

                const SizedBox(height: 14),

                // OCCUPANCY BAR
                _OccupancyBar(propertyId: propertyId),

                const SizedBox(height: 18),

                // MANAGE BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PropertyManagementScreen(
                            propertyId: propertyId,
                            propertyName: data['name'] ?? "Property",
                            propertyData: data,
                          ),
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Manage Property",
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // TOGGLE ACTIVE
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.border.withOpacity(0.7)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('properties')
                          .doc(doc.id)
                          .update({
                        "isActive": !isActive
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isActive
                              ? Icons.pause_circle_rounded
                              : Icons.play_circle_rounded,
                          size: 16,
                          color: isActive
                              ? AppColors.textMid
                              : AppColors.primaryOrange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isActive ? "Pause Listing" : "Activate Listing",
                          style: TextStyle(
                            color: isActive
                                ? AppColors.textMid
                                : AppColors.primaryOrange,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PROPERTY IMAGE HERO
// ─────────────────────────────────────────────────────────
class _PropertyImage extends StatelessWidget {
  final String? image;
  final bool isActive;
  const _PropertyImage({required this.image, required this.isActive});

  @override
  Widget build(BuildContext context) {
    if (image == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Stack(
        children: [
          Image.network(
            image!,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 180,
              color: AppColors.cardSoft(context),
              child: const Icon(Icons.image_not_supported_rounded,
                  color: AppColors.textMid, size: 40),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: _StatusPill(isActive: isActive),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// STATUS PILL
// ─────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final bool isActive;
  const _StatusPill({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF22C55E) : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 5,
              height: 5,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            isActive ? "ACTIVE" : "INACTIVE",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// MINI STAT CHIP
// ─────────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardSoft(context),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 11, color: AppColors.textMid),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMid)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// OCCUPIED COUNT BADGE
// ─────────────────────────────────────────────────────────
class _OccupiedCountBadge extends StatelessWidget {
  final String propertyId;
  const _OccupiedCountBadge({required this.propertyId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('room_occupancy')
          .where('apartmentId', isEqualTo: propertyId)
          .where('status', isEqualTo: 'occupied')
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        final greenColor = const Color(0xFF22C55E);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: count > 0
                ? greenColor.withOpacity(0.12)
                : AppColors.cardSoft(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: count > 0
                  ? greenColor.withOpacity(0.3)
                  : AppColors.border.withOpacity(0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.person_rounded,
                  size: 12,
                  color: count > 0 ? greenColor : AppColors.textMid),
              const SizedBox(width: 4),
              Text(
                "$count Occupied",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: count > 0 ? greenColor : AppColors.textMid,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// OCCUPANCY PROGRESS BAR
// ─────────────────────────────────────────────────────────
class _OccupancyBar extends StatelessWidget {
  final String propertyId;
  const _OccupancyBar({required this.propertyId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('room_occupancy')
          .where('apartmentId', isEqualTo: propertyId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final all = snap.data!.docs;
        final total = all.length;
        if (total == 0) return const SizedBox.shrink();
        final occupied = all
            .where((d) => (d.data() as Map)['status'] == 'occupied')
            .length;
        final ratio = occupied / total;
        final Color barColor;
        if (ratio >= 0.8) {
          barColor = const Color(0xFF22C55E);
        } else if (ratio >= 0.4) {
          barColor = AppColors.primaryOrange;
        } else {
          barColor = AppColors.danger;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Occupancy",
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMid,
                        fontWeight: FontWeight.w600)),
                Text("$occupied / $total rooms",
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMid,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: AppColors.cardSoft(context),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        );
      },
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