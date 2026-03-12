import 'package:cloud_firestore/cloud_firestore.dart';

class RoomOccupancyModel {

  final String bookingId;
  final String apartmentId;
  final String roomId;

  final DateTime checkIn;
  final DateTime checkOut;

  final String pricingMode; // daily or monthly

  final String guestName;
  final String guestId;

  RoomOccupancyModel({
    required this.bookingId,
    required this.apartmentId,
    required this.roomId,
    required this.checkIn,
    required this.checkOut,
    required this.pricingMode,
    required this.guestName,
    required this.guestId,
  });

  Map<String, dynamic> toMap() {
    return {
      "bookingId": bookingId,
      "apartmentId": apartmentId,
      "roomId": roomId,
      "checkIn": Timestamp.fromDate(checkIn),
      "checkOut": Timestamp.fromDate(checkOut),
      "pricingMode": pricingMode,
      "guestName": guestName,
      "guestId": guestId,
      "status": "occupied",
      "createdAt": Timestamp.now(),
    };
  }
}