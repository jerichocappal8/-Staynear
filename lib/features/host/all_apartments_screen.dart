import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_apartment_screen.dart';
import 'package:staynear/core/app_colors.dart';

class AllApartmentsScreen extends StatelessWidget {
  const AllApartmentsScreen({super.key});

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('properties')
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [

            // ===== HEADER =====
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
  Icons.arrow_back_ios_new,
  color: AppColors.text(context),
),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "All Apartments",
                        style: TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w600,
  color: AppColors.text(context),
),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ===== LIST =====
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: stream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "No apartments yet",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];

                      return _modernCard(
                        context,
                        doc.id,
                        doc.data() as Map<String, dynamic>,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modernCard(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            blurRadius: 25,
            color: Colors.black.withOpacity(.04),
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ===== TITLE + STATUS =====
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data['name'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
  decoration: BoxDecoration(
    color: AppColors.orangeLight,
    borderRadius: BorderRadius.circular(30),
  ),
  child: Text(
    (data['status'] ?? "active")
        .toString()
        .toUpperCase(),
    style: const TextStyle(
      color: AppColors.primaryOrange,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
  ),
),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            data['location'] ?? "",
            style: const TextStyle(
              color: AppColors.textMid,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            "₱${data['price']} / month",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryOrange,
            ),
          ),

          const SizedBox(height: 20),

          // ===== BUTTONS =====
          Row(
            children: [

              // EDIT (light button)
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditApartmentScreen(
                            docId: id,
                            data: data,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      "Edit",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // DELETE (soft red)
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: AppColors.danger
                  ),
                  child: TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(30),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "Delete Apartment",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "Are you sure you want to delete this apartment? This action cannot be undone.",
                                    textAlign: TextAlign.center,
                                    style:
                                        TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          onPressed: () =>
                                              Navigator.pop(
                                                  context, false),
                                          child:
                                              const Text("Cancel"),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          height: 45,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius
                                                    .circular(30),
                                            color: const Color(
                                                0xffFF4D4F),
                                          ),
                                          child: TextButton(
                                            onPressed: () =>
                                                Navigator.pop(
                                                    context,
                                                    true),
                                            child: Text(
                                              "Delete",
                                              style: TextStyle(
                                                  color:
                                                      Colors.white),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      );

                      if (confirm == true) {
                        await FirebaseFirestore.instance
                            .collection('properties')
                            .doc(id)
                            .delete();
                      }
                    },
                    child: Text(
                      "Delete",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}