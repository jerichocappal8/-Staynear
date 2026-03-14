import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'chat_service.dart';
import 'chat_room_screen.dart';

class ChatListUserScreen extends StatefulWidget {
  const ChatListUserScreen({super.key});

  @override
  State<ChatListUserScreen> createState() => _ChatListUserScreenState();
}

class _ChatListUserScreenState extends State<ChatListUserScreen> {
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2B40),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5EAF0), height: 1),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getUserConversationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const _EmptyInbox(
              message: 'No conversations yet.\nStart chatting from a property listing!',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 0),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final conversationId = docs[index].id;
              final hostId = data['hostId'] ?? '';

              return FutureBuilder<Map<String, dynamic>>(
                future: _chatService.getOtherParticipantInfo(hostId),
                builder: (context, hostSnap) {
                  final hostInfo = hostSnap.data ?? {};
                  return _ConversationTile(
                    conversationId: conversationId,
                    data: data,
                    otherName: hostInfo['name'] ?? 'Host',
                    otherPhoto: hostInfo['photo'] ?? '',
                    otherParticipantId: hostId,
                    chatService: _chatService,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOST INBOX
// ─────────────────────────────────────────────

class ChatListHostScreen extends StatefulWidget {
  const ChatListHostScreen({super.key});

  @override
  State<ChatListHostScreen> createState() => _ChatListHostScreenState();
}

class _ChatListHostScreenState extends State<ChatListHostScreen> {
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Guest Messages',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2B40),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5EAF0), height: 1),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getHostConversationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const _EmptyInbox(
              message: 'No guest messages yet.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 0),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final conversationId = docs[index].id;
              final userId = data['userId'] ?? '';

              return FutureBuilder<Map<String, dynamic>>(
                future: _chatService.getOtherParticipantInfo(userId),
                builder: (context, userSnap) {
                  final userInfo = userSnap.data ?? {};
                  return _ConversationTile(
                    conversationId: conversationId,
                    data: data,
                    otherName: userInfo['name'] ?? 'Guest',
                    otherPhoto: userInfo['photo'] ?? '',
                    otherParticipantId: userId,
                    chatService: _chatService,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CONVERSATION TILE
// ─────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final String conversationId;
  final Map<String, dynamic> data;
  final String otherName;
  final String otherPhoto;
  final String otherParticipantId;
  final ChatService chatService;

  const _ConversationTile({
    required this.conversationId,
    required this.data,
    required this.otherName,
    required this.otherPhoto,
    required this.otherParticipantId,
    required this.chatService,
  });

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    final dt = (ts as Timestamp).toDate();
    final now = DateTime.now();
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    if (now.difference(dt).inDays < 7) {
      return DateFormat('EEE').format(dt);
    }
    return DateFormat('MMM d').format(dt);
  }

  String _messagePreview(String type, String text) {
    switch (type) {
      case 'image':
        return '📷 Photo';
      case 'booking_reference':
        return '📅 Booking Reference';
      case 'payment_reference':
        return '💳 Payment Reference';
      default:
        return text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastMsg = data['lastMessage'] ?? '';
    final lastType = data['lastMessageType'] ?? 'text';
    final lastTs = data['lastTimestamp'];
    final propertyName = data['propertyName'] ?? '';

    return StreamBuilder<int>(
      stream: chatService.unreadCountStream(conversationId),
      builder: (context, unreadSnap) {
        final unreadCount = unreadSnap.data ?? 0;
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatRoomScreen(
                  conversationId: conversationId,
                  otherParticipantId: otherParticipantId,
                  otherParticipantName: otherName,
                  otherParticipantPhoto: otherPhoto,
                  propertyName: propertyName,
                ),
              ),
            );
          },
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFE0E7EF),
                      backgroundImage: otherPhoto.isNotEmpty
                          ? CachedNetworkImageProvider(otherPhoto)
                          : null,
                      child: otherPhoto.isEmpty
                          ? const Icon(Icons.person,
                              size: 26, color: Color(0xFF94A3B8))
                          : null,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0077B6),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              otherName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: const Color(0xFF1A2B40),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatTime(lastTs),
                            style: TextStyle(
                              fontSize: 12,
                              color: unreadCount > 0
                                  ? const Color(0xFF0077B6)
                                  : Colors.grey[400],
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Property name
                      Text(
                        propertyName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0077B6),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      // Last message
                      Text(
                        _messagePreview(lastType, lastMsg),
                        style: TextStyle(
                          fontSize: 13,
                          color: unreadCount > 0
                              ? const Color(0xFF1A2B40)
                              : Colors.grey[500],
                          fontWeight: unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
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
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────

class _EmptyInbox extends StatelessWidget {
  final String message;
  const _EmptyInbox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF0077B6).withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inbox_rounded,
                size: 48, color: Color(0xFF0077B6)),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF94A3B8),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}