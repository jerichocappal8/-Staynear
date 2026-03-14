import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../chat/chat_service.dart';
import '../chat/chat_room_screen.dart';

/// Example integration: how to wire "Message Host" button
/// in your existing ApartmentDetailPage.
///
/// Drop this mixin or copy the [_openChat] method into your page.
class ApartmentDetailChatButton extends StatelessWidget {
  final String propertyId;
  final String propertyName;
  final String ownerId;

  // Optional: attach existing booking/payment IDs
  final String? bookingId;
  final String? paymentId;

  const ApartmentDetailChatButton({
    super.key,
    required this.propertyId,
    required this.propertyName,
    required this.ownerId,
    this.bookingId,
    this.paymentId,
  });

  Future<void> _openChat(BuildContext context) async {
    // Guard: user must be logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to contact the host.')),
      );
      return;
    }

    // Prevent host from chatting with themselves
    if (currentUser.uid == ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your own property.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final chatService = ChatService();

      // 1. Get or create conversation (duplicate-safe)
      final conversationId = await chatService.getOrCreateConversation(
        propertyId: propertyId,
        propertyName: propertyName,
        hostId: ownerId,
      );

      // 2. Fetch host info for display
      final hostDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .get();
      final hostData = hostDoc.data() ?? {};
      final hostName =
          '${hostData['firstName'] ?? ''} ${hostData['lastName'] ?? ''}'.trim();
      final hostPhoto = hostData['photo'] ?? '';

      if (context.mounted) Navigator.pop(context); // close loader

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              conversationId: conversationId,
              otherParticipantId: ownerId,
              otherParticipantName: hostName.isNotEmpty ? hostName : 'Host',
              otherParticipantPhoto: hostPhoto,
              propertyName: propertyName,
              bookingId: bookingId,
              paymentId: paymentId,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openChat(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0077B6),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0077B6).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_rounded,
                color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Message Host',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MINIMAL DEMO PAGE (for reference / testing)
// ─────────────────────────────────────────────

class ApartmentDetailPageDemo extends StatelessWidget {
  const ApartmentDetailPageDemo({super.key});

  @override
  Widget build(BuildContext context) {
    // Replace these with your real property data
    const propertyId = 'PROPERTY_ID_HERE';
    const propertyName = 'Cozy Beach House';
    const ownerId = 'HOST_UID_HERE';

    return Scaffold(
      appBar: AppBar(title: const Text('Property Detail')),
      body: Center(
        child: ApartmentDetailChatButton(
          propertyId: propertyId,
          propertyName: propertyName,
          ownerId: ownerId,
          // bookingId: 'booking_abc123',
          // paymentId: 'payment_xyz789',
        ),
      ),
    );
  }
}