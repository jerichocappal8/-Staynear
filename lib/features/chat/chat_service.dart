import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  String get currentUserId => _auth.currentUser!.uid;

  // ─────────────────────────────────────────────
  // CONVERSATION MANAGEMENT
  // ─────────────────────────────────────────────

  /// Creates or retrieves an existing conversation between user and host
  /// for a specific property. Prevents duplicates.
  Future<String> getOrCreateConversation({
    required String propertyId,
    required String propertyName,
    required String hostId,
  }) async {
    final userId = currentUserId;

    // Check for an existing conversation with same propertyId + userId
    final existing = await _firestore
        .collection('conversations')
        .where('propertyId', isEqualTo: propertyId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    // Fetch both participant profiles in parallel so we can denormalize display
    // names and photos into the conversation doc. This avoids a Firestore read
    // on every chat-list rebuild for new conversations.
    final results = await Future.wait([
      _firestore.collection('users').doc(userId).get(),
      _firestore.collection('users').doc(hostId).get(),
    ]);
    final uData = results[0].data() ?? {};
    final hData = results[1].data() ?? {};

    String _joinName(Map d) =>
        ('${d['firstName'] ?? ''} ${d['lastName'] ?? ''}').trim();

    final userName  = _joinName(uData);
    final hostName  = _joinName(hData);
    final userPhoto = (uData['photo'] as String?) ?? '';
    final hostPhoto = (hData['photo'] as String?) ?? '';

    // Create new conversation
    final conversationRef = _firestore.collection('conversations').doc();
    await conversationRef.set({
      'propertyId':   propertyId,
      'propertyName': propertyName,
      'hostId':       hostId,
      'userId':       userId,
      'hostName':     hostName,
      'userName':     userName,
      'hostPhoto':    hostPhoto,
      'userPhoto':    userPhoto,
      'participants':     [userId, hostId],
      'lastMessage':      '',
      'lastMessageType':  'text',
      'lastTimestamp':    FieldValue.serverTimestamp(),
      'createdAt':        FieldValue.serverTimestamp(),
    });

    return conversationRef.id;
  }

  // ─────────────────────────────────────────────
  // MESSAGE SENDING
  // ─────────────────────────────────────────────

  Future<void> _sendMessage({
    required String conversationId,
    required Map<String, dynamic> messageData,
    required String lastMessage,
    required String lastMessageType,
  }) async {
    final batch = _firestore.batch();
    final msgRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();

    batch.set(msgRef, {
      ...messageData,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    batch.update(
      _firestore.collection('conversations').doc(conversationId),
      {
        'lastMessage': lastMessage,
        'lastMessageType': lastMessageType,
        'lastTimestamp': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

Future<Map<String, dynamic>> _currentUserMeta() async {

  final uid = currentUserId;
  final doc = await _firestore.collection('users').doc(uid).get();
  final data = doc.data() ?? {};

  return {
    'senderId': uid,
    'senderName':
        '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
    'senderPhoto': data['photo'] ?? '',
  };
}

  /// Send a plain text message
  Future<void> sendTextMessage({
    required String conversationId,
    required String text,
  }) async {
    final meta = await _currentUserMeta();
    await _sendMessage(
      conversationId: conversationId,
      messageData: {
        ...meta,
        'type': 'text',
        'text': text,
        'imageUrl': null,
        'bookingId': null,
        'paymentId': null,
      },
      lastMessage: text,
      lastMessageType: 'text',
    );
  }

  /// Upload image to Firebase Storage then send image message
  Future<void> sendImageMessage({
    required String conversationId,
    required File imageFile,
  }) async {
    final meta = await _currentUserMeta();
    final fileName = '${_uuid.v4()}.jpg';
    final ref = _storage.ref('conversations/$conversationId/$fileName');
    await ref.putFile(imageFile);
    final imageUrl = await ref.getDownloadURL();

    await _sendMessage(
      conversationId: conversationId,
      messageData: {
        ...meta,
        'type': 'image',
        'text': '📷 Photo',
        'imageUrl': imageUrl,
        'bookingId': null,
        'paymentId': null,
      },
      lastMessage: '📷 Photo',
      lastMessageType: 'image',
    );
  }

  /// Send a booking reference card
  Future<void> sendBookingReference({
    required String conversationId,
    required String bookingId,
  }) async {
    final meta = await _currentUserMeta();
    await _sendMessage(
      conversationId: conversationId,
      messageData: {
        ...meta,
        'type': 'booking_reference',
        'text': '📅 Booking Reference',
        'imageUrl': null,
        'bookingId': bookingId,
        'paymentId': null,
      },
      lastMessage: '📅 Booking Reference',
      lastMessageType: 'booking_reference',
    );
  }

  /// Send a payment reference card
  Future<void> sendPaymentReference({
    required String conversationId,
    required String paymentId,
  }) async {
    final meta = await _currentUserMeta();
    await _sendMessage(
      conversationId: conversationId,
      messageData: {
        ...meta,
        'type': 'payment_reference',
        'text': '💳 Payment Reference',
        'imageUrl': null,
        'bookingId': null,
        'paymentId': paymentId,
      },
      lastMessage: '💳 Payment Reference',
      lastMessageType: 'payment_reference',
    );
  }

  // ─────────────────────────────────────────────
  // READ RECEIPTS
  // ─────────────────────────────────────────────

  /// Mark all unread messages in a conversation as read for current user
  Future<void> markMessagesAsRead(String conversationId) async {
    final uid = currentUserId;
    final unread = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: uid)
        .get();

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ─────────────────────────────────────────────
  // REAL-TIME STREAMS
  // ─────────────────────────────────────────────

  /// Stream of messages for a conversation (ordered by timestamp)
  Stream<QuerySnapshot> getMessagesStream(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Stream of conversations for the current USER (guest)
  Stream<QuerySnapshot> getUserConversationsStream() {
    return _firestore
        .collection('conversations')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('lastTimestamp', descending: true)
        .snapshots();
  }

  /// Stream of conversations for the current HOST
  Stream<QuerySnapshot> getHostConversationsStream() {
    return _firestore
        .collection('conversations')
        .where('hostId', isEqualTo: currentUserId)
        .orderBy('lastTimestamp', descending: true)
        .snapshots();
  }

  /// Unread count for a conversation (messages NOT sent by current user)
  Stream<int> unreadCountStream(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: currentUserId)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // ─────────────────────────────────────────────
  // HELPER: Fetch other participant's info
  // ─────────────────────────────────────────────

Future<Map<String, dynamic>> getOtherParticipantInfo(
  String otherUserId) async {

  final doc = await _firestore.collection('users').doc(otherUserId).get();
  final data = doc.data() ?? {};

  return {
    'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
    'photo': data['photo'] ?? '',
  };
}
}