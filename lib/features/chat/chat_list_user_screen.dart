// chat_list_screen.dart
// ════════════════════════════════════════════════════════════════════════════
//  StayNear — Chat List Screens  (UI redesign, all logic unchanged)
//
//  ChatListUserScreen  — tenant inbox (streams getUserConversationsStream)
//  ChatListHostScreen  — host inbox   (streams getHostConversationsStream)
//
//  All Firestore streams, FutureBuilders, navigation, and chat service
//  calls are identical to the original file.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import 'chat_service.dart';
import 'chat_room_screen.dart';
import 'package:staynear/core/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  USER INBOX
// ─────────────────────────────────────────────────────────────────────────────

class ChatListUserScreen extends StatefulWidget {
  const ChatListUserScreen({super.key});

  @override
  State<ChatListUserScreen> createState() => _ChatListUserScreenState();
}

class _ChatListUserScreenState extends State<ChatListUserScreen>
    with SingleTickerProviderStateMixin {

  // ── original logic (unchanged) ─────────────────────────────────────────────
  final ChatService _chatService = ChatService();

  // ── list entrance animation ────────────────────────────────────────────────
  late final AnimationController _listCtrl;
  late final Animation<double>   _listFade;

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _listFade = CurvedAnimation(parent: _listCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: _buildAppBar(context, title: 'Messages'),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getUserConversationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primaryOrange, strokeWidth: 2.5),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const _EmptyInbox(
              message:
                  'No conversations yet.\nStart chatting from a property listing!',
              icon: Icons.chat_bubble_outline_rounded,
            );
          }

          return FadeTransition(
            opacity: _listFade,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              physics: const BouncingScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data           = docs[index].data() as Map<String, dynamic>;
                final conversationId = docs[index].id;
                final hostId         = data['hostId'] ?? '';

                return _staggeredItem(
                  index: index,
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _chatService.getOtherParticipantInfo(hostId),
                    builder: (context, hostSnap) {
                      final hostInfo = hostSnap.data ?? {};
                      // Fallback order:
                      //   1. fetched user-doc name (most up-to-date)
                      //   2. hostName stored on conversation doc (saved at creation)
                      //   3. propertyName as last recognisable label
                      //   4. 'Host'
                      final fetched  = (hostInfo['name']  as String? ?? '').trim();
                      final stored   = (data['hostName']  as String? ?? '').trim();
                      final property = (data['propertyName'] as String? ?? '').trim();
                      final resolvedName = fetched.isNotEmpty  ? fetched
                          : stored.isNotEmpty   ? stored
                          : property.isNotEmpty ? property
                          : 'Host';
                      // Same priority for avatar photo.
                      final fetchedPhoto = (hostInfo['photo'] as String? ?? '');
                      final storedPhoto  = (data['hostPhoto'] as String? ?? '');
                      final resolvedPhoto = fetchedPhoto.isNotEmpty ? fetchedPhoto : storedPhoto;
                      return _ConversationTile(
                        conversationId:       conversationId,
                        data:                 data,
                        otherName:            resolvedName,
                        otherPhoto:           resolvedPhoto,
                        otherParticipantId:   hostId,
                        chatService:          _chatService,
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED APP BAR builder
// ─────────────────────────────────────────────────────────────────────────────

PreferredSizeWidget _buildAppBar(BuildContext context,
    {required String title}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return AppBar(
    backgroundColor:         AppColors.background(context),
    surfaceTintColor:        Colors.transparent,
    scrolledUnderElevation:  0,
    elevation:               0,
    automaticallyImplyLeading: false,
    title: Text(
      title,
      style: TextStyle(
        fontSize:      22,
        fontWeight:    FontWeight.w900,
        color:         AppColors.text(context),
        letterSpacing: -.5,
      ),
    ),
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

// ─────────────────────────────────────────────────────────────────────────────
//  STAGGERED LIST ITEM helper
// ─────────────────────────────────────────────────────────────────────────────

Widget _staggeredItem({required int index, required Widget child}) {
  return TweenAnimationBuilder<double>(
    tween:    Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 300 + index * 50),
    curve:    Curves.easeOutCubic,
    builder: (_, v, c) => Opacity(
      opacity: v,
      child:   Transform.translate(offset: Offset(0, 14 * (1 - v)), child: c),
    ),
    child: child,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CONVERSATION TILE  (logic unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationTile extends StatefulWidget {
  final String              conversationId;
  final Map<String, dynamic> data;
  final String              otherName;
  final String              otherPhoto;
  final String              otherParticipantId;
  final ChatService         chatService;

  const _ConversationTile({
    required this.conversationId,
    required this.data,
    required this.otherName,
    required this.otherPhoto,
    required this.otherParticipantId,
    required this.chatService,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {

  // ── press-scale ────────────────────────────────────────────────────────────
  double _scale = 1.0;

  // ── original helpers (unchanged) ──────────────────────────────────────────

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    final dt  = (ts as Timestamp).toDate();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    if (now.difference(dt).inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('MMM d').format(dt);
  }

  String _messagePreview(String type, String text) {
    switch (type) {
      case 'image':             return '📷 Photo';
      case 'booking_reference': return '📅 Booking Reference';
      case 'payment_reference': return '💳 Payment Reference';
      default:                  return text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastMsg      = widget.data['lastMessage']     ?? '';
    final lastType     = widget.data['lastMessageType'] ?? 'text';
    final lastTs       = widget.data['lastTimestamp'];
    final propertyName = widget.data['propertyName']    ?? '';
    final isDark       = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<int>(
      stream: widget.chatService.unreadCountStream(widget.conversationId),
      builder: (context, unreadSnap) {
        final unreadCount = unreadSnap.data ?? 0;
        final hasUnread   = unreadCount > 0;

        return GestureDetector(
          onTapDown: (_) => setState(() => _scale = .975),
          onTapUp:   (_) {
            setState(() => _scale = 1.0);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatRoomScreen(
                  conversationId:       widget.conversationId,
                  otherParticipantId:   widget.otherParticipantId,
                  otherParticipantName: widget.otherName,
                  otherParticipantPhoto: widget.otherPhoto,
                  propertyName:         propertyName,
                ),
              ),
            );
          },
          onTapCancel: () => setState(() => _scale = 1.0),
          child: AnimatedScale(
            scale:    _scale,
            duration: const Duration(milliseconds: 120),
            curve:    Curves.easeOut,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasUnread
                      ? AppColors.primaryOrange.withOpacity(.30)
                      : isDark
                          ? AppColors.darkCardSoft.withOpacity(.5)
                          : AppColors.border,
                  width: hasUnread ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:      Colors.black.withOpacity(isDark ? .12 : .04),
                    blurRadius: 14,
                    offset:     const Offset(0, 4),
                  ),
                  if (hasUnread)
                    BoxShadow(
                      color:      AppColors.primaryOrange.withOpacity(.08),
                      blurRadius: 16,
                      offset:     const Offset(0, 4),
                    ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // ── avatar + unread badge ──────────────────────────────
                  _Avatar(
                    photo:       widget.otherPhoto,
                    name:        widget.otherName,
                    unreadCount: unreadCount,
                  ),

                  const SizedBox(width: 13),

                  // ── content column ─────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // name + timestamp
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.otherName,
                                style: TextStyle(
                                  fontSize:   15,
                                  fontWeight: hasUnread
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color:      AppColors.text(context),
                                  letterSpacing: -.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(lastTs),
                              style: TextStyle(
                                fontSize:   11.5,
                                color: hasUnread
                                    ? AppColors.primaryOrange
                                    : AppColors.textLight,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),

                        // property name pill
                        if (propertyName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Container(
                              constraints: const BoxConstraints(maxWidth: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color:         AppColors.orangeLight,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.apartment_rounded,
                                      size: 10,
                                      color: AppColors.primaryOrange),
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
                                ],
                              ),
                            ),
                          ]),
                        ],

                        const SizedBox(height: 5),

                        // last message preview
                        Text(
                          _messagePreview(lastType, lastMsg),
                          style: TextStyle(
                            fontSize:   13,
                            color: hasUnread
                                ? AppColors.text(context)
                                : AppColors.textMid,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                            height: 1.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AVATAR  — with animated unread badge
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String photo;
  final String name;
  final int    unreadCount;

  const _Avatar({
    required this.photo,
    required this.name,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [

        // ── avatar circle ────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width:  52,
          height: 52,
          decoration: BoxDecoration(
            shape:  BoxShape.circle,
            border: Border.all(
              color: hasUnread
                  ? AppColors.primaryOrange
                  : AppColors.border,
              width: hasUnread ? 2.0 : 1.2,
            ),
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.orangeLight,
            backgroundImage: photo.isNotEmpty
                ? CachedNetworkImageProvider(photo)
                : null,
            child: photo.isEmpty
                ? Text(
                    name.isNotEmpty
                        ? name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize:   18,
                      fontWeight: FontWeight.w800,
                      color:      AppColors.primaryOrange,
                    ),
                  )
                : null,
          ),
        ),

        // ── unread badge ─────────────────────────────────────────────────
        if (hasUnread)
          Positioned(
            right: -2,
            top:   -2,
            child: AnimatedScale(
              scale:    hasUnread ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              curve:    Curves.easeOutBack,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color:        AppColors.primaryOrange,
                  shape:        unreadCount <= 9
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  borderRadius: unreadCount <= 9
                      ? null
                      : BorderRadius.circular(9),
                  border:       Border.all(
                      color: AppColors.card(context), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color:      AppColors.primaryOrange.withOpacity(.35),
                      blurRadius: 8,
                      offset:     const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyInbox extends StatelessWidget {
  final String   message;
  final IconData icon;
  const _EmptyInbox({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width:  88,
              height: 88,
              decoration: const BoxDecoration(
                color:  AppColors.orangeLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.primaryOrange),
            ),
            const SizedBox(height: 22),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.w800,
                color:      AppColors.text(context),
                letterSpacing: -.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color:    AppColors.textMid,
                height:   1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}