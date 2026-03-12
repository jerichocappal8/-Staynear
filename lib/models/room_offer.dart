// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/models/room_offer.dart
//
//  Represents one rentable room type inside a property.
//  Stored as a DOCUMENT in the rooms subcollection:
//    properties/{propertyId}/rooms/{roomId}
//
//  CHANGE LOG:
//  • Added securityDeposit  — per-room deposit (replaces property-level deposit)
//  • serviceFee             — already existed, kept as-is
//  • pricingMode            — 'monthly' | 'daily'
//  • priceMonthly           — price when pricingMode == 'monthly'
//  • priceDaily             — price when pricingMode == 'daily'
// ════════════════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';

class RoomOffer {
  final String? id;

  String roomType;

  /// Pricing mode: 'monthly' | 'daily'
  String pricingMode;

  /// Monthly price (editing as String to support text field binding)
  String priceMonthly;

  /// Daily price (editing as String to support text field binding)
  String priceDaily;

  /// Optional service fee charged on top of base rent
  String serviceFee;

  /// Per-room security deposit — replaces the old property-level deposit.
  /// Each room type can have a different deposit requirement.
  /// Example: Bed Space → ₱500 | 1 Bedroom → ₱3,000 | Entire Unit → ₱8,000
  String securityDeposit;

  String availableUnits;
  String maxOccupants;

  /// 'open' | 'female' | 'male'
  String genderRestriction;

  bool isAvailable;

  RoomOffer({
    this.id,
    this.roomType           = '',
    this.pricingMode        = 'monthly',
    this.priceMonthly       = '',
    this.priceDaily         = '',
    this.serviceFee         = '',
    this.securityDeposit    = '',
    this.availableUnits     = '',
    this.maxOccupants       = '',
    this.genderRestriction  = 'open',
    this.isAvailable        = true,
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  Firestore → Model
  // ─────────────────────────────────────────────────────────────────────────
factory RoomOffer.fromFirestore(String id, Map<String, dynamic> data) {
  String _toStr(dynamic v) => v?.toString() ?? '';

  return RoomOffer(
    id: id,

    roomType: data['roomType'] ?? '',

    availableUnits: _toStr(data['availableUnits']),
    maxOccupants: _toStr(data['maxOccupants']),

    genderRestriction: data['genderRestriction'] ?? 'open',

    pricingMode: data['pricingMode'] ?? 'monthly',

    priceMonthly: _toStr(data['priceMonthly']),
    priceDaily: _toStr(data['priceDaily']),

    serviceFee: _toStr(data['serviceFee']),
    securityDeposit: _toStr(data['securityDeposit']),

    isAvailable: data['isAvailable'] ?? true,
  );
}

  // ─────────────────────────────────────────────────────────────────────────
  //  Model → Firestore
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> toFirestoreMap() {
    return {
      'roomType'          : roomType.trim(),

      // Pricing
      'pricingMode'       : pricingMode,
      'priceMonthly'      : double.tryParse(priceMonthly.trim())     ?? 0.0,
      'priceDaily'        : double.tryParse(priceDaily.trim())       ?? 0.0,

      // Fees & deposit (all per-room, not property-level)
      'serviceFee'        : double.tryParse(serviceFee.trim())       ?? 0.0,
      'securityDeposit'   : double.tryParse(securityDeposit.trim())  ?? 0.0,

      // Room data
      'availableUnits'    : int.tryParse(availableUnits.trim())      ?? 0,
      'maxOccupants'      : int.tryParse(maxOccupants.trim())        ?? 0,
      'genderRestriction' : genderRestriction,
      'isAvailable'       : isAvailable,

      'updatedAt'         : Timestamp.now(),
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Validation
  //  Monthly mode → priceMonthly > 0
  //  Daily mode   → priceDaily   > 0
  // ─────────────────────────────────────────────────────────────────────────
  bool get isValid {
    final monthly   = double.tryParse(priceMonthly.trim()) ?? 0;
    final daily     = double.tryParse(priceDaily.trim())   ?? 0;
    final units     = int.tryParse(availableUnits.trim())  ?? 0;
    final occupants = int.tryParse(maxOccupants.trim())    ?? 0;

    final priceValid =
        pricingMode == 'monthly' ? monthly > 0 : daily > 0;

    return roomType.isNotEmpty && priceValid && units > 0 && occupants > 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Fully booked helper
  // ─────────────────────────────────────────────────────────────────────────
  bool get isFullyBooked {
    final units = int.tryParse(availableUnits.trim()) ?? 0;
    return units <= 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Active price — whichever pricing mode is selected
  // ─────────────────────────────────────────────────────────────────────────
  double get activePrice => pricingMode == 'monthly'
      ? (double.tryParse(priceMonthly.trim()) ?? 0)
      : (double.tryParse(priceDaily.trim())   ?? 0);

  // ─────────────────────────────────────────────────────────────────────────
  //  Total price = activePrice + serviceFee
  //  (used everywhere a "displayed price" is needed)
  // ─────────────────────────────────────────────────────────────────────────
  double get totalPrice {
    final fee = double.tryParse(serviceFee.trim()) ?? 0;
    return activePrice + fee;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Total due today (checkout — first payment only)
  //
  //  totalDueToday = activePrice + securityDeposit + serviceFee
  //
  //  This is what the tenant pays on day 1:
  //    • First month/day rent
  //    • Security deposit (refundable at end of tenancy)
  //    • Service fee (platform/management charge)
  //
  //  This intentionally does NOT multiply by duration — that's the
  //  full-stay total, not the initial payment.
  // ─────────────────────────────────────────────────────────────────────────
  double get totalDueToday {
    final fee     = double.tryParse(serviceFee.trim())      ?? 0;
    final deposit = double.tryParse(securityDeposit.trim()) ?? 0;
    return activePrice + deposit + fee;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Clone
  // ─────────────────────────────────────────────────────────────────────────
  RoomOffer copyWith({
    String? roomType,
    String? pricingMode,
    String? priceMonthly,
    String? priceDaily,
    String? serviceFee,
    String? securityDeposit,
    String? availableUnits,
    String? maxOccupants,
    String? genderRestriction,
    bool?   isAvailable,
  }) {
    return RoomOffer(
      id:                id,
      roomType:          roomType          ?? this.roomType,
      pricingMode:       pricingMode       ?? this.pricingMode,
      priceMonthly:      priceMonthly      ?? this.priceMonthly,
      priceDaily:        priceDaily        ?? this.priceDaily,
      serviceFee:        serviceFee        ?? this.serviceFee,
      securityDeposit:   securityDeposit   ?? this.securityDeposit,
      availableUnits:    availableUnits    ?? this.availableUnits,
      maxOccupants:      maxOccupants      ?? this.maxOccupants,
      genderRestriction: genderRestriction ?? this.genderRestriction,
      isAvailable:       isAvailable       ?? this.isAvailable,
    );
  }
}