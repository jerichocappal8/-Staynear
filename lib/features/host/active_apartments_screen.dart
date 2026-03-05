import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'presentation/host_apartment_preview_screen.dart';

class ActiveApartmentsScreen extends StatelessWidget {
  const ActiveApartmentsScreen({super.key});

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  static const _toggleOrange = Color(0xFFFF8A00);
  static const _orange = Color(0xFFFF6B35);
  static const _bg = Color(0xFFF8F7F5);
  static const _cardBg = Colors.white;
  static const _textDark = Color(0xFF1A1A2E);
  static const _textMid = Color(0xFF6B7280);
  static const _textLight = Color(0xFF9CA3AF);
  static const _border = Color(0xFFEEECE8);

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('properties')
        .where('ownerId', isEqualTo: uid)
        .snapshots();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "My Listings",
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: _textDark),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No listings yet",
                style: TextStyle(color: _textMid),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final image =
                  (data['images'] != null && data['images'].isNotEmpty)
                      ? data['images'][0]
                      : null;

              final views = data['views'] ?? 0;
              final inquiries = data['inquiries'] ?? 0;
              final isActive = data['status'] == 'active';

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.04),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    /// IMAGE
                    if (image != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          image,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),

                    const SizedBox(height: 14),

                    /// TITLE + STATUS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            data['name'] ?? "",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.green.withOpacity(.15)
                                : Colors.red.withOpacity(.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isActive ? "ACTIVE" : "INACTIVE",
                            style: TextStyle(
                              color: isActive
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    /// LOCATION
                    Text(
                      data['location'] ?? "",
                      style: const TextStyle(
                        fontSize: 13,
                        color: _textMid,
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// PRICE
                    Text(
                      "₱${data['price']} / month",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _orange,
                      ),
                    ),

                    const SizedBox(height: 14),

                    /// STATS
                    Row(
                      children: [
                        _statItem(Icons.visibility_rounded, "$views Views"),
                        const SizedBox(width: 18),
                        _statItem(Icons.chat_bubble_outline_rounded,
                            "$inquiries Inquiries"),
                      ],
                    ),

                    const SizedBox(height: 18),

                    /// BUTTONS
                    Row(
                      children: [

                        /// VIEW (GO TO HOST PREVIEW PAGE)
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      HostApartmentPreviewScreen(
                                    propertyId: doc.id,
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              "View",
                              style: TextStyle(color: _textDark),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        /// TOGGLE ACTIVE
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _toggleOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('properties')
                                  .doc(doc.id)
                                  .update({
                                "status":
                                    isActive ? "inactive" : "active"
                              });
                            },
                            child: Text(
                              isActive ? "Pause" : "Activate",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _statItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _textMid),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textMid,
          ),
        ),
      ],
    );
  }
}