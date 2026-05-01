import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:staynear/core/app_colors.dart';
// ─────────────────────────────────────────────────────────────────────────────
// APP COLORS  (copy from your existing app_colors.dart — duplicated here for
// portability; remove this block if you import it from your own file)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

class HostRequestDetailsScreen extends StatefulWidget {
  final String userId;

  const HostRequestDetailsScreen({super.key, required this.userId});

  @override
  State<HostRequestDetailsScreen> createState() =>
      _HostRequestDetailsScreenState();
}

class _HostRequestDetailsScreenState extends State<HostRequestDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Staggered fade-slide animation helper ────────────────────────────────

  Animation<double> _fadeAt(double begin, double end) =>
      CurvedAnimation(
        parent: _animController,
        curve: Interval(begin, end, curve: Curves.easeOut),
      );

  // ── Firestore actions ─────────────────────────────────────────────────────

  Future<void> _approveRequest() async {
    setState(() => _isProcessing = true);
    try {
      final now = FieldValue.serverTimestamp();
      final batch = FirebaseFirestore.instance.batch();

      batch.update(
        FirebaseFirestore.instance
            .collection('host_requests')
            .doc(widget.userId),
        {'status': 'approved', 'reviewedAt': now},
      );
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(widget.userId),
        {'hostRequest': 'approved', 'role': 'host', 'isHost': true},
      );
      batch.set(
        FirebaseFirestore.instance.collection('hosts').doc(widget.userId),
        {
          'userId': widget.userId,
          'rating': 0,
          'totalListings': 0,
          'createdAt': now,
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      if (mounted) {
        _showResultSnackbar('Request approved successfully ✓', isError: false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showResultSnackbar('Action failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectRequest() async {
    final reason = await _showRejectionDialog();
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final now = FieldValue.serverTimestamp();
      final batch = FirebaseFirestore.instance.batch();

      batch.update(
        FirebaseFirestore.instance
            .collection('host_requests')
            .doc(widget.userId),
        {
          'status': 'rejected',
          'rejectionReason': reason.trim(),
          'reviewedAt': now,
        },
      );
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(widget.userId),
        {'hostRequest': 'rejected', 'role': 'user', 'isHost': false},
      );

      await batch.commit();
      if (mounted) {
        _showResultSnackbar('Request rejected.', isError: false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showResultSnackbar('Action failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showResultSnackbar(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.danger : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<String?> _showRejectionDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => _RejectionDialog(controller: controller),
    );
  }

@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return FutureBuilder<List<DocumentSnapshot>>(
    future: Future.wait([
      FirebaseFirestore.instance
          .collection('host_requests')
          .doc(widget.userId)
          .get(),
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get(),
    ]),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Scaffold(
          backgroundColor: AppColors.background(context),
          body: _LoadingView(isDark: isDark),
        );
      }

      if (snapshot.hasError || snapshot.data == null) {
        return Scaffold(
          backgroundColor: AppColors.background(context),
          body: _ErrorView(error: snapshot.error?.toString()),
        );
      }

      final requestDoc = snapshot.data![0];
      final userDoc = snapshot.data![1];

      if (!requestDoc.exists) {
        return Scaffold(
          backgroundColor: AppColors.background(context),
          body: const _ErrorView(error: 'Host request not found.'),
        );
      }

      final req = requestDoc.data() as Map<String, dynamic>;
      final usr = userDoc.data() as Map<String, dynamic>? ?? {};
      final address = req['address'] as Map<String, dynamic>? ?? {};
      final profilePhoto = usr['photo'] as String?;
      final status = req['status'] as String? ?? 'pending';

      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Sticky AppBar
            SliverAppBar(
              expandedHeight: 0,
              floating: true,
              pinned: true,
              backgroundColor: AppColors.card(context),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: AppColors.text(context)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Host Application',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text(context),
                ),
              ),
              actions: [
                _StatusChip(status: status),
                const SizedBox(width: 12),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: AppColors.border.withOpacity(isDark ? 0.2 : 1),
                ),
              ),
            ),

            // ── Content
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Profile hero
                  FadeTransition(
                    opacity: _fadeAt(0.0, 0.4),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(_fadeAt(0.0, 0.4)),
                      child: _ProfileHeader(
                        userId: widget.userId,
                        fullName: req['fullName'] as String? ?? '—',
                        profilePhoto: profilePhoto,
                        status: status,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Personal info
                  FadeTransition(
                    opacity: _fadeAt(0.15, 0.55),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(_fadeAt(0.15, 0.55)),
                      child: _SectionCard(
                        icon: Icons.person_outline_rounded,
                        title: 'Personal Information',
                        child: Column(
                          children: [
                            _InfoRow(
                                icon: Icons.phone_outlined,
                                label: 'Phone',
                                value: req['phone'] as String?),
                            _InfoRow(
                                icon: Icons.wc_rounded,
                                label: 'Gender',
                                value: req['gender'] as String?),
                            _InfoRow(
                              icon: Icons.cake_outlined,
                              label: 'Date of Birth',
                              value: _formatDate(req['dateOfBirth']),
                            ),
                            _InfoRow(
                                icon: Icons.numbers_rounded,
                                label: 'Age',
                                value: req['age']?.toString(),
                                isLast: true),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Address
                  FadeTransition(
                    opacity: _fadeAt(0.25, 0.65),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(_fadeAt(0.25, 0.65)),
                      child: _SectionCard(
                        icon: Icons.location_on_outlined,
                        title: 'Address',
                        child: Column(
                          children: [
                            _InfoRow(
                                icon: Icons.home_outlined,
                                label: 'Street',
                                value: address['street'] as String?),
                            _InfoRow(
                                icon: Icons.place_outlined,
                                label: 'Barangay',
                                value: address['barangay'] as String?),
                            _InfoRow(
                                icon: Icons.location_city_outlined,
                                label: 'City',
                                value: address['city'] as String?),
                            _InfoRow(
                                icon: Icons.map_outlined,
                                label: 'Province',
                                value: address['province'] as String?),
                            _InfoRow(
                                icon: Icons.public_outlined,
                                label: 'Region',
                                value: address['region'] as String?),
                            _InfoRow(
                                icon: Icons.markunread_mailbox_outlined,
                                label: 'ZIP Code',
                                value: address['zipCode'] as String?,
                                isLast: true),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Documents
                  FadeTransition(
                    opacity: _fadeAt(0.35, 0.75),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(_fadeAt(0.35, 0.75)),
                      child: _SectionCard(
                        icon: Icons.badge_outlined,
                        title: 'Identity Documents',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (req['governmentIdUrl'] != null)
                              _DocumentImage(
                                label: 'Government ID',
                                url: req['governmentIdUrl'] as String,
                              ),
                            if (req['governmentIdUrl'] != null &&
                                req['secondaryIdUrl'] != null)
                              const SizedBox(height: 14),
                            if (req['secondaryIdUrl'] != null)
                              _DocumentImage(
                                label: 'Secondary ID',
                                url: req['secondaryIdUrl'] as String,
                              ),
                            if (req['governmentIdUrl'] == null &&
                                req['secondaryIdUrl'] == null)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'No documents uploaded.',
                                  style: TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 13),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Application info
                  FadeTransition(
                    opacity: _fadeAt(0.45, 0.85),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(_fadeAt(0.45, 0.85)),
                      child: _SectionCard(
                        icon: Icons.info_outline_rounded,
                        title: 'Application Info',
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.credit_card_rounded,
                              label: 'ID Type',
                              value: req['idType'] as String?,
                            ),
                            _InfoRow(
                              icon: Icons.schedule_rounded,
                              label: 'Submitted',
                              value: _formatTimestamp(req['submittedAt']),
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
bottomNavigationBar: FadeTransition(
  opacity: _fadeAt(0.6, 1.0),
  child: _ActionBar(
    status: status,
    isProcessing: _isProcessing,
    onApprove: _approveRequest,
    onReject: _rejectRequest,
  ),
),
      );
    },
  );
}

String _formatTimestamp(dynamic ts) {
  if (ts == null) return '—';
  if (ts is Timestamp) {
    return DateFormat('MMM d, yyyy • h:mm a').format(ts.toDate());
  }
  return ts.toString();
}

String _formatDate(String? iso) {
  if (iso == null) return '—';
  try {
    final date = DateTime.parse(iso);
    return DateFormat('MMMM d, yyyy').format(date);
  } catch (_) {
    return iso;
  }
}
    }

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String userId;
  final String fullName;
  final String? profilePhoto;
  final String status;

  const _ProfileHeader({
    required this.userId,
    required this.fullName,
    required this.profilePhoto,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with Hero animation
          GestureDetector(
            onTap: profilePhoto != null
                ? () => _openFullScreen(context, profilePhoto!, 'profile_$userId')
                : null,
            child: Hero(
              tag: 'profile_$userId',
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.primaryOrange, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor:
                      isDark ? AppColors.darkCardSoft : AppColors.orangeLight,
                  backgroundImage: profilePhoto != null
                      ? CachedNetworkImageProvider(profilePhoto!)
                      : null,
                  child: profilePhoto == null
                      ? Text(
                          fullName.isNotEmpty
                              ? fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryOrange,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            fullName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.text(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Host Applicant',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMid,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _openFullScreen(BuildContext context, String url, String heroTag) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) =>
            _FullScreenImageViewer(imageUrl: url, heroTag: heroTag),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: AppColors.primaryOrange, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: AppColors.border.withOpacity(isDark ? 0.2 : 0.8),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO ROW
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textLight),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value?.isNotEmpty == true ? value! : '—',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: AppColors.border.withOpacity(isDark ? 0.15 : 0.7),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOCUMENT IMAGE TILE
// ─────────────────────────────────────────────────────────────────────────────

class _DocumentImage extends StatelessWidget {
  final String label;
  final String url;

  const _DocumentImage({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heroTag = 'doc_$url';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMid,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _openViewer(context, heroTag),
          child: Hero(
            tag: heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: url,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 180,
                      color: isDark
                          ? AppColors.darkCardSoft
                          : AppColors.orangeLight,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryOrange,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 180,
                      color: isDark
                          ? AppColors.darkCardSoft
                          : AppColors.bgLight,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: AppColors.textLight, size: 32),
                      ),
                    ),
                  ),
                  // Tap overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.zoom_in_rounded,
                              color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Tap to expand',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openViewer(BuildContext context, String heroTag) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) =>
            _FullScreenImageViewer(imageUrl: url, heroTag: heroTag),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FULL SCREEN IMAGE VIEWER
// ─────────────────────────────────────────────────────────────────────────────

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _FullScreenImageViewer(
      {required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: () {
              // Hook up your download logic here
            },
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.broken_image, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg, label) = switch (status.toLowerCase()) {
      'approved' => (
          Colors.green[700]!,
          Colors.green.withOpacity(0.12),
          'Approved'
        ),
      'rejected' => (
          AppColors.danger,
          AppColors.danger.withOpacity(0.1),
          'Rejected'
        ),
      _ => (
          AppColors.primaryOrange,
          AppColors.orangeLight,
          'Pending'
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;
   final String status;

  const _ActionBar({
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
        required this.status,

  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: AppColors.border.withOpacity(isDark ? 0.2 : 1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Reject button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: (status != "pending" || isProcessing) ? null : onReject,
              icon: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.danger),
                    )
                  : const Icon(Icons.cancel_outlined,
                      size: 18, color: AppColors.danger),
              label: const Text(
                'Reject',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: AppColors.danger, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Approve button
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: (status != "pending" || isProcessing) ? null : onApprove,
              icon: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline_rounded,
                      size: 18),
              label: const Text(
                'Approve as Host',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2D9E5A),
                disabledBackgroundColor:
                    const Color(0xFF2D9E5A).withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REJECTION DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _RejectionDialog extends StatefulWidget {
  final TextEditingController controller;
  const _RejectionDialog({required this.controller});

  @override
  State<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<_RejectionDialog> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(
        () => setState(() => _hasText = widget.controller.text.trim().isNotEmpty));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cancel_outlined,
                      color: AppColors.danger, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reject Application',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text(context),
                      ),
                    ),
                    const Text(
                      'Provide a reason for the applicant',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMid,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Text field
            TextField(
              controller: widget.controller,
              maxLines: 4,
              maxLength: 300,
              style: TextStyle(
                  fontSize: 14, color: AppColors.text(context)),
              decoration: InputDecoration(
                hintText:
                    'e.g. ID photo is blurry, incomplete information...',
                hintStyle: const TextStyle(
                    color: AppColors.textLight, fontSize: 13),
                filled: true,
                fillColor: isDark
                    ? AppColors.darkCardSoft
                    : AppColors.bgLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.danger, width: 1.5),
                ),
                counterStyle: const TextStyle(
                    color: AppColors.textLight, fontSize: 11),
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(
                          color: AppColors.border
                              .withOpacity(isDark ? 0.4 : 1)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textMid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _hasText
                        ? () => Navigator.pop(
                            context, widget.controller.text.trim())
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      disabledBackgroundColor:
                          AppColors.danger.withOpacity(0.35),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Confirm Reject',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING / ERROR STATES
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final bool isDark;
  const _LoadingView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primaryOrange),
          const SizedBox(height: 16),
          Text(
            'Loading application...',
            style: TextStyle(color: AppColors.textMid, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String? error;
  const _ErrorView({this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.danger, size: 48),
            const SizedBox(height: 16),
            Text(
              error ?? 'Something went wrong.',
              style: const TextStyle(color: AppColors.textMid, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
