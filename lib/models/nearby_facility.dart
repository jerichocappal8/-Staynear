import 'package:flutter/material.dart';

class NearbyFacility {
  final String name;
  final String distance;
  final IconData icon;

  const NearbyFacility({
    required this.name,
    required this.distance,
    required this.icon,
  });

  factory NearbyFacility.fromMap(Map<String, dynamic> map) {
    const iconMap = {
      'minimarket': Icons.store,
      'hospital': Icons.local_hospital,
      'canteen': Icons.restaurant,
      'school': Icons.school,
    };

    return NearbyFacility(
      name: map['name'] ?? '',
      distance: map['distance'] ?? '',
      icon: iconMap[map['iconKey']] ?? Icons.place,
    );
  }
}