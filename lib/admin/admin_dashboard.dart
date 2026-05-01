// admin_dashboard.dart
// ════════════════════════════════════════════════════════════════════════════
//  StayNear — Admin Dashboard  (UI redesign, all Firestore logic unchanged)
//
//  _approve() and _reject() are byte-for-byte identical to the original.
//  The Firestore stream, query, and address parsing are also unchanged.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staynear/admin/host_request_details_screen.dart';

import 'package:staynear/core/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:staynear/features/auth/auth_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {

  // ── list entrance animation ────────────────────────────────────────────────
  late final AnimationController _listCtrl;
  late final Animation<double>   _listFade;

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 460),
    )..forward();
    _listFade = CurvedAnimation(parent: _listCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  APPROVE HOST  (logic unchanged)
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _approve(String uid) async {
    await FirebaseFirestore.instance
        .collection('host_requests')
        .doc(uid)
        .update({'status': 'approved'});

    await FirebaseFirestore.instance
        .collection('hosts')
        .doc(uid)
        .set({
          'userId':         uid,
          'rating':         0,
          'totalListings':  0,
          'createdAt':      FieldValue.serverTimestamp(),
        });

    // 🔥 THIS IS THE IMPORTANT PART
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
          'hostRequest': 'approved',
          'role':         'host',
          'isHost':      true, // 👈 unlocks host dashboard
        });
  }

  // ════════════════════════════════════════════════════════════════════════
  //  REJECT HOST  (logic unchanged)
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _reject(String uid) async {
    await FirebaseFirestore.instance
        .collection('host_requests')
        .doc(uid)
        .update({'status': 'rejected'});

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
          'hostRequest': 'rejected',
          'role':         'user',
          'isHost':      false,
        });
  }

  // ── confirmation dialogs ──────────────────────────────────────────────────

  Future<void> _confirmApprove(BuildContext ctx, String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => _ConfirmDialog(
        name:      name,
        action:    'approve',
        message:   'Approving this request will grant $name full host access on StayNear.',
        confirmLabel: 'Approve',
        confirmColor: const Color(0xFF10B981),
      ),
    );
    if (confirmed == true) await _approve(uid);
  }

  Future<void> _confirmReject(BuildContext ctx, String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => _ConfirmDialog(
        name:      name,
        action:    'reject',
        message:   'Rejecting this request will deny $name from becoming a host.',
        confirmLabel: 'Reject',
        confirmColor: AppColors.danger,
      ),
    );
    if (confirmed == true) await _reject(uid);
  }

Future<void> _logout() async {
  await FirebaseAuth.instance.signOut();

  if (!mounted) return;

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => const AuthScreen(isLogin: true),
    ),
    (route) => false,
  );
}
  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: _buildAppBar(context, isDark),
      body: StreamBuilder<QuerySnapshot>(
        // ── original Firestore stream (unchanged) ──────────────────────
        stream: FirebaseFirestore.instance
            .collection('host_requests')
            .orderBy('submittedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return _LoadingState();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const _EmptyState();
          }

          final requests = snapshot.data!.docs;

          return FadeTransition(
            opacity: _listFade,
            child: ListView.builder(
              padding:   const EdgeInsets.fromLTRB(20, 8, 20, 32),
              physics:   const BouncingScrollPhysics(),
              itemCount: requests.length,
              itemBuilder: (_, i) {
                final doc  = requests[i];
                final data = doc.data() as Map<String, dynamic>;

                // ── original address parsing (unchanged) ─────────────
                final address  = data['address'];
                String city    = '';
                String province = '';

                if (address is Map<String, dynamic>) {
                  city     = address['city']     ?? '';
                  province = address['province'] ?? '';
                } else if (address is String) {
                  city = address;
                }

                final name   = data['fullName'] ?? 'No name';
                final status = (data['status']  ?? 'pending').toString();

                return TweenAnimationBuilder<double>(
                  tween:    Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 320 + i * 60),
                  curve:    Curves.easeOutCubic,
                  builder: (_, v, child) => Opacity(
                    opacity: v,
                    child:   Transform.translate(
                        offset: Offset(0, 16 * (1 - v)), child: child),
                  ),
                  child: _RequestCard(
                    docId:    doc.id,
                    name:     name,
                    city:     city,
                    province: province,
                    status:   status,
                    photo:    data['photo'],
                    email:    data['email'],
                    onApprove: status == 'pending'
                        ? () => _confirmApprove(context, doc.id, name)
                        : null,
                    onReject: status == 'pending'
                        ? () => _confirmReject(context, doc.id, name)
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ── app bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      backgroundColor:        AppColors.background(context),
      surfaceTintColor:       Colors.transparent,
      scrolledUnderElevation: 0,
      elevation:              0,
      automaticallyImplyLeading: false,
      title: Text(
        'Host Requests',
        style: TextStyle(
          fontSize:      22,
          fontWeight:    FontWeight.w900,
          color:         AppColors.text(context),
          letterSpacing: -.5,
        ),
      ),
actions: [

  // Admin badge
  Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.orangeLight,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: const [
      Icon(Icons.admin_panel_settings_rounded,
          size: 13, color: AppColors.primaryOrange),
      SizedBox(width: 5),
      Text(
        'Admin',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryOrange,
        ),
      ),
    ]),
  ),

  // Logout button
  IconButton(
    tooltip: 'Logout',
    icon: const Icon(Icons.logout_rounded),
    color: AppColors.text(context),
    onPressed: _logout,
  ),

  const SizedBox(width: 8),
],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: isDark
              ? AppColors.darkCardSoft.withOpacity(.4)
              : AppColors.border,
          height: 1,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  REQUEST CARD
// ═════════════════════════════════════════════════════════════════════════════

class _RequestCard extends StatelessWidget {
  final String    docId;
  final String    name;
  final String    city;
  final String    province;
  final String    status;
  final dynamic   photo;
  final dynamic   email;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _RequestCard({
    required this.docId,
    required this.name,
    required this.city,
    required this.province,
    required this.status,
    required this.photo,
    required this.email,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final location = [city, province].where((s) => s.isNotEmpty).join(', ');

return GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HostRequestDetailsScreen(userId: docId),
      ),
    );
  },
  child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color:         AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border:        Border.all(
            color: isDark
                ? AppColors.darkCardSoft.withOpacity(.5)
                : AppColors.border),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(isDark ? .10 : .04),
            blurRadius: 16,
            offset:     const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── top row: avatar + name + status ──────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // avatar
                _Avatar(name: name, photo: photo),

                const SizedBox(width: 12),

                // name + location + email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize:      16,
                          fontWeight:    FontWeight.w800,
                          color:         AppColors.text(context),
                          letterSpacing: -.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: AppColors.textLight),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              location,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.textMid),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ],
                      if (email != null && email.toString().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.email_outlined,
                              size: 12, color: AppColors.textLight),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              email.toString(),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMid),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // status badge
                _StatusBadge(status: status),
              ],
            ),

            // ── divider ───────────────────────────────────────────────
            if (onApprove != null || onReject != null) ...[
              const SizedBox(height: 14),
              Container(height: 1, color: AppColors.border.withOpacity(.6)),
              const SizedBox(height: 14),

              // ── action buttons ────────────────────────────────────
              Row(children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Approve',
                    icon:  Icons.check_circle_rounded,
                    color: const Color(0xFF10B981),
                    onTap: onApprove,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: 'Reject',
                    icon:  Icons.cancel_rounded,
                    color: AppColors.danger,
                    onTap: onReject,
                    outlined: true,
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    ),
  );
}
}

// ─────────────────────────────────────────────────────────────────────────────
//  AVATAR
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String  name;
  final dynamic photo;
  const _Avatar({required this.name, required this.photo});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photo != null && photo.toString().isNotEmpty;
    return Container(
      width:  50,
      height: 50,
      decoration: BoxDecoration(
        shape:  BoxShape.circle,
        border: Border.all(
            color: AppColors.primaryOrange.withOpacity(.25), width: 2),
      ),
      child: CircleAvatar(
        radius: 23,
        backgroundColor: AppColors.orangeLight,
        backgroundImage: hasPhoto ? NetworkImage(photo.toString()) : null,
        child: hasPhoto
            ? null
            : Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.w800,
                  color:      AppColors.primaryOrange,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATUS BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color  bg;
    Color  fg;
    Color  dot;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'approved':
        bg    = const Color(0xFF10B981).withOpacity(.12);
        fg    = const Color(0xFF059669);
        dot   = const Color(0xFF10B981);
        label = 'Approved';
        icon  = Icons.check_circle_rounded;
        break;
      case 'rejected':
        bg    = AppColors.danger.withOpacity(.10);
        fg    = AppColors.danger;
        dot   = AppColors.danger;
        label = 'Rejected';
        icon  = Icons.cancel_rounded;
        break;
      default:
        bg    = AppColors.primaryOrange.withOpacity(.12);
        fg    = AppColors.primaryOrange;
        dot   = AppColors.primaryOrange;
        label = 'Pending';
        icon  = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize:   10.5,
                fontWeight: FontWeight.w700,
                color:      fg,
                letterSpacing: .2)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback? onTap;
  final bool         outlined;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) { setState(() => _scale = .96); HapticFeedback.lightImpact(); }
          : null,
      onTapUp: widget.onTap != null
          ? (_) { setState(() => _scale = 1.0); widget.onTap!(); }
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _scale = 1.0)
          : null,
      child: AnimatedScale(
        scale:    _scale,
        duration: const Duration(milliseconds: 110),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: widget.outlined
                ? widget.color.withOpacity(.08)
                : widget.color,
            borderRadius: BorderRadius.circular(14),
            border: widget.outlined
                ? Border.all(color: widget.color.withOpacity(.30), width: 1.2)
                : null,
            boxShadow: widget.outlined
                ? []
                : [
                    BoxShadow(
                      color:      widget.color.withOpacity(.28),
                      blurRadius: 12,
                      offset:     const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon,
                  size:  16,
                  color: widget.outlined ? widget.color : Colors.white),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize:   13.5,
                  fontWeight: FontWeight.w700,
                  color: widget.outlined ? widget.color : Colors.white,
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
//  CONFIRMATION DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _ConfirmDialog extends StatelessWidget {
  final String name;
  final String action;
  final String message;
  final String confirmLabel;
  final Color  confirmColor;

  const _ConfirmDialog({
    required this.name,
    required this.action,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // icon
            Container(
              width:  64,
              height: 64,
              decoration: BoxDecoration(
                color:  confirmColor.withOpacity(.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                confirmLabel == 'Approve'
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size:  30,
                color: confirmColor,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              '$confirmLabel Host?',
              style: TextStyle(
                fontSize:      18,
                fontWeight:    FontWeight.w800,
                color:         AppColors.text(context),
                letterSpacing: -.3,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
                          color:      AppColors.text(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // confirm
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, true),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color:         confirmColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color:      confirmColor.withOpacity(.32),
                          blurRadius: 14,
                          offset:     const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
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
//  LOADING STATE
// ═════════════════════════════════════════════════════════════════════════════

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
          color: AppColors.primaryOrange, strokeWidth: 2.5),
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
              child: const Icon(Icons.people_outline_rounded,
                  size: 36, color: AppColors.primaryOrange),
            ),
            const SizedBox(height: 20),
            Text(
              'No host requests yet',
              style: TextStyle(
                fontSize:      18,
                fontWeight:    FontWeight.w800,
                color:         AppColors.text(context),
                letterSpacing: -.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When users apply to become hosts,\ntheir requests will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, color: AppColors.textMid, height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}
