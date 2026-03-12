import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'all_apartments_screen.dart';
import 'active_apartments_screen.dart';
import 'add_apartment_screen.dart';
import 'host_bottom_nav.dart';
import 'package:staynear/core/app_colors.dart';

class HostDashboardScreen extends StatelessWidget {
  const HostDashboardScreen({super.key});

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final propertiesRef = FirebaseFirestore.instance
        .collection('properties')
        .where('ownerId', isEqualTo: uid);

    return Scaffold(
      backgroundColor: AppColors.background(context),

      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: propertiesRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData) {
              return const Center(child: Text("No data"));
            }

            final docs = snapshot.data!.docs;

            final total = docs.length;
            final active =
                docs.where((d) => (d['isActive'] ?? false) == true).length;
            final recent = docs.take(3).toList();

            // 🔥 You can connect these later
            final viewsTotal = 0;
            final inquiriesTotal = 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ================= HEADER =================

                  Text(
                    "Good morning, Admin!",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Here’s your latest review",
                    style: TextStyle(color: AppColors.textMid),
                  ),

                  const SizedBox(height: 24),

                  // ================= STATS =================

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.1, // ✅ prevents overflow
                    children: [
_statCard(context,
  icon: Icons.apartment,
  color: Colors.blue,
  number: total.toString(),
  label: "Total Apartments",
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllApartmentsScreen(),
      ),
    );
  },
),

_statCard(context,
  icon: Icons.home,
  color: Colors.orange,
  number: active.toString(),
  label: "My Apartments",
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveApartmentsScreen(),
      ),
    );
  },
),
                      _statCard(context,
                        icon: Icons.remove_red_eye,
                        color: Colors.green,
                        number: viewsTotal.toString(),
                        label: "Views Total",
                      ),
                      _statCard(context,
                        icon: Icons.chat_bubble,
                        color: Colors.purple,
                        number: inquiriesTotal.toString(),
                        label: "Inquiries",
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ================= RECENT LISTINGS =================

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Recent Listings",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                      ),
                      Icon(Icons.chevron_right),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 10,
                          color: Colors.black.withOpacity(.05),
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: recent.isEmpty
                        ? Text(
                            "No listings yet",
                            style: TextStyle(color: Colors.grey),
                          )
                        : Column(
    children: recent.map((doc) {

      final data = doc.data() as Map<String, dynamic>;

      return Column(
        children: [
          _listingItem(
            data['name'] ?? "Unnamed",
            data['address'] ?? "No location",
            (data['isActive'] ?? false) ? "active" : "inactive",
          ),
          const SizedBox(height: 12),
        ],
      );
    }).toList(),
),
                  ),

                  const SizedBox(height: 30),

                  // ================= ADD BUTTON =================

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AddApartmentScreen(),
                        ),
                      );
                    },
                    child: Container(
                      height: 60,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
  colors: [
    AppColors.primaryOrange,
    Color(0xffFF7043),
  ],
),
                      ),
                      child: const Center(
                        child: Text(
                          "Add Apartment",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),

      // ================= REUSABLE BOTTOM NAV =================

      bottomNavigationBar: HostBottomNav(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) return;
          // Add navigation logic later
        },
      ),
    );
  }

  // ================= STAT CARD =================

Widget _statCard(BuildContext context, {
  required IconData icon,
  required Color color,
  required String number,
  required String label,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black.withOpacity(.05),
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            number,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    ),
  );
}

  // ================= LISTING ITEM =================

  Widget _listingItem(
      String name, String location, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style:
                  const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              location,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}