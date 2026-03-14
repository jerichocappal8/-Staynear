import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_room_screen.dart';

class ChatListHostScreen extends StatelessWidget {
  final String hostId;

  const ChatListHostScreen({super.key, required this.hostId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .where('hostId', isEqualTo: hostId)
            .orderBy('lastTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

  if (snapshot.connectionState == ConnectionState.waiting) {
    return const Center(child: CircularProgressIndicator());
  }

  if (!snapshot.hasData || snapshot.data == null) {
    return const Center(child: Text("No messages yet"));
  }

  final conversations = snapshot.data!.docs;

  if (conversations.isEmpty) {
    return const Center(child: Text("No messages yet"));
  }

  return ListView.builder(
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
      return const ListTile(
        leading: CircleAvatar(child: Icon(Icons.person)),
        title: Text("Loading..."),
      );
    }

    final userData =
        userSnapshot.data!.data() as Map<String, dynamic>? ?? {};

    final name = userData['name'] ?? "Guest";

    final photo = userData['photo'];

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: photo != null ? NetworkImage(photo) : null,
        child: photo == null ? const Icon(Icons.person) : null,
      ),
      title: Text(name.isEmpty ? "Guest" : name),
      subtitle: Text(lastMessage),
      trailing: Text(_formatTime(lastTimestamp)),
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
    );
  }

String _formatTime(Timestamp? ts) {
  if (ts == null) return "";

  final date = ts.toDate();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');

  return "$hour:$minute";
}
}