// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/models/guest_info_model.dart
// ════════════════════════════════════════════════════════════════════════════

class GuestInfoModel {
  final String    firstName;
  final String    lastName;
  final String    email;
  final DateTime  checkInDate;
  final DateTime  checkOutDate;
  final int       roomsCount;
  final int       guestsCount;
  final String    specialRequests;

  const GuestInfoModel({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.checkInDate,
    required this.checkOutDate,
    required this.roomsCount,
    required this.guestsCount,
    this.specialRequests = '',
  });

  GuestInfoModel copyWith({
    String?   firstName,
    String?   lastName,
    String?   email,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    int?      roomsCount,
    int?      guestsCount,
    String?   specialRequests,
  }) {
    return GuestInfoModel(
      firstName:       firstName       ?? this.firstName,
      lastName:        lastName        ?? this.lastName,
      email:           email           ?? this.email,
      checkInDate:     checkInDate     ?? this.checkInDate,
      checkOutDate:    checkOutDate    ?? this.checkOutDate,
      roomsCount:      roomsCount      ?? this.roomsCount,
      guestsCount:     guestsCount     ?? this.guestsCount,
      specialRequests: specialRequests ?? this.specialRequests,
    );
  }

  /// e.g. "08/14/2025"
  static String fmtDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.year}';
}