// message_bubble.dart
// ════════════════════════════════════════════════════════════════════════════
//  StayNear — Message Bubble  (UI redesign, all logic unchanged)
//
//  Supports all original message types: text · image · booking_reference ·
//  payment_reference. Read receipts, timestamps, avatar logic, image preview,
//  and full-screen viewer are all identical to the original.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import 'package:staynear/core/app_colors.dart';

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
    // ── original data extraction (unchanged) ──────────────────────────────
    final type        = message['type'] ?? 'text';
    final timestamp   = message['timestamp'];
    final isRead      = message['isRead'] ?? false;
    final senderPhoto = message['senderPhoto'] ?? '';

    final timeStr = timestamp != null
        ? DateFormat('HH:mm').format(timestamp.toDate())
        : '';

    return TweenAnimationBuilder<double>(
      tween:    Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve:    Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child:   Transform.translate(
          offset: Offset(isMine ? 8 * (1 - v) : -8 * (1 - v), 0),
          child:  child,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left:   isMine ? 56 : 12,
          right:  isMine ? 12 : 56,
          top:    3,
          bottom: 3,
        ),
        child: Row(
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [

            // ── sender avatar (other side) ──────────────────────────────
            if (!isMine && showAvatar) ...[
              _Avatar(photoUrl: senderPhoto),
              const SizedBox(width: 6),
            ] else if (!isMine) ...[
              const SizedBox(width: 34),
            ],

            // ── bubble + meta ───────────────────────────────────────────
            Flexible(
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [

                  // bubble
                  _buildBubbleContent(context, type),

                  const SizedBox(height: 3),

                  // timestamp + read receipt
                  _MetaRow(
                    timeStr: timeStr,
                    isMine:  isMine,
                    isRead:  isRead,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubbleContent(BuildContext context, String type) {
    switch (type) {
      case 'image':
        return _ImageBubble(message: message, isMine: isMine);
      case 'booking_reference':
        return _ReferenceBubble(
          isMine:   isMine,
          icon:     Icons.calendar_month_rounded,
          label:    'Booking Reference',
          subtitle: 'Tap to view booking details',
          color:    AppColors.primaryOrange,
          id:       message['bookingId'] ?? '',
        );
      case 'payment_reference':
        return _ReferenceBubble(
          isMine:   isMine,
          icon:     Icons.payments_rounded,
          label:    'Payment Reference',
          subtitle: 'Tap to view payment details',
          color:    const Color(0xFF10B981),
          id:       message['paymentId'] ?? '',
        );
      default:
        return _TextBubble(message: message, isMine: isMine);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AVATAR
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String photoUrl;
  const _Avatar({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.primaryOrange.withOpacity(.25), width: 1.5),
      ),
      child: CircleAvatar(
        radius: 14,
        backgroundColor: AppColors.orangeLight,
        backgroundImage: photoUrl.isNotEmpty
            ? CachedNetworkImageProvider(photoUrl)
            : null,
        child: photoUrl.isEmpty
            ? const Icon(Icons.person_rounded,
                size: 16, color: AppColors.primaryOrange)
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TIMESTAMP + READ RECEIPT ROW
// ─────────────────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final String timeStr;
  final bool   isMine;
  final bool   isRead;
  const _MetaRow(
      {required this.timeStr,
      required this.isMine,
      required this.isRead});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeStr,
          style: const TextStyle(
              fontSize: 10.5, color: AppColors.textLight,
              fontWeight: FontWeight.w400),
        ),
        if (isMine) ...[
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Icon(
              isRead ? Icons.done_all_rounded : Icons.done_rounded,
              key:   ValueKey(isRead),
              size:  13,
              color: isRead
                  ? AppColors.primaryOrange
                  : AppColors.textLight,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TEXT BUBBLE
// ─────────────────────────────────────────────────────────────────────────────

class _TextBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  const _TextBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // sent bubble: orange gradient  |  received: card surface
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: isMine
            ? const LinearGradient(
                colors: [Color(0xFFFF8C00), AppColors.primaryOrange],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              )
            : null,
        color: isMine ? null : AppColors.card(context),
        borderRadius: BorderRadius.only(
          topLeft:     const Radius.circular(20),
          topRight:    const Radius.circular(20),
          bottomLeft:  Radius.circular(isMine ? 20 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 20),
        ),
        border: isMine
            ? null
            : Border.all(
                color: isDark
                    ? AppColors.darkCardSoft.withOpacity(.6)
                    : AppColors.border,
                width: 1),
        boxShadow: [
          BoxShadow(
            color: isMine
                ? AppColors.primaryOrange.withOpacity(.22)
                : Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        message['text'] ?? '',
        style: TextStyle(
          fontSize: 14.5,
          color:    isMine ? Colors.white : AppColors.text(context),
          height:   1.45,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  IMAGE BUBBLE  (logic unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _ImageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  const _ImageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final imageUrl = message['imageUrl'] ?? '';

    return GestureDetector(
      onTap: () => _showFullImage(context, imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft:     const Radius.circular(20),
          topRight:    const Radius.circular(20),
          bottomLeft:  Radius.circular(isMine ? 20 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 20),
        ),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              width:    220,
              height:   180,
              fit:      BoxFit.cover,
              placeholder: (_, __) => Container(
                width:  220,
                height: 180,
                color:  AppColors.border,
                child:  const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primaryOrange, strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                width:  220,
                height: 180,
                color:  AppColors.border,
                child:  const Icon(Icons.broken_image_rounded,
                    color: AppColors.textLight, size: 36),
              ),
            ),
            // tap-to-view overlay hint
            Positioned(
              bottom: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:         Colors.black.withOpacity(.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_out_map_rounded,
                        size: 11, color: Colors.white),
                    SizedBox(width: 3),
                    Text('View',
                        style: TextStyle(
                            fontSize: 10, color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── original full-image logic (unchanged) ──────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
//  REFERENCE BUBBLE  (booking / payment)
// ─────────────────────────────────────────────────────────────────────────────

class _ReferenceBubble extends StatelessWidget {
  final bool     isMine;
  final IconData icon;
  final String   label;
  final String   subtitle;
  final Color    color;
  final String   id;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shortId = id.length > 8
        ? id.substring(0, 8).toUpperCase()
        : id.toUpperCase();

    return Container(
      width: 244,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isMine
            ? LinearGradient(
                colors: [
                  color.withOpacity(.85),
                  color,
                ],
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
              )
            : null,
        color: isMine ? null : AppColors.card(context),
        borderRadius: BorderRadius.only(
          topLeft:     const Radius.circular(20),
          topRight:    const Radius.circular(20),
          bottomLeft:  Radius.circular(isMine ? 20 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 20),
        ),
        border: isMine
            ? null
            : Border.all(
                color: isDark
                    ? color.withOpacity(.30)
                    : color.withOpacity(.20),
                width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isMine
                ? color.withOpacity(.28)
                : Colors.black.withOpacity(.05),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [

          // icon container
          Container(
            width:  42,
            height: 42,
            decoration: BoxDecoration(
              color: isMine
                  ? Colors.white.withOpacity(.22)
                  : color.withOpacity(.10),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isMine
                    ? Colors.white.withOpacity(.18)
                    : color.withOpacity(.18),
                width: 1,
              ),
            ),
            child: Icon(icon,
                color: isMine ? Colors.white : color, size: 20),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize:   13,
                    color:      isMine ? Colors.white : color,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color:    isMine
                        ? Colors.white.withOpacity(.78)
                        : AppColors.textMid,
                  ),
                ),
                const SizedBox(height: 5),
                // reference ID chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isMine
                        ? Colors.white.withOpacity(.18)
                        : color.withOpacity(.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '#$shortId',
                    style: TextStyle(
                      fontSize:   10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color:      isMine
                          ? Colors.white.withOpacity(.85)
                          : color,
                      letterSpacing: .5,
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