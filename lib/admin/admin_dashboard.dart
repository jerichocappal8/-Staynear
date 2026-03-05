import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Requests'),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('host_requests')
            .orderBy('submittedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No host requests yet"));
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (_, i) {

              final doc = requests[i];
              final data = doc.data() as Map<String, dynamic>;

              final address = data['address'];

              // ✅ SAFE ADDRESS HANDLING (new + old format)
              String city = '';
              String province = '';

              if (address is Map<String, dynamic>) {
                city = address['city'] ?? '';
                province = address['province'] ?? '';
              } else if (address is String) {
                city = address;
              }

              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text(
                    data['fullName'] ?? 'No name',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "$city $province\nStatus: ${data['status']}",
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ✅ APPROVE
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _approve(doc.id),
                      ),

                      // ❌ REJECT
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _reject(doc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ======================
  // APPROVE HOST
  // ======================
  Future<void> _approve(String uid) async {

    // Update request status
    await FirebaseFirestore.instance
        .collection('host_requests')
        .doc(uid)
        .update({'status': 'approved'});

    // Create host profile
    await FirebaseFirestore.instance
        .collection('hosts')
        .doc(uid)
        .set({
          'userId': uid,
          'rating': 0,
          'totalListings': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });

    // 🔥 THIS IS THE IMPORTANT PART
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
          'hostRequest': 'approved',
          'isHost': true, // 👈 unlocks host dashboard
        });
  }

  // ======================
  // REJECT HOST
  // ======================
  Future<void> _reject(String uid) async {

    await FirebaseFirestore.instance
        .collection('host_requests')
        .doc(uid)
        .update({'status': 'rejected'});

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
          'hostRequest': 'rejected',
          'isHost': false,
        });
  }
}