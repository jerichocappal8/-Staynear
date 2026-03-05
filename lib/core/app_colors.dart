import 'package:flutter/material.dart';

class AppColors {

  static const primaryOrange = Color(0xFFF5A623);
  static const orangeLight   = Color(0xFFFFF3E0);

  static const border        = Color(0xFFEEECE8);

  // ADD THESE BACK
  static const textDark = Color(0xFF1A1A2E);
  static const cardWhite = Colors.white;
  static const bgLight = Color(0xFFF8F7F5);

  static const textMid = Color(0xFF6B7280);
  static const textLight = Color(0xFF9CA3AF);

  static Color text(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : textDark;
  }

  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0F0F10)
        : bgLight;
  }

  static Color card(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A1A1C)
        : cardWhite;
  }
}