import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String   bookingId;
  final String   userId;       // tenant who made the payment
  final String   hostId;       // host who receives the payment
  // Same value as BookingModel.apartmentId; kept as propertyId on payments
  // for existing rules and host revenue queries.
  final String   propertyId;
  final double   amount;
  final String   method;
  final String   status;       // 'success' | 'failed' | 'refunded'
  final DateTime createdAt;

  PaymentModel({
    required this.bookingId,
    required this.userId,
    required this.hostId,
    required this.propertyId,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'bookingId':  bookingId,
      'userId':     userId,
      'hostId':     hostId,
      'propertyId': propertyId,
      'amount':     amount,
      'method':     method,
      'status':     status,
      'createdAt':  Timestamp.fromDate(createdAt),
    };
  }
}
