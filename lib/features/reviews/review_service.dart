// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/features/reviews/review_service.dart
//
//  Firestore structure:
//  ┌──────────────────────────────────────────────────────────────────────┐
//  │  reviews/{bookingId}_review                                          │
//  │  ├── bookingId        : String   (unique — one review per booking)   │
//  │  ├── apartmentId      : String                                       │
//  │  ├── apartmentName    : String                                       │
//  │  ├── userId           : String                                       │
//  │  ├── hostId           : String                                       │
//  │  ├── guestName        : String                                       │
//  │  ├── rating           : int      (1–5)                               │
//  │  ├── comment          : String                                       │
//  │  ├── checkIn          : Timestamp                                    │
//  │  ├── checkOut         : Timestamp                                    │
//  │  ├── amountPaid       : double                                       │
//  │  └── createdAt        : Timestamp (serverTimestamp)                  │
//  └──────────────────────────────────────────────────────────────────────┘
//
//  Security rules tip (Firestore):
//    allow create: if request.auth.uid == request.resource.data.userId
//                  && !exists(/databases/$(database)/documents/reviews/
//                      $(request.resource.data.bookingId + '_review'));
//    allow read: if true;
// ════════════════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewService {
  ReviewService._();

  static final _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  //  Submit a review
  //  Throws if this booking already has a review.
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> submitReview({
    required String bookingId,
    required String apartmentId,
    required String apartmentName,
    required String userId,
    required String hostId,
    required String guestName,
    required int rating,
    required String comment,
    required DateTime checkIn,
    required DateTime checkOut,
    required double amountPaid,
  }) async {
    // Guard: one review per booking — deterministic doc ID makes this an O(1)
    // existence check instead of a collection query, and eliminates the race
    // window that existed between the old hasReview() query and the batch write.
    final reviewDocId = '${bookingId}_review';
    final reviewRef   = _db.collection('reviews').doc(reviewDocId);

    final existing = await reviewRef.get();
    if (existing.exists) {
      throw Exception('A review for this booking already exists.');
    }

    final batch = _db.batch();

    // 1. Create the review document
    batch.set(reviewRef, {
      'bookingId': bookingId,
      'apartmentId': apartmentId,
      'apartmentName': apartmentName,
      'userId': userId,
      'hostId': hostId,
      'guestName': guestName,
      'rating': rating,
      'comment': comment.trim(),
      'checkIn': Timestamp.fromDate(checkIn),
      'checkOut': Timestamp.fromDate(checkOut),
      'amountPaid': amountPaid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Mark booking as reviewed so the UI can react
    final bookingRef = _db.collection('bookings').doc(bookingId);
    batch.update(bookingRef, {'hasReview': true});
await batch.commit();

// Update apartment rating and review count
await updateApartmentRating(apartmentId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Check if a review already exists for this booking
  // ─────────────────────────────────────────────────────────────────────────

  static Future<bool> hasReview(String bookingId) async {
    final snap = await _db
        .collection('reviews')
        .doc('${bookingId}_review')
        .get();
    return snap.exists;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Fetch all reviews for a given apartment (for host/admin dashboards)
  // ─────────────────────────────────────────────────────────────────────────

  static Stream<QuerySnapshot> reviewsForApartment(String apartmentId) {
    return _db
        .collection('reviews')
        .where('apartmentId', isEqualTo: apartmentId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
static Future<void> updateApartmentRating(String apartmentId) async {
  final propertyRef = _db.collection('properties').doc(apartmentId);

  final reviewsSnap = await _db
      .collection('reviews')
      .where('apartmentId', isEqualTo: apartmentId)
      .get();

  if (reviewsSnap.docs.isEmpty) {
    await propertyRef.set({
      'rating': 0,
      'reviewCount': 0,
    }, SetOptions(merge: true));
    return;
  }

  double total = 0;
  for (var doc in reviewsSnap.docs) {
    total += (doc['rating'] as num).toDouble();
  }

  final avg = total / reviewsSnap.docs.length;

  await propertyRef.set({
    'rating': double.parse(avg.toStringAsFixed(1)),
    'reviewCount': reviewsSnap.docs.length,
  }, SetOptions(merge: true));
}
}