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
    source: ImageSource.gallery,
    imageQuality: 80,
  );
  if (picked == null) return;

  final File imageFile = File(picked.path);

  final bool? send = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withOpacity(0.85),
    transitionDuration: const Duration(milliseconds: 400),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutExpo,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return _ImagePreviewDialog(imageFile: imageFile);
    },
  );

  if (send != true) return;

  setState(() => _isSending = true);
  try {
    await _chatService.sendImageMessage(
      conversationId: widget.conversationId,
      imageFile: imageFile,
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
class _ImagePreviewDialog extends StatefulWidget {
  final File imageFile;
  const _ImagePreviewDialog({required this.imageFile});

  @override
  State<_ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<_ImagePreviewDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _shimmer;
  late Animation<double> _btnSlide;
  late Animation<double> _btnFade;

  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    _btnSlide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _btnFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Futuristic corner-bracket frame ──
            _FuturisticImageFrame(
              imageFile: widget.imageFile,
              shimmer: _shimmer,
            ),

            const SizedBox(height: 6),

            // ── Label ──
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Opacity(
                opacity: _btnFade.value,
                child: Text(
  'PREVIEW',
  style: TextStyle(
    color: AppColors.primaryOrange.withOpacity(0.6),
    fontSize: 10,
    letterSpacing: 1.2,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.none,
    height: 1,
  ),
),
              ),
            ),

            const SizedBox(height: 16),

            // ── Buttons ──
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _btnSlide.value),
                child: Opacity(
                  opacity: _btnFade.value,
                  child: Row(
                    children: [
                      // Cancel
                      Expanded(
                        child: _DialogButton(
                          label: 'CANCEL',
                          icon: Icons.close_rounded,
                          isAccent: false,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context, false);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Send
                      Expanded(
                        child: _DialogButton(
                          label: 'SEND',
                          icon: Icons.send_rounded,
                          isAccent: true,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(context, true);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Corner-bracket image frame with shimmer ──────────────────────────────────
class _FuturisticImageFrame extends StatelessWidget {
  final File imageFile;
  final Animation<double> shimmer;

  const _FuturisticImageFrame({
    required this.imageFile,
    required this.shimmer,
  });

  @override
  Widget build(BuildContext context) {
    const cornerSize = 18.0;
    const cornerThickness = 2.5;
    const cornerColor = AppColors.primaryOrange;

    return AnimatedBuilder(
      animation: shimmer,
      builder: (_, __) {
        return Stack(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment(shimmer.value - 1, -0.3),
                  end: Alignment(shimmer.value, 0.3),
                  colors: [
                    Colors.white.withOpacity(0),
                    Colors.white.withOpacity(0.12),
                    Colors.white.withOpacity(0),
                  ],
                ).createShader(bounds),
                blendMode: BlendMode.srcATop,
                child: Image.file(
                  imageFile,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Corner brackets — top-left
            Positioned(
              top: 0, left: 0,
              child: _Corner(
                color: cornerColor,
                size: cornerSize,
                thickness: cornerThickness,
                corners: {_CornerSide.topLeft},
              ),
            ),
            // top-right
            Positioned(
              top: 0, right: 0,
              child: _Corner(
                color: cornerColor,
                size: cornerSize,
                thickness: cornerThickness,
                corners: {_CornerSide.topRight},
              ),
            ),
            // bottom-left
            Positioned(
              bottom: 0, left: 0,
              child: _Corner(
                color: cornerColor,
                size: cornerSize,
                thickness: cornerThickness,
                corners: {_CornerSide.bottomLeft},
              ),
            ),
            // bottom-right
            Positioned(
              bottom: 0, right: 0,
              child: _Corner(
                color: cornerColor,
                size: cornerSize,
                thickness: cornerThickness,
                corners: {_CornerSide.bottomRight},
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _CornerSide { topLeft, topRight, bottomLeft, bottomRight }

class _Corner extends StatelessWidget {
  final Color color;
  final double size;
  final double thickness;
  final Set<_CornerSide> corners;

  const _Corner({
    required this.color,
    required this.size,
    required this.thickness,
    required this.corners,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          color: color,
          thickness: thickness,
          corners: corners,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final Set<_CornerSide> corners;

  _CornerPainter({
    required this.color,
    required this.thickness,
    required this.corners,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final w = size.width;
    final h = size.height;

    for (final corner in corners) {
      switch (corner) {
        case _CornerSide.topLeft:
          canvas.drawLine(Offset(0, h), Offset(0, 0), paint);
          canvas.drawLine(Offset(0, 0), Offset(w, 0), paint);
          break;
        case _CornerSide.topRight:
          canvas.drawLine(Offset(0, 0), Offset(w, 0), paint);
          canvas.drawLine(Offset(w, 0), Offset(w, h), paint);
          break;
        case _CornerSide.bottomLeft:
          canvas.drawLine(Offset(0, 0), Offset(0, h), paint);
          canvas.drawLine(Offset(0, h), Offset(w, h), paint);
          break;
        case _CornerSide.bottomRight:
          canvas.drawLine(Offset(w, 0), Offset(w, h), paint);
          canvas.drawLine(Offset(w, h), Offset(0, h), paint);
          break;
      }
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

// ── Pressable button ─────────────────────────────────────────────────────────
class _DialogButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isAccent;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.icon,
    required this.isAccent,
    required this.onTap,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isAccent
        ? const LinearGradient(
            colors: [Color(0xFFFF8C00), AppColors.primaryOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.03),
            ],
          );

    final border = widget.isAccent
        ? Border.all(color: AppColors.primaryOrange.withOpacity(0.6), width: 1)
        : Border.all(color: Colors.white.withOpacity(0.15), width: 1);

    final shadow = widget.isAccent
        ? [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ]
        : <BoxShadow>[];

    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: bg,
            borderRadius: BorderRadius.circular(12),
            border: border,
            boxShadow: shadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 15,
                color: widget.isAccent
                    ? Colors.white
                    : Colors.white.withOpacity(0.6),
              ),
              const SizedBox(width: 7),
              Text(
  widget.label,
  style: TextStyle(
    color: widget.isAccent
        ? Colors.white
        : Colors.white.withOpacity(0.6),
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    decoration: TextDecoration.none,
    height: 1,
  ),
),
            ],
          ),
        ),
      ),
    );
  }
}