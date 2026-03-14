import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  final bool showAvatar;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final type = message['type'] ?? 'text';
    final timestamp = message['timestamp'];
    final isRead = message['isRead'] ?? false;
    final senderPhoto = message['senderPhoto'] ?? '';

    final timeStr = timestamp != null
        ? DateFormat('HH:mm').format(timestamp.toDate())
        : '';

    return Padding(
      padding: EdgeInsets.only(
        left: isMine ? 64 : 12,
        right: isMine ? 12 : 64,
        top: 2,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Sender Avatar (guest side only)
          if (!isMine && showAvatar) ...[
            _buildAvatar(senderPhoto),
            const SizedBox(width: 6),
          ] else if (!isMine) ...[
            const SizedBox(width: 34),
          ],

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _buildBubbleContent(context, type),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: isRead
                            ? const Color(0xFF00B4D8)
                            : Colors.grey[400],
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String photoUrl) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: const Color(0xFFE0E7EF),
      backgroundImage:
          photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
      child: photoUrl.isEmpty
          ? const Icon(Icons.person, size: 14, color: Color(0xFF94A3B8))
          : null,
    );
  }

  Widget _buildBubbleContent(BuildContext context, String type) {
    switch (type) {
      case 'image':
        return _ImageBubble(message: message, isMine: isMine);
      case 'booking_reference':
        return _ReferenceBubble(
          isMine: isMine,
          icon: Icons.calendar_today_rounded,
          label: 'Booking Reference',
          subtitle: 'Tap to view booking details',
          color: const Color(0xFF0077B6),
          id: message['bookingId'] ?? '',
        );
      case 'payment_reference':
        return _ReferenceBubble(
          isMine: isMine,
          icon: Icons.payment_rounded,
          label: 'Payment Reference',
          subtitle: 'Tap to view payment details',
          color: const Color(0xFF2D6A4F),
          id: message['paymentId'] ?? '',
        );
      default:
        return _TextBubble(message: message, isMine: isMine);
    }
  }
}

// ─────────────────────────────────────────────
// TEXT BUBBLE
// ─────────────────────────────────────────────

class _TextBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;

  const _TextBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMine ? const Color(0xFF0077B6) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft:
              isMine ? const Radius.circular(18) : const Radius.circular(4),
          bottomRight:
              isMine ? const Radius.circular(4) : const Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        message['text'] ?? '',
        style: TextStyle(
          fontSize: 15,
          color: isMine ? Colors.white : const Color(0xFF1A2B40),
          height: 1.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// IMAGE BUBBLE
// ─────────────────────────────────────────────

class _ImageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;

  const _ImageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final imageUrl = message['imageUrl'] ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft:
            isMine ? const Radius.circular(18) : const Radius.circular(4),
        bottomRight:
            isMine ? const Radius.circular(4) : const Radius.circular(18),
      ),
      child: GestureDetector(
        onTap: () => _showFullImage(context, imageUrl),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 220,
          height: 180,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 220,
            height: 180,
            color: const Color(0xFFE0E7EF),
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 220,
            height: 180,
            color: const Color(0xFFE0E7EF),
            child: const Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REFERENCE BUBBLE (booking / payment)
// ─────────────────────────────────────────────

class _ReferenceBubble extends StatelessWidget {
  final bool isMine;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String id;

  const _ReferenceBubble({
    required this.isMine,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMine ? color : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft:
              isMine ? const Radius.circular(18) : const Radius.circular(4),
          bottomRight:
              isMine ? const Radius.circular(4) : const Radius.circular(18),
        ),
        border: isMine ? null : Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMine
                  ? Colors.white.withOpacity(0.2)
                  : color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isMine ? Colors.white : color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isMine ? Colors.white : color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isMine
                        ? Colors.white.withOpacity(0.8)
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#${id.substring(0, id.length.clamp(0, 8)).toUpperCase()}',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: isMine
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey[400],
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