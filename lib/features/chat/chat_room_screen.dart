// chat_room_screen.dart
// ════════════════════════════════════════════════════════════════════════════
//  StayNear — Chat Room Screen  (UI redesign, all logic unchanged)
//
//  All ChatService calls, Firestore streams, send methods, image picker,
//  scroll logic, and navigation are identical to the original file.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'chat_service.dart';
import 'message_bubble.dart';
import 'package:staynear/core/app_colors.dart';

class ChatRoomScreen extends StatefulWidget {
  final String  conversationId;
  final String  otherParticipantId;
  final String  otherParticipantName;
  final String  otherParticipantPhoto;
  final String  propertyName;
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

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with SingleTickerProviderStateMixin {

  // ── original logic (unchanged) ─────────────────────────────────────────────
  final ChatService           _chatService    = ChatService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController      _scrollController = ScrollController();
  final ImagePicker           _picker         = ImagePicker();
  bool _isSending = false;

  // ── input focus for animated border ───────────────────────────────────────
  final FocusNode _focusNode = FocusNode();
  bool _inputFocused = false;

  @override
  void initState() {
    super.initState();
    _chatService.markMessagesAsRead(widget.conversationId);
    _focusNode.addListener(() {
      setState(() => _inputFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── original send helpers (unchanged) ─────────────────────────────────────

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
    final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primaryOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
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

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final isDark     = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: _buildAppBar(context, isDark),
      body: Column(
        children: [

          // ── property banner ──────────────────────────────────────────
          _PropertyBanner(name: widget.propertyName),

          // ── messages list ────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessagesStream(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryOrange, strokeWidth: 2.5),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                // original logic (unchanged)
                _chatService.markMessagesAsRead(widget.conversationId);
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                if (docs.isEmpty) return const _EmptyChatPlaceholder();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final msg    = docs[index].data() as Map<String, dynamic>;
                    final isMine = msg['senderId'] == currentUid;
                    final showAvatar = !isMine &&
                        (index == 0 ||
                            (docs[index - 1].data()
                                    as Map<String, dynamic>)['senderId'] ==
                                currentUid);

                    return MessageBubble(
                      message:    msg,
                      isMine:     isMine,
                      showAvatar: showAvatar,
                    );
                  },
                );
              },
            ),
          ),

          // ── input bar ────────────────────────────────────────────────
          _buildInputBar(context, isDark),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  APP BAR
  // ─────────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      backgroundColor:        AppColors.background(context),
      surfaceTintColor:       Colors.transparent,
      scrolledUnderElevation: 0,
      elevation:              0,
      titleSpacing:           0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:         AppColors.card(context),
            borderRadius: BorderRadius.circular(12),
            border:        Border.all(color: AppColors.border),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 15, color: AppColors.text(context)),
        ),
      ),
      title: Row(children: [
        // avatar with online ring
        Stack(
          children: [
            Container(
              width:  42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(.35), width: 2),
              ),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.orangeLight,
                backgroundImage: widget.otherParticipantPhoto.isNotEmpty
                    ? CachedNetworkImageProvider(widget.otherParticipantPhoto)
                    : null,
                child: widget.otherParticipantPhoto.isEmpty
                    ? Text(
                        widget.otherParticipantName.isNotEmpty
                            ? widget.otherParticipantName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w800,
                          color:      AppColors.primaryOrange,
                        ),
                      )
                    : null,
              ),
            ),
            Positioned(
              right: 1, bottom: 1,
              child: Container(
                width:  11,
                height: 11,
                decoration: BoxDecoration(
                  color:  const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.background(context), width: 2),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.otherParticipantName,
                style: TextStyle(
                  fontSize:      15,
                  fontWeight:    FontWeight.w800,
                  color:         AppColors.text(context),
                  letterSpacing: -.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Row(children: [
                Container(
                  width:  6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Color(0xFF22C55E), shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                const Text('Online',
                    style: TextStyle(
                        fontSize:   11,
                        color:      Color(0xFF22C55E),
                        fontWeight: FontWeight.w600)),
              ]),
            ],
          ),
        ),
      ]),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: _IconActionBtn(
            icon:  Icons.phone_rounded,
            color: AppColors.primaryOrange,
            onTap: () {},
          ),
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
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  INPUT BAR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildInputBar(BuildContext context, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve:    Curves.easeOut,
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(
          top: BorderSide(
            color: _inputFocused
                ? AppColors.primaryOrange.withOpacity(.35)
                : isDark
                    ? AppColors.darkCardSoft.withOpacity(.5)
                    : AppColors.border,
            width: _inputFocused ? 1.5 : 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(isDark ? .18 : .05),
            blurRadius: 16,
            offset:     const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left:   12,
        right:  12,
        top:    10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _AttachBtn(onTap: _showAttachMenu),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkCardSoft.withOpacity(.5)
                    : AppColors.bgLight,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _inputFocused
                      ? AppColors.primaryOrange.withOpacity(.45)
                      : Colors.transparent,
                  width: 1.3,
                ),
              ),
              child: TextField(
                controller:         _textController,
                focusNode:          _focusNode,
                maxLines:           4,
                minLines:           1,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                    fontSize: 14.5, color: AppColors.text(context)),
                decoration: const InputDecoration(
                  hintText:       'Message...',
                  hintStyle:      TextStyle(
                      color: AppColors.textLight, fontSize: 14.5),
                  border:         InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendBtn(
              isSending: _isSending,
              onTap:     _isSending ? null : _sendText),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ICON ACTION BUTTON (app bar call button)
// ─────────────────────────────────────────────────────────────────────────────

class _IconActionBtn extends StatefulWidget {
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  const _IconActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  State<_IconActionBtn> createState() => _IconActionBtnState();
}

class _IconActionBtnState extends State<_IconActionBtn> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _scale = .90),
      onTapUp:     (_) { setState(() => _scale = 1.0); widget.onTap(); },
      onTapCancel: ()  => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale:    _scale,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width:  38,
          height: 38,
          decoration: BoxDecoration(
            color:         widget.color.withOpacity(.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(widget.icon, size: 18, color: widget.color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ATTACH BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _AttachBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _AttachBtn({required this.onTap});

  @override
  State<_AttachBtn> createState() => _AttachBtnState();
}

class _AttachBtnState extends State<_AttachBtn> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) { setState(() => _scale = .90); HapticFeedback.lightImpact(); },
      onTapUp:     (_) { setState(() => _scale = 1.0); widget.onTap(); },
      onTapCancel: ()  => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale:    _scale,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width:  44,
          height: 44,
          decoration: BoxDecoration(
            color:         AppColors.orangeLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.add_rounded,
              color: AppColors.primaryOrange, size: 22),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SEND BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _SendBtn extends StatefulWidget {
  final bool          isSending;
  final VoidCallback? onTap;
  const _SendBtn({required this.isSending, required this.onTap});

  @override
  State<_SendBtn> createState() => _SendBtnState();
}

class _SendBtnState extends State<_SendBtn> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) { setState(() => _scale = .90); HapticFeedback.lightImpact(); }
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width:  44,
          height: 44,
          decoration: BoxDecoration(
            gradient: widget.isSending
                ? null
                : const LinearGradient(
                    colors: [Color(0xFFFF8C00), AppColors.primaryOrange],
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                  ),
            color:         widget.isSending ? AppColors.textLight : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: widget.isSending
                ? []
                : [
                    BoxShadow(
                      color:      AppColors.primaryOrange.withOpacity(.35),
                      blurRadius: 12,
                      offset:     const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: widget.isSending
                ? const SizedBox(
                    width:  18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded,
                    color: Colors.white, size: 19),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROPERTY BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _PropertyBanner extends StatelessWidget {
  final String name;
  const _PropertyBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) return const SizedBox.shrink();

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        border: Border(
          bottom: BorderSide(
              color: AppColors.primaryOrange.withOpacity(.20), width: 1),
        ),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color:         AppColors.primaryOrange.withOpacity(.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.apartment_rounded,
              size: 13, color: AppColors.primaryOrange),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontSize:   12,
              fontWeight: FontWeight.w600,
              color:      AppColors.primaryOrange,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPTY CHAT PLACEHOLDER
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyChatPlaceholder extends StatelessWidget {
  const _EmptyChatPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  80,
              height: 80,
              decoration: const BoxDecoration(
                  color: AppColors.orangeLight, shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 36, color: AppColors.primaryOrange),
            ),
            const SizedBox(height: 20),
            Text(
              'Start the conversation',
              style: TextStyle(
                fontSize:      18,
                fontWeight:    FontWeight.w800,
                color:         AppColors.text(context),
                letterSpacing: -.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Say hello to get started!',
              style: TextStyle(
                  fontSize: 13.5, color: AppColors.textMid, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ATTACH MENU BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin:  const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color:         AppColors.card(context),
        borderRadius: BorderRadius.circular(28),
        border:        Border.all(
            color: isDark
                ? AppColors.darkCardSoft.withOpacity(.5)
                : AppColors.border),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(.10),
              blurRadius: 24,
              offset:     const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  36,
            height: 4,
            decoration: BoxDecoration(
                color:         AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 18),
          Text(
            'Send Attachment',
            style: TextStyle(
              fontSize:      16,
              fontWeight:    FontWeight.w800,
              color:         AppColors.text(context),
              letterSpacing: -.3,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachOption(
                icon:  Icons.image_rounded,
                label: 'Photo',
                color: const Color(0xFF8B5CF6),
                onTap: onImageTap,
              ),
              _AttachOption(
                icon:  Icons.calendar_month_rounded,
                label: 'Booking',
                color: AppColors.primaryOrange,
                onTap: onBookingTap,
              ),
              _AttachOption(
                icon:  Icons.payments_rounded,
                label: 'Payment',
                color: const Color(0xFF10B981),
                onTap: onPaymentTap,
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _AttachOption extends StatefulWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AttachOption> createState() => _AttachOptionState();
}

class _AttachOptionState extends State<_AttachOption> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) { setState(() => _scale = .90); HapticFeedback.lightImpact(); },
      onTapUp:     (_) { setState(() => _scale = 1.0); widget.onTap(); },
      onTapCancel: ()  => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale:    _scale,
        duration: const Duration(milliseconds: 120),
        curve:    Curves.easeOut,
        child: Column(children: [
          Container(
            width:  62,
            height: 62,
            decoration: BoxDecoration(
              color:         widget.color.withOpacity(.10),
              borderRadius: BorderRadius.circular(20),
              border:        Border.all(
                  color: widget.color.withOpacity(.20), width: 1),
            ),
            child: Icon(widget.icon, color: widget.color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            widget.label,
            style: TextStyle(
              fontSize:   12.5,
              fontWeight: FontWeight.w600,
              color:      widget.color,
            ),
          ),
        ]),
      ),
    );
  }
}