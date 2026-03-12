import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {

  final String bookingId;
  final double amount;
  final String method;
  final String status;
  final DateTime createdAt;

  PaymentModel({
    required this.bookingId,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      "bookingId": bookingId,
      "amount": amount,
      "method": method,
      "status": status,
      "createdAt": Timestamp.fromDate(createdAt),
    };
  }
}