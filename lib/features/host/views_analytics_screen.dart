import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewsAnalyticsScreen extends StatelessWidget {
  final String propertyId;
  final String propertyName;

  const ViewsAnalyticsScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  static const _bg = Color(0xFFF8F7F5);
  static const _cardBg = Colors.white;
  static const _textDark = Color(0xFF1A1A2E);
  static const _textMid = Color(0xFF6B7280);
  static const _orange = Color(0xFFFF8A00);
  static const _border = Color(0xFFEEECE8);

  @override
  Widget build(BuildContext context) {
    final analyticsStream = FirebaseFirestore.instance
        .collection('properties')
        .doc(propertyId)
        .collection('analytics')
        .snapshots();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "$propertyName Analytics",
          style: const TextStyle(
              color: _textDark, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: _textDark),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: analyticsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          final totalViews = docs.length;

          final uniqueUsers = docs
              .map((e) => e['userId'])
              .toSet()
              .length;

          final contactClicks = docs
              .where((e) => e['contactClicked'] == true)
              .length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [

                _statCard("Total Views", totalViews.toString()),
                const SizedBox(height: 16),

                _statCard("Unique Viewers", uniqueUsers.toString()),
                const SizedBox(height: 16),

                _statCard("Contact Clicks", contactClicks.toString()),
                const SizedBox(height: 16),

                _statCard(
                    "Avg Session (sec)",
                    _averageSession(docs).toStringAsFixed(1)),

                const SizedBox(height: 30),

                const Text(
                  "Daily Views (Chart Coming Next)",
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _textDark),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _averageSession(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;

    final total = docs.fold<double>(
        0,
        (sum, e) =>
            sum + (e['sessionDuration'] ?? 0).toDouble());

    return total / docs.length;
  }

  Widget _statCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15, color: _textMid)),
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _orange)),
        ],
      ),
    );
  }
}