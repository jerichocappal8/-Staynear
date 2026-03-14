import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'chat_service.dart';
import 'message_bubble.dart';

class ChatRoomScreen extends StatefulWidget {
  final String conversationId;
  final String otherParticipantId; // hostId if user, userId if host
  final String otherParticipantName;
  final String otherParticipantPhoto;
  final String propertyName;

  // Optional: pass bookingId / paymentId for quick-send buttons
  final String? bookingId;
  final String? paymentId;

  const ChatRoomScreen({
    super.key,
    required this.conversationId,
    required this.otherParticipantId,
    required this.otherParticipantName,
    required this.otherParticipantPhoto,
    required this.propertyName,
    this.bookingId,
    this.paymentId,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _chatService.markMessagesAsRead(widget.conversationId);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    setState(() => _isSending = true);
    try {
      await _chatService.sendTextMessage(
        conversationId: widget.conversationId,
        text: text,
      );
      _scrollToBottom();
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _isSending = true);
    try {
      await _chatService.sendImageMessage(
        conversationId: widget.conversationId,
        imageFile: File(picked.path),
      );
      _scrollToBottom();
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendBookingRef() async {
    if (widget.bookingId == null) {
      _showNoRefSnackbar('No booking linked to this chat yet.');
      return;
    }
    setState(() => _isSending = true);
    try {
      await _chatService.sendBookingReference(
        conversationId: widget.conversationId,
        bookingId: widget.bookingId!,
      );
      _scrollToBottom();
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendPaymentRef() async {
    if (widget.paymentId == null) {
      _showNoRefSnackbar('No payment linked to this chat yet.');
      return;
    }
    setState(() => _isSending = true);
    try {
      await _chatService.sendPaymentReference(
        conversationId: widget.conversationId,
        paymentId: widget.paymentId!,
      );
      _scrollToBottom();
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showNoRefSnackbar(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttachMenuSheet(
        onImageTap: () {
          Navigator.pop(context);
          _pickAndSendImage();
        },
        onBookingTap: () {
          Navigator.pop(context);
          _sendBookingRef();
        },
        onPaymentTap: () {
          Navigator.pop(context);
          _sendPaymentRef();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Property name banner
          _PropertyBanner(name: widget.propertyName),

          // ── Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _chatService.getMessagesStream(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                // Auto-mark as read on new messages
                _chatService.markMessagesAsRead(widget.conversationId);

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                if (docs.isEmpty) {
                  return const _EmptyChatPlaceholder();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final msg =
                        docs[index].data() as Map<String, dynamic>;
                    final isMine = msg['senderId'] == currentUid;
                    final showAvatar = !isMine &&
                        (index == 0 ||
                            (docs[index - 1].data()
                                    as Map<String, dynamic>)['senderId'] ==
                                currentUid);

                    return MessageBubble(
                      message: msg,
                      isMine: isMine,
                      showAvatar: showAvatar,
                    );
                  },
                );
              },
            ),
          ),

          // ── Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 20, color: Color(0xFF1A2B40)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE0E7EF),
            backgroundImage: widget.otherParticipantPhoto.isNotEmpty
                ? CachedNetworkImageProvider(widget.otherParticipantPhoto)
                : null,
            child: widget.otherParticipantPhoto.isEmpty
                ? const Icon(Icons.person,
                    size: 18, color: Color(0xFF94A3B8))
                : null,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.otherParticipantName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2B40),
                ),
              ),
              const Text(
                'Online',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF52C41A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.phone_outlined,
              color: Color(0xFF0077B6)),
          onPressed: () {},
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE5EAF0), height: 1),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        children: [
          // Attach button
          GestureDetector(
            onTap: _showAttachMenu,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Color(0xFF0077B6), size: 22),
            ),
          ),
          const SizedBox(width: 8),

          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle:
                      TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: _isSending ? null : _sendText,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isSending
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF0077B6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PROPERTY BANNER
// ─────────────────────────────────────────────

class _PropertyBanner extends StatelessWidget {
  final String name;
  const _PropertyBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0077B6).withOpacity(0.07),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.home_rounded,
              size: 15, color: Color(0xFF0077B6)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0077B6),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────

class _EmptyChatPlaceholder extends StatelessWidget {
  const _EmptyChatPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0077B6).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 40, color: Color(0xFF0077B6)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2B40),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Say hello to get started!',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ATTACH MENU BOTTOM SHEET
// ─────────────────────────────────────────────

class _AttachMenuSheet extends StatelessWidget {
  final VoidCallback onImageTap;
  final VoidCallback onBookingTap;
  final VoidCallback onPaymentTap;

  const _AttachMenuSheet({
    required this.onImageTap,
    required this.onBookingTap,
    required this.onPaymentTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E7EF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Send Attachment',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2B40),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachOption(
                icon: Icons.image_rounded,
                label: 'Photo',
                color: const Color(0xFF7B2FBE),
                onTap: onImageTap,
              ),
              _AttachOption(
                icon: Icons.calendar_today_rounded,
                label: 'Booking',
                color: const Color(0xFF0077B6),
                onTap: onBookingTap,
              ),
              _AttachOption(
                icon: Icons.payment_rounded,
                label: 'Payment',
                color: const Color(0xFF2D6A4F),
                onTap: onPaymentTap,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}