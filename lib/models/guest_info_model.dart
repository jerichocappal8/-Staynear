// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/models/guest_info_model.dart
// ════════════════════════════════════════════════════════════════════════════

class GuestInfoModel {
  final String    firstName;
  final String    lastName;
  final String    email;
  final String    phone;
  final DateTime  checkInDate;
  final DateTime  checkOutDate;
  final int       roomsCount;
  final int       guestsCount;
  final String    specialRequests;
  // The user-selected stay length for monthly bookings. 0 for daily bookings.
  // This is the source of truth — do not recompute from date difference.
  final int       stayMonths;

  const GuestInfoModel({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.checkInDate,
    required this.checkOutDate,
    required this.roomsCount,
    required this.guestsCount,
    this.specialRequests = '',
    this.stayMonths = 0,
  });

  GuestInfoModel copyWith({
    String?   firstName,
    String?   lastName,
    String?   email,
    String?   phone,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    int?      roomsCount,
    int?      guestsCount,
    String?   specialRequests,
    int?      stayMonths,
  }) {
    return GuestInfoModel(
      firstName:       firstName       ?? this.firstName,
      lastName:        lastName        ?? this.lastName,
      email:           email           ?? this.email,
      phone:           phone           ?? this.phone,
      checkInDate:     checkInDate     ?? this.checkInDate,
      checkOutDate:    checkOutDate    ?? this.checkOutDate,
      roomsCount:      roomsCount      ?? this.roomsCount,
      guestsCount:     guestsCount     ?? this.guestsCount,
      specialRequests: specialRequests ?? this.specialRequests,
      stayMonths:      stayMonths      ?? this.stayMonths,
    );
  }

  /// e.g. "08/14/2025"
  static String fmtDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.year}';

  /// e.g. "May 6, 2026"
  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static String fmtDateLong(DateTime d) =>
      '${_monthNames[d.month]} ${d.day}, ${d.year}';
}