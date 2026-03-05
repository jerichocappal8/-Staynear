// lib/core/settings_controller.dart

import 'package:flutter/material.dart';
import 'settings_prefs.dart';

/// A [ChangeNotifier] that holds runtime-observable settings.
///
/// Currently manages [darkMode]. Extend with additional reactive
/// settings as needed.
///
/// Usage:
///   1. Create one instance near the root of your widget tree.
///   2. Wrap your MaterialApp (or relevant subtree) in a
///      [ChangeNotifierProvider] / [ListenableBuilder] / [AnimatedBuilder].
///   3. Pass the instance down, or use a DI solution such as
///      Provider / Riverpod / GetIt.
///
/// Minimal wiring example (no extra package needed):
///
///   final settingsController = SettingsController();
///
///   void main() async {
///     WidgetsFlutterBinding.ensureInitialized();
///     await SettingsPrefs.init();
///     settingsController.loadFromPrefs();
///     runApp(const MyApp());
///   }
///
///   // Inside MyApp.build:
///   return ListenableBuilder(
///     listenable: settingsController,
///     builder: (_, __) => MaterialApp(
///       themeMode: settingsController.themeMode,
///       ...
///     ),
///   );

class SettingsController extends ChangeNotifier {
  bool _darkMode;

  SettingsController({bool darkMode = false}) : _darkMode = darkMode;

  bool get darkMode => _darkMode;

  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  /// Call once after [SettingsPrefs.init()] to restore saved value.
  void loadFromPrefs() {
    _darkMode = SettingsPrefs.getBool(SettingsPrefs.kDarkMode);
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool value) async {
    _darkMode = value;
    await SettingsPrefs.setBool(SettingsPrefs.kDarkMode, value);
    notifyListeners();
  }
}

/// Global singleton — avoids a dependency on any DI package.
/// Replace with Provider / Riverpod / GetIt in a production app.
final SettingsController settingsController = SettingsController();