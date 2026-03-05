import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../edit_apartment_screen.dart';
import '../views_analytics_screen.dart';

class HostApartmentPreviewScreen extends StatelessWidget {
  final String propertyId;

  const HostApartmentPreviewScreen({
    super.key,
    required this.propertyId,
  });

  static const _bg = Color(0xFFF8F7F5);
  static const _orange = Color(0xFFFF8A00);
  static const _textDark = Color(0xFF1A1A2E);
  static const _textMid = Color(0xFF6B7280);
  static const _border = Color(0xFFEEECE8);

  @override
  Widget build(BuildContext context) {
    final docStream = FirebaseFirestore.instance
        .collection('properties')
        .doc(propertyId)
        .snapshots();

    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<DocumentSnapshot>(
        stream: docStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final images = List<String>.from(data['images'] ?? []);
          final amenities = List<String>.from(data['amenities'] ?? []);

          return Stack(
            children: [

              /// ================= SCROLL CONTENT =================
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    /// ================= IMAGE HEADER =================
                    Stack(
                      children: [
                        SizedBox(
                          height: 280,
                          width: double.infinity,
                          child: Image.network(
                            images.isNotEmpty ? images[0] : "",
                            fit: BoxFit.cover,
                          ),
                        ),

                        Positioned(
                          top: 50,
                          left: 16,
                          child: _circleIcon(
                            icon: Icons.arrow_back,
                            onTap: () => Navigator.pop(context),
                          ),
                        ),

                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "1/${images.length}",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    /// ================= TITLE =================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        data['name'] ?? "",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        data['location'] ?? "",
                        style: const TextStyle(
                          fontSize: 14,
                          color: _textMid,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "₱${data['price']} / month",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _orange,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// ================= AMENITIES =================
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "Home Facilities",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: amenities
                            .map(
                              (e) => Chip(
                                label: Text(e),
                                backgroundColor: Colors.grey[200],
                              ),
                            )
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// ================= DESCRIPTION =================
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "Description",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        data['description'] ?? "",
                        style: const TextStyle(
                          height: 1.6,
                          color: _textMid,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),

              /// ================= HOST ACTION BAR =================
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 20, 30),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: _border),
                    ),
                  ),
                  child: Row(
                    children: [

                      /// Edit Button
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _border),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EditApartmentScreen(
                                  docId: propertyId,
                                  data: data,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            "Edit",
                            style: TextStyle(
                                color: _textDark),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      /// Analytics Button
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ViewsAnalyticsScreen(
                                  propertyId: propertyId,
                                  propertyName:
                                      data['name'],
                                ),
                              ),
                            );
                          },
                          child: const Text("Analytics"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _circleIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18),
      ),
    );
  }
}