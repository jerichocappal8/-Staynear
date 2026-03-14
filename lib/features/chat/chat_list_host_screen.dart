// chat_list_host_screen.dart
// ════════════════════════════════════════════════════════════════════════════
//  StayNear — Host Chat List Screen  (UI redesign, all logic unchanged)
//
//  Firestore query, StreamBuilder, FutureBuilder, navigation to
//  ChatRoomScreen, and _formatTime are all identical to the original.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_room_screen.dart';
import 'package:staynear/core/app_colors.dart';

import '../../core/animations/slide_page_route.dart';
import '../host/host_bottom_nav.dart';
import '../host/host_dashboard_screen.dart';
import '../host/host_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatListHostScreen extends StatelessWidget {
  final String hostId;

  const ChatListHostScreen({super.key, required this.hostId});

  // ── original helper (unchanged) ───────────────────────────────────────────
  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final date   = ts.toDate();
    final hour   = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

return GestureDetector(
  onHorizontalDragEnd: (details) {

    // swipe RIGHT → Dashboard
    if (details.primaryVelocity! > 0) {
      Navigator.pushReplacement(
        context,
        SlidePageRoute(
          page: const HostDashboardScreen(),
        ),
      );
    }

    // swipe LEFT → Profile
    if (details.primaryVelocity! < 0) {
      Navigator.pushReplacement(
        context,
        SlidePageRoute(
          page: const HostProfileScreen(),
        ),
      );
    }
  },

  child: Scaffold(
    backgroundColor: AppColors.background(context),

    // ── AppBar ─────────────────────────────────────────────
    appBar: AppBar(
      backgroundColor: AppColors.background(context),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        'Messages',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: AppColors.text(context),
          letterSpacing: -.5,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.orangeLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.mark_chat_unread_rounded,
                size: 13, color: AppColors.primaryOrange),
            SizedBox(width: 5),
            Text(
              'Host',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryOrange,
              ),
            ),
          ]),
        ),
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
    ),

    // ── Body ───────────────────────────────────────────────
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('hostId', isEqualTo: hostId)
          .orderBy('lastTimestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.primaryOrange, strokeWidth: 2.5),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const _EmptyState();
        }

        final conversations = snapshot.data!.docs;

        if (conversations.isEmpty) {
          return const _EmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          physics: const BouncingScrollPhysics(),
          itemCount: conversations.length,
          itemBuilder: (context, index) {

            final data = conversations[index].data() as Map<String, dynamic>;
            final lastTimestamp = data['lastTimestamp'] as Timestamp?;
            final lastMessage = data['lastMessage']?.toString() ?? '';

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(data['userId'])
                  .get(),
              builder: (context, userSnapshot) {

                if (!userSnapshot.hasData) {
                  return _LoadingTile();
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                final name = userData['name'] ?? 'Guest';
                final photo = userData['photo'];

                return _ConversationTile(
                  conversationId: conversations[index].id,
                  data: data,
                  name: name.isEmpty ? 'Guest' : name,
                  photo: photo,
                  lastMessage: lastMessage,
                  timeLabel: _formatTime(lastTimestamp),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatRoomScreen(
                          conversationId: conversations[index].id,
                          otherParticipantId: data['userId'],
                          otherParticipantName: name,
                          otherParticipantPhoto: photo ?? '',
                          propertyName: data['propertyName'] ?? '',
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    ),

    // ── Bottom Navbar ─────────────────────────────────────
    bottomNavigationBar: HostBottomNav(
      currentIndex: 1,
      onTap: (index) {

        if (index == 0) {
          Navigator.pushReplacement(
            context,
            SlidePageRoute(
              page: const HostDashboardScreen(),
            ),
          );
        }

        if (index == 2) {
          Navigator.pushReplacement(
            context,
            SlidePageRoute(
              page: const HostProfileScreen(),
            ),
          );
        }

      },
    ),
  ),
);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CONVERSATION TILE
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationTile extends StatefulWidget {
  final String              conversationId;
  final Map<String, dynamic> data;
  final String              name;
  final dynamic             photo;       // String? url
  final String              lastMessage;
  final String              timeLabel;
  final VoidCallback        onTap;

  const _ConversationTile({
    required this.conversationId,
    required this.data,
    required this.name,
    required this.photo,
    required this.lastMessage,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final propertyName = widget.data['propertyName']?.toString() ?? '';

    return TweenAnimationBuilder<double>(
      tween:    Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve:    Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child:   Transform.translate(
            offset: Offset(0, 12 * (1 - v)), child: child),
      ),
      child: GestureDetector(
        onTapDown:   (_) { setState(() => _scale = .975); HapticFeedback.lightImpact(); },
        onTapUp:     (_) { setState(() => _scale = 1.0);  widget.onTap(); },
        onTapCancel: ()  => setState(() => _scale = 1.0),
        child: AnimatedScale(
          scale:    _scale,
          duration: const Duration(milliseconds: 120),
          curve:    Curves.easeOut,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:         AppColors.card(context),
              borderRadius: BorderRadius.circular(20),
              border:        Border.all(
                color: isDark
                    ? AppColors.darkCardSoft.withOpacity(.5)
                    : AppColors.border,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withOpacity(isDark ? .10 : .04),
                  blurRadius: 14,
                  offset:     const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // ── avatar ───────────────────────────────────────────────
                _Avatar(name: widget.name, photo: widget.photo),

                const SizedBox(width: 12),

                // ── content ──────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // name + time
                      Row(children: [
                        Expanded(
                          child: Text(
                            widget.name,
                            style: TextStyle(
                              fontSize:   15,
                              fontWeight: FontWeight.w700,
                              color:      AppColors.text(context),
                              letterSpacing: -.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.timeLabel,
                          style: const TextStyle(
                              fontSize:   11.5,
                              color:      AppColors.textLight,
                              fontWeight: FontWeight.w500),
                        ),
                      ]),

                      // property pill
                      if (propertyName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color:         AppColors.orangeLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.apartment_rounded,
                                size: 10, color: AppColors.primaryOrange),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                propertyName,
                                style: const TextStyle(
                                  fontSize:   10.5,
                                  color:      AppColors.primaryOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 5),

                      // last message preview
                      Text(
                        widget.lastMessage.isEmpty
                            ? 'No messages yet'
                            : widget.lastMessage,
                        style: TextStyle(
                          fontSize:   13,
                          color: widget.lastMessage.isEmpty
                              ? AppColors.textLight
                              : AppColors.textMid,
                          fontWeight: FontWeight.w400,
                          height:     1.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // ── chevron ──────────────────────────────────────────────
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textLight),
              ],
            ),
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
      width:  52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.primaryOrange.withOpacity(.25), width: 2),
      ),
      child: CircleAvatar(
        radius: 24,
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
//  LOADING SKELETON TILE
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmer = isDark
        ? AppColors.darkCardSoft.withOpacity(.4)
        : AppColors.border.withOpacity(.7);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:         AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border:        Border.all(color: AppColors.border.withOpacity(.5)),
      ),
      child: Row(children: [
        // avatar placeholder
        Container(
          width:  52,
          height: 52,
          decoration: BoxDecoration(color: shimmer, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 13, width: 120,
                  decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 8),
              Container(height: 11, width: 180,
                  decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(6))),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

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
              child: const Icon(Icons.mark_chat_unread_outlined,
                  size: 36, color: AppColors.primaryOrange),
            ),
            const SizedBox(height: 20),
            Text(
              'No guest messages yet',
              style: TextStyle(
                fontSize:      18,
                fontWeight:    FontWeight.w800,
                color:         AppColors.text(context),
                letterSpacing: -.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When guests contact you about a property,\ntheir messages will appear here.',
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