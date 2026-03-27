// lib/models/testimonial.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Testimonial {
  final String name;
  final String photoUrl;
  final String userId; // ADD THIS
  final double rating;
  final String comment;
  final DateTime? createdAt;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double amountPaid;

  const Testimonial({
    required this.name,
    required this.photoUrl,
    required this.userId,
    required this.rating,
    required this.comment,
    this.createdAt,
    this.checkIn,
    this.checkOut,
    this.amountPaid = 0,
  });

  factory Testimonial.fromReviewDoc(Map<String, dynamic> d) {
    DateTime? _ts(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return Testimonial(
      name: d['guestName'] ?? 'Guest',
      photoUrl: '', // we will load from users collection
      userId: d['userId'] ?? '',
      rating: ((d['rating'] ?? 0) as num).toDouble(),
      comment: d['comment'] ?? '',
      createdAt: _ts(d['createdAt']),
      checkIn: _ts(d['checkIn']),
      checkOut: _ts(d['checkOut']),
      amountPaid: ((d['amountPaid'] ?? 0) as num).toDouble(),
    );
  }
}