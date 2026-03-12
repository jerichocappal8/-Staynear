import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../edit_apartment_screen.dart';
import '../views_analytics_screen.dart';
import 'package:staynear/core/app_colors.dart';

class HostApartmentPreviewScreen extends StatelessWidget {
  final String propertyId;

  const HostApartmentPreviewScreen({
    super.key,
    required this.propertyId,
  });
  @override
  Widget build(BuildContext context) {
    final docStream = FirebaseFirestore.instance
        .collection('properties')
        .doc(propertyId)
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.background(context),
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
  context: context,
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
                              style: TextStyle(
                                  color: AppColors.card(context), fontSize: 12),
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
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text(context),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        data['location'] ?? "",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMid,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "₱${data['price']} / month",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryOrange,
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
                                backgroundColor: AppColors.card(context),
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
                        style: TextStyle(
                          height: 1.6,
                          color: AppColors.textMid,
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
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    border: Border(
                      top: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [

                      /// Edit Button
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
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
                          child: Text(
                            "Edit",
                            style: TextStyle(
                                color: AppColors.text(context)),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      /// Analytics Button
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
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
                          child: Text("Analytics"),
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
  required BuildContext context,
  required IconData icon,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.card(context),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(8),
      child: Icon(
        icon,
        size: 18,
        color: AppColors.text(context),
      ),
    ),
  );
}
}