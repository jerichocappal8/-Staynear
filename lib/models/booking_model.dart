import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String apartmentId;
  final String apartmentName;
  final String apartmentImage;

  final String roomId;
  final String roomName;

  final String userId;
  final String hostId;

  final String guestName;
  final String guestEmail;

  final DateTime checkIn;
  final DateTime checkOut;

  final String pricingMode;

  final double priceMonthly;
  final int monthsStayed;

  final double stayTotal;
  final double serviceFee;

  /// NEW
  final double securityDeposit;

  /// NEW
  final double totalDueToday;

  final double totalPrice;
  final double amountPaid;
  final double remainingBalance;

  final String paymentStatus;
  final String bookingStatus;

  final DateTime createdAt;

  BookingModel({
    required this.apartmentId,
    required this.apartmentName,
    required this.apartmentImage,
    required this.roomId,
    required this.roomName,
    required this.userId,
      required this.hostId,
    required this.guestName,
    required this.guestEmail,
    required this.checkIn,
    required this.checkOut,
    required this.pricingMode,
    required this.priceMonthly,
    required this.monthsStayed,
    required this.stayTotal,
    required this.serviceFee,
    required this.securityDeposit,
    required this.totalDueToday,
    required this.totalPrice,
    required this.amountPaid,
    required this.remainingBalance,
    required this.paymentStatus,
    required this.bookingStatus,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
return {
  "apartmentId": apartmentId,
  "apartmentName": apartmentName,
  "apartmentImage": apartmentImage,

  "roomId": roomId,
  "roomName": roomName,

  "userId": userId,
  "hostId": hostId,
      "guestName": guestName,
      "guestEmail": guestEmail,
      "checkIn": Timestamp.fromDate(checkIn),
      "checkOut": Timestamp.fromDate(checkOut),
      "pricingMode": pricingMode,
      "priceMonthly": priceMonthly,
      "monthsStayed": monthsStayed,
      "stayTotal": stayTotal,
      "serviceFee": serviceFee,
      "securityDeposit": securityDeposit,
      "totalDueToday": totalDueToday,
      "totalPrice": totalPrice,
      "amountPaid": amountPaid,
      "remainingBalance": remainingBalance,
      "paymentStatus": paymentStatus,
      "bookingStatus": bookingStatus,
      "createdAt": Timestamp.fromDate(createdAt),
    };
  }
}