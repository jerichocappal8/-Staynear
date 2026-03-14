// all_apartments_screen.dart
// ════════════════════════════════════════════════════════════════════════════
//  StayNear — All Apartments Screen  (UI redesign, all logic unchanged)
//  • Firestore query: unchanged
//  • Navigation: unchanged
//  • Delete + Edit logic: unchanged
//  • Price field: removed from UI per requirements
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'edit_apartment_screen.dart';
import 'package:staynear/core/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AllApartmentsScreen extends StatefulWidget {
  const AllApartmentsScreen({super.key});

  @override
  State<AllApartmentsScreen> createState() => _AllApartmentsScreenState();
}

class _AllApartmentsScreenState extends State<AllApartmentsScreen>
    with SingleTickerProviderStateMixin {

  // ── original logic (unchanged) ─────────────────────────────────────────────
  String get uid => FirebaseAuth.instance.currentUser!.uid;

  // ── list entrance animation ────────────────────────────────────────────────
  late final AnimationController _listCtrl;
  late final Animation<double>   _listFade;

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 480),
    )..forward();
    _listFade = CurvedAnimation(parent: _listCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  // ─── original Firestore stream (unchanged) ─────────────────────────────────
  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('properties')
      .where('ownerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots();

  // ─── original delete logic (unchanged) ────────────────────────────────────
  Future<void> _handleDelete(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteDialog(context: ctx),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(id)
          .delete();
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Column(
        children: [

          // ── header ─────────────────────────────────────────────────────────
          _Header(onBack: () => Navigator.pop(context)),

          // ── list ───────────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _stream,
              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryOrange, strokeWidth: 2.5),
                  );
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) return const _EmptyState();

                return FadeTransition(
                  opacity: _listFade,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    physics: const BouncingScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc  = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      // staggered per-item delay via TweenAnimationBuilder
                      return TweenAnimationBuilder<double>(
                        tween:    Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 340 + index * 60),
                        curve:    Curves.easeOutCubic,
                        builder: (_, v, child) => Opacity(
                          opacity: v,
                          child:   Transform.translate(
                            offset: Offset(0, 18 * (1 - v)),
                            child:  child,
                          ),
                        ),
                        child: _ApartmentCard(
                          id:       doc.id,
                          data:     data,
                          onEdit: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditApartmentScreen(
                                docId: doc.id,
                                data:  data,
                              ),
                            ),
                          ),
                          onDelete: () => _handleDelete(context, doc.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HEADER
// ═════════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            // back button
            GestureDetector(
              onTap: onBack,
              child: Container(
                width:  40,
                height: 40,
                decoration: BoxDecoration(
                  color:         AppColors.card(context),
                  borderRadius: BorderRadius.circular(12),
                  border:        Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                        color:      Colors.black.withOpacity(.04),
                        blurRadius: 10,
                        offset:     const Offset(0, 3)),
                  ],
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: AppColors.text(context)),
              ),
            ),

            // title
            Expanded(
              child: Center(
                child: Text(
                  'All Apartments',
                  style: TextStyle(
                    fontSize:      18,
                    fontWeight:    FontWeight.w800,
                    color:         AppColors.text(context),
                    letterSpacing: -.3,
                  ),
                ),
              ),
            ),

            // balance spacer (mirrors back button width)
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  APARTMENT CARD
// ═════════════════════════════════════════════════════════════════════════════

class _ApartmentCard extends StatelessWidget {
  final String              id;
  final Map<String, dynamic> data;
  final VoidCallback        onEdit;
  final VoidCallback        onDelete;

  const _ApartmentCard({
    required this.id,
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name     = (data['name']     ?? 'Unnamed').toString();
    final location = (data['location'] ?? data['address'] ?? '').toString();
    final isActive = (data['isActive'] ?? false) == true;
    final status   = (data['status']   ?? (isActive ? 'active' : 'inactive'))
        .toString();
    final statusActive = status.toLowerCase() == 'active' || isActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color:         AppColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border:        Border.all(color: AppColors.border.withOpacity(.6)),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(.05),
              blurRadius: 18,
              offset:     const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── row 1: name + status pill ──────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // icon container
                Container(
                  width:  48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusActive
                        ? AppColors.primaryOrange.withOpacity(.10)
                        : AppColors.border.withOpacity(.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.apartment_rounded,
                    size:  22,
                    color: statusActive
                        ? AppColors.primaryOrange
                        : AppColors.textLight,
                  ),
                ),

                const SizedBox(width: 12),

                // name + location
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize:   16,
                          fontWeight: FontWeight.w800,
                          color:      AppColors.text(context),
                          letterSpacing: -.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: AppColors.textLight),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              location,
                              style: const TextStyle(
                                  fontSize:   12.5,
                                  color:      AppColors.textMid),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // status pill
                _StatusBadge(active: statusActive),
              ],
            ),

            const SizedBox(height: 16),

            // ── divider ────────────────────────────────────────────────
            Container(height: 1, color: AppColors.border.withOpacity(.6)),

            const SizedBox(height: 14),

            // ── row 2: edit + delete buttons ──────────────────────────
            Row(children: [
              Expanded(child: _EditButton(onTap: onEdit)),
              const SizedBox(width: 10),
              Expanded(child: _DeleteButton(onTap: onDelete)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATUS BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? green.withOpacity(.12)
            : AppColors.border.withOpacity(.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width:  6,
          height: 6,
          decoration: BoxDecoration(
            color:  active ? green : AppColors.textLight,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          active ? 'ACTIVE' : 'INACTIVE',
          style: TextStyle(
            fontSize:   10,
            fontWeight: FontWeight.w800,
            color:      active ? const Color(0xFF059669) : AppColors.textMid,
            letterSpacing: .3,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EDIT BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _EditButton extends StatefulWidget {
  final VoidCallback onTap;
  const _EditButton({required this.onTap});

  @override
  State<_EditButton> createState() => _EditButtonState();
}

class _EditButtonState extends State<_EditButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) { setState(() => _scale = .96); HapticFeedback.lightImpact(); },
      onTapUp:     (_) { setState(() => _scale = 1.0); widget.onTap(); },
      onTapCancel: ()  { setState(() => _scale = 1.0); },
      child: AnimatedScale(
        scale:    _scale,
        duration: const Duration(milliseconds: 110),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color:         AppColors.card(context),
            borderRadius: BorderRadius.circular(14),
            border:        Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_rounded,
                  size: 15, color: AppColors.text(context)),
              const SizedBox(width: 6),
              Text(
                'Edit',
                style: TextStyle(
                  fontSize:   13.5,
                  fontWeight: FontWeight.w700,
                  color:      AppColors.text(context),
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
//  DELETE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteButton extends StatefulWidget {
  final VoidCallback onTap;
  const _DeleteButton({required this.onTap});

  @override
  State<_DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<_DeleteButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) { setState(() => _scale = .96); HapticFeedback.lightImpact(); },
      onTapUp:     (_) { setState(() => _scale = 1.0); widget.onTap(); },
      onTapCancel: ()  { setState(() => _scale = 1.0); },
      child: AnimatedScale(
        scale:    _scale,
        duration: const Duration(milliseconds: 110),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color:         AppColors.danger.withOpacity(.10),
            borderRadius: BorderRadius.circular(14),
            border:        Border.all(
                color: AppColors.danger.withOpacity(.25), width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.delete_outline_rounded,
                  size: 15, color: AppColors.danger),
              SizedBox(width: 6),
              Text(
                'Delete',
                style: TextStyle(
                  fontSize:   13.5,
                  fontWeight: FontWeight.w700,
                  color:      AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DELETE CONFIRMATION DIALOG  (logic unchanged)
// ═════════════════════════════════════════════════════════════════════════════

class _DeleteDialog extends StatelessWidget {
  final BuildContext context;
  const _DeleteDialog({required this.context});

  @override
  Widget build(BuildContext outerCtx) {
    return Dialog(
      backgroundColor: AppColors.card(outerCtx),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // danger icon
            Container(
              width:  64,
              height: 64,
              decoration: BoxDecoration(
                color:  AppColors.danger.withOpacity(.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 30, color: AppColors.danger),
            ),

            const SizedBox(height: 18),

            Text(
              'Delete Apartment',
              style: TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.w800,
                color:      AppColors.text(outerCtx),
                letterSpacing: -.3,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Are you sure you want to delete this apartment? This action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, color: AppColors.textMid, height: 1.5),
            ),

            const SizedBox(height: 24),

            Row(children: [

              // cancel
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color:         AppColors.border.withOpacity(.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.w700,
                          color:      AppColors.text(outerCtx),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // confirm delete
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, true),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color:         AppColors.danger,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color:      AppColors.danger.withOpacity(.35),
                          blurRadius: 14,
                          offset:     const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.w700,
                          color:      Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  EMPTY STATE
// ═════════════════════════════════════════════════════════════════════════════

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
              width:  80,
              height: 80,
              decoration: const BoxDecoration(
                  color: AppColors.orangeLight, shape: BoxShape.circle),
              child: const Icon(Icons.apartment_rounded,
                  size: 36, color: AppColors.primaryOrange),
            ),
            const SizedBox(height: 20),
            Text(
              'No apartments yet',
              style: TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.w700,
                color:      AppColors.text(context),
                letterSpacing: -.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first property from the Host Dashboard to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, color: AppColors.textMid, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}