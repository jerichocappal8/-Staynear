import 'package:cloud_firestore/cloud_firestore.dart';

/// ─────────────────────────────────────────────────────────────
/// RoomOffer Model
/// Represents one rentable room type inside a property.
/// Stored as a DOCUMENT in:
/// properties/{propertyId}/rooms/{roomId}
/// ─────────────────────────────────────────────────────────────
class RoomOffer {
  final String? id; // Firestore document ID (nullable when creating)
  String roomType;
  String priceMonthly;     // Stored as String while editing
  String availableUnits;   // Stored as String while editing
  String maxOccupants;     // Stored as String while editing
  String genderRestriction; // 'open' | 'female' | 'male'
  bool isAvailable;

  RoomOffer({
    this.id,
    this.roomType = '',
    this.priceMonthly = '',
    this.availableUnits = '',
    this.maxOccupants = '',
    this.genderRestriction = 'open',
    this.isAvailable = true,
  });

  /// ─────────────────────────────────────────────────────────────
  /// Convert to Firestore map (for saving)
  /// ─────────────────────────────────────────────────────────────
  Map<String, dynamic> toFirestoreMap() {
    return {
      'roomType': roomType.trim(),
      'priceMonthly': double.tryParse(priceMonthly.trim()) ?? 0.0,
      'availableUnits': int.tryParse(availableUnits.trim()) ?? 0,
      'maxOccupants': int.tryParse(maxOccupants.trim()) ?? 0,
      'genderRestriction': genderRestriction,
      'isAvailable': isAvailable,
      'createdAt': Timestamp.now(),
    };
  }

  /// ─────────────────────────────────────────────────────────────
  /// Create RoomOffer from Firestore document
  /// (Used when reading from database)
  /// ─────────────────────────────────────────────────────────────
  factory RoomOffer.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return RoomOffer(
      id: id,
      roomType: data['roomType'] ?? '',
      priceMonthly: (data['priceMonthly'] ?? 0).toString(),
      availableUnits: (data['availableUnits'] ?? 0).toString(),
      maxOccupants: (data['maxOccupants'] ?? 0).toString(),
      genderRestriction: data['genderRestriction'] ?? 'open',
      isAvailable: data['isAvailable'] ?? true,
    );
  }

  /// ─────────────────────────────────────────────────────────────
  /// Validation (used before publishing property)
  /// ─────────────────────────────────────────────────────────────
  bool get isValid {
    final price = double.tryParse(priceMonthly.trim()) ?? 0;
    final units = int.tryParse(availableUnits.trim()) ?? 0;
    final occupants = int.tryParse(maxOccupants.trim()) ?? 0;

    return roomType.isNotEmpty &&
        price > 0 &&
        units > 0 &&
        occupants > 0;
  }

  /// ─────────────────────────────────────────────────────────────
  /// Helper: Check if fully booked
  /// (For future booking logic)
  /// ─────────────────────────────────────────────────────────────
  bool get isFullyBooked {
    final units = int.tryParse(availableUnits.trim()) ?? 0;
    return units <= 0;
  }

  /// ─────────────────────────────────────────────────────────────
  /// Clone method (useful for editing)
  /// ─────────────────────────────────────────────────────────────
  RoomOffer copyWith({
    String? roomType,
    String? priceMonthly,
    String? availableUnits,
    String? maxOccupants,
    String? genderRestriction,
    bool? isAvailable,
  }) {
    return RoomOffer(
      id: id,
      roomType: roomType ?? this.roomType,
      priceMonthly: priceMonthly ?? this.priceMonthly,
      availableUnits: availableUnits ?? this.availableUnits,
      maxOccupants: maxOccupants ?? this.maxOccupants,
      genderRestriction: genderRestriction ?? this.genderRestriction,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}