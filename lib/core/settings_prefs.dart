// lib/core/settings_prefs.dart

import 'package:shared_preferences/shared_preferences.dart';

class SettingsPrefs {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── generic helpers ──────────────────────────────────────────────────────

  static bool getBool(String key, {bool defaultValue = false}) =>
      _prefs.getBool(key) ?? defaultValue;

  static Future<void> setBool(String key, bool value) =>
      _prefs.setBool(key, value);

  static int getInt(String key, {int defaultValue = 0}) =>
      _prefs.getInt(key) ?? defaultValue;

  static Future<void> setInt(String key, int value) =>
      _prefs.setInt(key, value);

static Future<void> setString(String key, String value) =>
    _prefs.setString(key, value);

static String? getString(String key) {
  return _prefs.getString(key);
}

  // ── notification keys ────────────────────────────────────────────────────

  static const String kPushNewMessages    = 'push_new_messages';
  static const String kPushBookingUpdates = 'push_booking_updates';
  static const String kPushPromotions     = 'push_promotions';
  static const String kPushAppUpdates     = 'push_app_updates';
  static const String kEmailWeekly        = 'email_weekly';
  static const String kEmailAlerts        = 'email_alerts';

  // ── location keys ────────────────────────────────────────────────────────

  static const String kLocationUse        = 'location_use';
  static const String kLocationBackground = 'location_background';
  static const String kLocationRadius     = 'location_radius';

  // ── privacy & security keys ──────────────────────────────────────────────

    static const String kSecurity2FA       = 'security_2fa';
    static const String k2FASecret         = '2fa_secret';
    static const String kSecurityBiometric = 'security_biometric';
    static const String kPrivacyVisibility = 'privacy_visibility';
    static const String kPrivacyActivity   = 'privacy_activity';
    static const String kPrivacyAnalytics  = 'privacy_analytics';

  // ── appearance keys ──────────────────────────────────────────────────────

  static const String kDarkMode           = 'appearance_dark_mode';
  static const String kSystemTheme        = 'appearance_system_theme';
  static const String kTextSize           = 'appearance_text_size';
  static const String kCompactMode        = 'appearance_compact';
  static const String kAnimations         = 'appearance_animations';

  // ── language key ─────────────────────────────────────────────────────────

  static const String kLanguage           = 'language_index';
}
// ── privacy & security keys ──────────────────────────────────────────────
