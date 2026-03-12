import 'package:flutter/material.dart';

class AppColors {

  /// PRIMARY BRAND COLORS
  static const primaryOrange = Color(0xFFF5A623);
  static const orangeLight   = Color(0xFFFFF3E0);

  /// LIGHT MODE
  static const bgLight   = Color(0xFFF8F7F5);
  static const cardWhite = Colors.white;

  /// TEXT COLORS
  static const textDark  = Color(0xFF1A1A2E);
  static const textMid   = Color(0xFF6B7280);
  static const textLight = Color(0xFF9CA3AF);

  /// BORDERS
  static const border = Color(0xFFEEECE8);

  /// DARK MODE (IMPROVED NAVY PALETTE)
  static const darkBackground = Color(0xFF0B132B); // deep navy background
  static const darkCard       = Color(0xFF1C2541); // card surface
  static const darkCardSoft   = Color(0xFF273469); // elevated cards
  static const darkNavbar     = Color(0xFF0A0F25); // bottom nav / overlays
  static const danger = Color(0xFFFF4D4F);
  /// DYNAMIC TEXT
  static Color text(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : textDark;
  }

  /// DYNAMIC BACKGROUND
  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : bgLight;
  }

  /// DYNAMIC CARD COLOR
  static Color card(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCard
        : cardWhite;
  }

  /// OPTIONAL: Slightly elevated card
  static Color cardSoft(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCardSoft
        : cardWhite;
  }
}