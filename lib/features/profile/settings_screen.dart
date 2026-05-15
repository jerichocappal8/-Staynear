// lib/features/settings/settings_screen.dart
//
// Dependencies (pubspec.yaml):
//   shared_preferences: ^2.3.2
//
// Required one-time setup in main.dart:
//
//   void main() async {
//     WidgetsFlutterBinding.ensureInitialized();
//     await SettingsPrefs.init();
//     settingsController.loadFromPrefs();
//     runApp(const MyApp());
//   }
//
// To wire ThemeMode into MaterialApp:
//
//   return ListenableBuilder(
//     listenable: settingsController,
//     builder: (_, __) => MaterialApp(
//       themeMode: settingsController.themeMode,
//       theme: ThemeData.light(),
//       darkTheme: ThemeData.dark(),
//       home: const SettingsScreen(),
//     ),
//   );
import 'package:flutter/material.dart';
import 'package:otp/otp.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Adjust these import paths to match your project structure.
import '../../core/app_colors.dart';
import 'package:staynear/core/auth_helper.dart';
import '../../core/settings_prefs.dart';
import '../../core/settings_controller.dart';
import '../security/setup_2fa_screen.dart';
import '../auth/auth_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:local_auth/local_auth.dart';
import '../../services/biometric_service.dart';
import '../security/change_password_page.dart';
import '../security/backup_codes_page.dart';
// ════════════════════════════════════════════════════════════════════════════
//  SETTINGS SCREEN
// ════════════════════════════════════════════════════════════════════════════

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        children: [

          // ── Preferences ──────────────────────────────────────────────────
          const _SectionLabel(text: 'PREFERENCES'),
          _SettingsCard(items: [
            _SettingsTile(
              icon: Icons.location_on_outlined,
              iconColor: const Color(0xFF10B981),
              title: 'Location Preferences',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const LocationPreferencesPage())),
            ),
          ]),

          const SizedBox(height: 24),

          // ── Privacy & Security ───────────────────────────────────────────
          const _SectionLabel(text: 'PRIVACY & SECURITY'),
          _SettingsCard(items: [
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              iconColor: const Color(0xFFEF4444),
              title: 'Privacy & Security',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const PrivacySecurityPage())),
            ),
            _SettingsTile(
              icon: Icons.policy_outlined,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Privacy Policy',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
            ),
            _SettingsTile(
              icon: Icons.description_outlined,
              iconColor: const Color(0xFFF59E0B),
              title: 'Terms & Conditions',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const TermsConditionsPage())),
              isLast: true,
            ),
          ]),

          const SizedBox(height: 24),

          // ── Display ──────────────────────────────────────────────────────
          const _SectionLabel(text: 'DISPLAY'),
          _SettingsCard(items: [
            _SettingsTile(
              icon: Icons.palette_outlined,
              iconColor: const Color(0xFF6366F1),
              title: 'Appearance',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AppearancePage())),
              isLast: true,
            ),
          ]),

          const SizedBox(height: 24),

          // ── Storage & Info ───────────────────────────────────────────────
          const _SectionLabel(text: 'STORAGE & INFO'),
          _SettingsCard(items: [
            _SettingsTile(
              icon: Icons.delete_sweep_outlined,
              iconColor: const Color(0xFFEC4899),
              title: 'Clear Cache',
              onTap: () => _showClearCacheDialog(context),
            ),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              iconColor: AppColors.textMid,
              title: 'About App',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AboutAppPage())),
              isLast: true,
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Clear Cache',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will clear all cached data. Your account and saved information will not be affected.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textMid,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textMid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await _clearCache();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            child: Text(
              'Clear',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

Future<void> _clearCache() async {
  final tempDir = await getTemporaryDirectory();

  if (await tempDir.exists()) {
    final files = tempDir.listSync();

    for (var file in files) {
      try {
        if (file is File) {
          await file.delete();
        } else if (file is Directory) {
          await file.delete(recursive: true);
        }
      } catch (_) {}
    }
  }
}
  }

// ════════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textLight,
            letterSpacing: 1.0,
          ),
        ),
      );
}

// Accepts either [items] or [children] so both call-sites compile.
class _SettingsCard extends StatelessWidget {
  final List<Widget>? items;
  final List<Widget>? children;

  const _SettingsCard({this.items, this.children})
      : assert(items != null || children != null,
            '_SettingsCard requires items or children');

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: items ?? children!),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;
  final bool isLast;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(16),
            bottom: isLast ? const Radius.circular(16) : Radius.zero,
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text(context),
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.textLight),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
  height: 1,
  indent: 64,
  endIndent: 0,
  color: AppColors.border,
),
      ],
    );
  }
}

// ── Shared inner-page scaffold ────────────────────────────────────────────

class _InnerPage extends StatelessWidget {
  final String title;
  final Widget body;
  const _InnerPage({required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        body: body,
      );
}

// ── Persistent switch tile ────────────────────────────────────────────────
//
// Reads its initial value from SharedPreferences in initState and
// persists every change immediately.  Each tile requires a unique [prefKey].

class _PersistentSwitchTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String prefKey;
  final bool defaultValue;
  final bool isLast;

  const _PersistentSwitchTile({
    required this.title,
    required this.prefKey,
    this.subtitle,
    this.defaultValue = false,
    this.isLast = false,
  });

  @override
  State<_PersistentSwitchTile> createState() => _PersistentSwitchTileState();
}

class _PersistentSwitchTileState extends State<_PersistentSwitchTile> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = SettingsPrefs.getBool(widget.prefKey,
        defaultValue: widget.defaultValue);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text(context)),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMid),
                      ),
                    ],
                  ],
                ),
              ),
              Switch.adaptive(
                value: _value,
                activeColor: AppColors.primaryOrange,
                onChanged: (v) {
                  setState(() => _value = v);
                  SettingsPrefs.setBool(widget.prefKey, v);
                },
              ),
            ],
          ),
        ),
        if (!widget.isLast)
          Divider(
  height: 1,
  color: AppColors.border,
),
      ],
    );
  }
}
class _Enable2FATile extends StatefulWidget {
  const _Enable2FATile();

  @override
  State<_Enable2FATile> createState() => _Enable2FATileState();
}

class _Enable2FATileState extends State<_Enable2FATile> {

  bool? enabled;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {

    final uid = AuthHelper.uid;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    enabled = doc.data()?['twoFAEnabled'] ?? false;

    setState(() {});
  }

  Future<void> _disable2FA() async {

    final uid = AuthHelper.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
      "twoFAEnabled": false,
      "twoFASecret": FieldValue.delete(),
      "twoFABackupCodes": FieldValue.delete(),
    });

    setState(() {
      enabled = false;
    });
  }
Future<void> _confirmDisable2FA() async {

  final controller = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        "Verify to Disable 2FA",
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Text(
            "Enter your authenticator code or backup code to disable 2FA.",
          ),

          const SizedBox(height: 16),

          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Authentication Code",
              border: OutlineInputBorder(),
            ),
          ),

        ],
      ),
      actions: [

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel"),
        ),

        TextButton(
          onPressed: () {
            Navigator.pop(context, controller.text.trim());
          },
          child: Text(
            "Verify",
            style: TextStyle(color: Colors.red),
          ),
        ),

      ],
    ),
  );

  if (result == null || result.isEmpty) return;

  bool valid = await _verifyCode(result);

  if (valid) {
    await _disable2FA();
  } else {

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Invalid code"),
        backgroundColor: Colors.red,
      ),
    );
  }
}
Future<bool> _verifyCode(String code) async {

  final uid = AuthHelper.uid;

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();

  final secret = doc.data()?['twoFASecret'];
  final backupCodes = List<String>.from(doc.data()?['twoFABackupCodes'] ?? []);

  if (backupCodes.contains(code)) {

    backupCodes.remove(code);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
      "twoFABackupCodes": backupCodes
    });

    return true;
  }

  if (secret == null) return false;

return verifyTOTP(secret, code);
}

bool verifyTOTP(String secret, String code) {

  final now = DateTime.now().millisecondsSinceEpoch;

  final current = OTP.generateTOTPCodeString(
    secret,
    now,
    interval: 30,
    algorithm: Algorithm.SHA1,
    isGoogle: true,
  );

  final previous = OTP.generateTOTPCodeString(
    secret,
    now - 30000,
    interval: 30,
    algorithm: Algorithm.SHA1,
    isGoogle: true,
  );

  final next = OTP.generateTOTPCodeString(
    secret,
    now + 30000,
    interval: 30,
    algorithm: Algorithm.SHA1,
    isGoogle: true,
  );

  return code == current || code == previous || code == next;
}
  @override
  Widget build(BuildContext context) {

    if (enabled == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: [

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

          child: Row(
            children: [

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      'Two-Factor Authentication',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text(context),
                      ),
                    ),

                    SizedBox(height: 2),

                    Text(
                      'Add an extra layer of security',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMid,
                      ),
                    ),
                  ],
                ),
              ),

              /// ENABLE BUTTON
              if (enabled == false)
                TextButton(
                  onPressed: () {

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Setup2FAScreen(),
                      ),
                    );

                  },

                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryOrange,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: AppColors.primaryOrange.withOpacity(0.6),
                      ),
                    ),
                  ),

                  child: Text(
                    'Enable 2FA',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )

              /// DISABLE SWITCH
              else
                Switch.adaptive(
                  value: true,
                  activeColor: AppColors.primaryOrange,
                  onChanged: (value) {
  if (value == false) {
    _confirmDisable2FA();
  }
},
                ),
            ],
          ),
        ),

        Divider(
  height: 1,
  color: AppColors.border,
)

      ],
    );
  }
}
// ── Dark-mode switch tile (ChangeNotifier-aware) ──────────────────────────
//
// Uses [ListenableBuilder] so it rebuilds whenever [settingsController]
// notifies (e.g. from another screen). Delegates persistence to the
// controller so the single source of truth stays in [SettingsController].

class _DarkModeSwitchTile extends StatelessWidget {
  const _DarkModeSwitchTile();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsController,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dark Mode',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.text(context)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Switch to a darker color scheme',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMid),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: settingsController.darkMode,
                    activeColor: AppColors.primaryOrange,
                    onChanged: settingsController.toggleDarkMode,
                  ),
                ],
              ),
            ),
            Divider(
  height: 1,
  color: AppColors.border,
),
          ],
        );
      },
    );
  }
}

// ── Persistent radio group ────────────────────────────────────────────────

class _PersistentRadioGroup extends StatefulWidget {
  final List<String> options;
  final String prefKey;
  final int defaultIndex;

  const _PersistentRadioGroup({
    required this.options,
    required this.prefKey,
    this.defaultIndex = 0,
  });

  @override
  State<_PersistentRadioGroup> createState() => _PersistentRadioGroupState();
}

class _PersistentRadioGroupState extends State<_PersistentRadioGroup> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = SettingsPrefs.getInt(widget.prefKey,
        defaultValue: widget.defaultIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(widget.options.length, (i) {
          final isLast = i == widget.options.length - 1;
          return Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() => _selected = i);
                  SettingsPrefs.setInt(widget.prefKey, i);
                },
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: isLast ? const Radius.circular(16) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.options[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selected == i
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: _selected == i
                                ? AppColors.primaryOrange
                                : AppColors.textDark,
                          ),
                        ),
                      ),
                      if (_selected == i)
                        const Icon(Icons.check_rounded,
                            size: 18, color: AppColors.primaryOrange),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Divider(
  height: 1,
  color: AppColors.border,
),
            ],
          );
        }),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  NOTIFICATIONS PAGE
// ════════════════════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════════════════════
//  LOCATION PREFERENCES PAGE
// ════════════════════════════════════════════════════════════════════════════

class LocationPreferencesPage extends StatelessWidget {
  const LocationPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _InnerPage(
      title: 'Location Preferences',
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        children: [
          const _SectionLabel(text: 'LOCATION ACCESS'),
          _SettingsCard(children: [
            const _PersistentSwitchTile(
              title: 'Use My Location',
              subtitle: 'Allow the app to access your location',
              prefKey: SettingsPrefs.kLocationUse,
              defaultValue: true,
            ),
            const _PersistentSwitchTile(
              title: 'Background Location',
              subtitle: 'Access location even when app is closed',
              prefKey: SettingsPrefs.kLocationBackground,
              isLast: true,
            ),
          ]),
          const SizedBox(height: 24),
          const _SectionLabel(text: 'SEARCH RADIUS'),
          _PersistentRadioGroup(
            prefKey: SettingsPrefs.kLocationRadius,
            defaultIndex: 1,
            options: const [
              'Within 1 km',
              'Within 5 km',
              'Within 10 km',
              'Within 25 km',
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: Color(0xFFF59E0B)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your location data is only used to show relevant listings and is never shared with third parties.',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF92400E), height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PRIVACY & SECURITY PAGE
// ════════════════════════════════════════════════════════════════════════════

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}
class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const _InnerPage(title: 'Privacy & Security', body: Center(

  child: Text(

    'Please log in to continue.',

    style: TextStyle(fontSize: 16),

  ),

));
    return _InnerPage(
      title: 'Privacy & Security',
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        children: [
          const _SectionLabel(text: 'SECURITY'),
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots(),
  builder: (context, snapshot) {

    bool twoFAEnabled = false;

    if (snapshot.hasData && snapshot.data!.data() != null) {
      twoFAEnabled =
          (snapshot.data!.data() as Map<String, dynamic>)['twoFAEnabled'] ?? false;
    }

    return _SettingsCard(children: [

      const _Enable2FATile(),

      const _PersistentSwitchTile(
        title: 'Biometric Login',
        subtitle: 'Use fingerprint or face ID to sign in',
        prefKey: SettingsPrefs.kSecurityBiometric,
        defaultValue: false,
      ),

      _SettingsTile(
        icon: Icons.password,
        iconColor: const Color(0xFF6366F1),
        title: 'Change Password',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ChangePasswordPage(),
            ),
          );
        },
      ),

      _SettingsTile(
        icon: Icons.lock_reset_rounded,
        iconColor: const Color(0xFF10B981),
        title: 'Forgot Password',
        onTap: () => _sendPasswordReset(context),
      ),

      /// SHOW ONLY IF 2FA ENABLED
      if (twoFAEnabled)
        _SettingsTile(
          icon: Icons.key,
          iconColor: const Color(0xFFF59E0B),
          title: 'View Backup Codes',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BackupCodesPage(),
              ),
            );
          },
          isLast: true,
        ),

    ]);
  },
),
          const SizedBox(height: 24),
          const _SectionLabel(text: 'ACCOUNT'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: InkWell(
              onTap: () => _showDeleteDialog(context),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: Color(0xFFEF4444)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Delete Account',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppColors.textLight),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

Future<void> _sendPasswordReset(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.email == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No email address found for this account.'),
          backgroundColor: Colors.red),
    );
    return;
  }

  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Password reset link sent to ${user.email}'),
        backgroundColor: AppColors.primaryOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to send reset email: $e'),
          backgroundColor: Colors.red),
    );
  }
}

void _showDeleteDialog(BuildContext context) {
  if (_isDeleting) return;
  final providers = (FirebaseAuth.instance.currentUser?.providerData ?? [])
      .map((p) => p.providerId)
      .toList();
  if (providers.contains('password')) {
    _showPasswordDeleteDialog(context);
  } else if (providers.contains('google.com')) {
    _showGoogleDeleteDialog(context);
  } else {
    _showPasswordDeleteDialog(context);
  }
}

void _showPasswordDeleteDialog(BuildContext context) {
  final passwordController = TextEditingController();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Delete Account',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'This action is permanent and cannot be undone. All your data will be removed.',
            style: TextStyle(fontSize: 14, color: AppColors.textMid, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Enter your password to confirm',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textMid, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: _isDeleting
              ? null
              : () {
                  final password = passwordController.text.trim();
                  if (password.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter your password.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext);
                  _performDeleteWithPassword(context, password);
                },
          child: Text(
            'Delete',
            style: TextStyle(
              color: _isDeleting ? AppColors.textLight : const Color(0xFFEF4444),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

void _showGoogleDeleteDialog(BuildContext context) {
  final confirmController = TextEditingController();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Delete Account',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'This action is permanent and cannot be undone. All your data will be removed.',
            style: TextStyle(fontSize: 14, color: AppColors.textMid, height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You will be asked to sign in with Google to verify your identity.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: confirmController,
            decoration: const InputDecoration(
              labelText: 'Type CONFIRM to proceed',
              hintText: 'CONFIRM',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textMid, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: _isDeleting
              ? null
              : () {
                  if (confirmController.text.trim() != 'CONFIRM') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please type CONFIRM exactly to proceed.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext);
                  _performDeleteWithGoogle(context);
                },
          child: Text(
            'Delete',
            style: TextStyle(
              color: _isDeleting ? AppColors.textLight : const Color(0xFFEF4444),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> _performDeleteWithPassword(BuildContext context, String password) async {
  if (_isDeleting) return;
  if (mounted) setState(() => _isDeleting = true);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(color: AppColors.primaryOrange),
    ),
  );

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) Navigator.of(context).pop();
      return;
    }

    final uid = user.uid;

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);

    // Delete Firestore doc BEFORE auth deletion —
    // Firestore rules require request.auth.uid, which is gone after delete().
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();

    if (!context.mounted) return;
    final navigator = Navigator.of(context);

    await user.delete();
    debugPrint('[DeleteAccount] Firebase Auth user deleted successfully.');

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen(isLogin: true)),
      (route) => false,
    );
  } on FirebaseAuthException catch (e) {
    debugPrint('[DeleteAccount] FirebaseAuthException: code=${e.code} message=${e.message}');
    if (!context.mounted) return;
    Navigator.of(context).pop();

    final String message;
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        message = 'Incorrect password. Your account was not deleted.';
        break;
      case 'requires-recent-login':
        message = 'For security, please log out and log back in before deleting your account.';
        break;
      case 'network-request-failed':
        message = 'Network error. Please check your connection and try again.';
        break;
      default:
        message = 'Delete failed: ${e.message ?? e.code}';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  } catch (e) {
    debugPrint('[DeleteAccount] Error: $e');
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
    );
  } finally {
    if (mounted) setState(() => _isDeleting = false);
  }
}

Future<void> _performDeleteWithGoogle(BuildContext context) async {
  if (_isDeleting) return;
  if (mounted) setState(() => _isDeleting = true);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(color: AppColors.primaryOrange),
    ),
  );

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) Navigator.of(context).pop();
      return;
    }

    final uid = user.uid;

    final googleSignIn = GoogleSignIn(
      serverClientId:
          '578999573932-9pm11s6boh55s4pnmo1ckpcestm2ki8a.apps.googleusercontent.com',
    );
    await googleSignIn.signOut();

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign-in cancelled. Account was not deleted.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (mounted) setState(() => _isDeleting = false);
      return;
    }

    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google sign-in failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (mounted) setState(() => _isDeleting = false);
      return;
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await user.reauthenticateWithCredential(credential);

    // Delete Firestore doc BEFORE auth deletion —
    // Firestore rules require request.auth.uid, which is gone after delete().
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();

    if (!context.mounted) return;
    final navigator = Navigator.of(context);

    await user.delete();
    debugPrint('[DeleteAccount] Firebase Auth user deleted successfully.');

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen(isLogin: true)),
      (route) => false,
    );
  } on FirebaseAuthException catch (e) {
    debugPrint('[DeleteAccount] FirebaseAuthException: code=${e.code} message=${e.message}');
    if (!context.mounted) return;
    Navigator.of(context).pop();

    final String message;
    switch (e.code) {
      case 'requires-recent-login':
        message = 'For security, please log out and log back in before deleting your account.';
        break;
      case 'user-mismatch':
        message = 'The Google account does not match your signed-in account.';
        break;
      case 'invalid-credential':
        message = 'Google sign-in failed. Please try again.';
        break;
      case 'network-request-failed':
        message = 'Network error. Please check your connection and try again.';
        break;
      default:
        message = 'Delete failed: ${e.message ?? e.code}';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  } catch (e) {
    debugPrint('[DeleteAccount] Error: $e');
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
    );
  } finally {
    if (mounted) setState(() => _isDeleting = false);
  }
}
}
// ════════════════════════════════════════════════════════════════════════════
//  APPEARANCE PAGE
// ════════════════════════════════════════════════════════════════════════════

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _InnerPage(
      title: 'Appearance',
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        children: [
          const _SectionLabel(text: 'THEME'),
          _SettingsCard(children: [
            // Dark mode is controller-driven so the whole app reacts.
            const _DarkModeSwitchTile(),
            const _PersistentSwitchTile(
              title: 'Use System Theme',
              subtitle: "Follow your device's display settings",
              prefKey: SettingsPrefs.kSystemTheme,
              defaultValue: true,
              isLast: true,
            ),
          ]),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  LANGUAGE PAGE
// ════════════════════════════════════════════════════════════════════════════


// ════════════════════════════════════════════════════════════════════════════
//  ABOUT APP PAGE
// ════════════════════════════════════════════════════════════════════════════

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _InnerPage(
      title: 'About App',
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryOrange.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.home_rounded,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  'Staynear',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text(context),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0 (Build 100)',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textMid),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const _SectionLabel(text: 'APP INFO'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                _InfoRow(label: 'Version', value: '1.0.0'),
                _InfoRow(label: 'Build Number', value: '100'),
                _InfoRow(label: 'Released', value: 'March 2026'),
                _InfoRow(label: 'Platform', value: 'Flutter'),
                _InfoRow(
                    label: 'Developer',
                    value: 'Staynear Team',
                    isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel(text: 'CONTACT'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                _InfoRow(label: 'Email', value: 'support@staynear.ph'),
                _InfoRow(
                    label: 'Website',
                    value: 'www.staynear.ph',
                    isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Center(
            child: Text(
              '© 2026 Staynear. All rights reserved.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                  letterSpacing: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _InfoRow(
      {required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textMid)),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text(context))),
            ],
          ),
        ),
        if (!isLast) Divider(
  height: 1,
  color: AppColors.border,
),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TERMS & CONDITIONS PAGE
// ════════════════════════════════════════════════════════════════════════════

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _InnerPage(
      title: 'Terms & Conditions',
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DocHeader(
              icon: Icons.description_outlined,
              iconColor: Color(0xFFF59E0B),
              title: 'Terms & Conditions',
              subtitle: 'Last updated: March 1, 2026',
            ),
            const SizedBox(height: 24),
            _DocSection(
              title: '1. Acceptance of Terms',
              body: 'By accessing or using Staynear, you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use the application.',
            ),
            _DocSection(
              title: '2. Use of the Service',
              body: 'Staynear provides a platform connecting renters and property owners. You agree to use the service only for lawful purposes and in accordance with these terms.',
            ),
            _DocSection(
              title: '3. User Accounts',
              body: 'You must provide accurate and complete information when creating an account. You are solely responsible for all activity that occurs under your account.',
            ),
            _DocSection(
              title: '4. Listings and Bookings',
              body: "Property owners are responsible for the accuracy of their listings. Staynear does not guarantee the availability, condition, or legality of any listed property. All bookings are subject to the property owner's acceptance.",
            ),
            _DocSection(
              title: '5. Payments',
              body: 'All payment transactions are processed securely. Staynear is not liable for errors in payment processing caused by third-party payment providers.',
            ),
            _DocSection(
              title: '6. Prohibited Activities',
              body: 'You may not use Staynear to post false or misleading listings, engage in fraudulent activity, harass other users, or violate any applicable laws or regulations.',
            ),
            _DocSection(
              title: '7. Termination',
              body: 'We reserve the right to suspend or terminate your account at our discretion if you violate these Terms.',
            ),
            _DocSection(
              title: '8. Changes to Terms',
              body: 'Staynear reserves the right to update these Terms at any time. Continued use of the app after changes constitutes acceptance of the new terms.',
            ),
            _DocSection(
              title: '9. Contact',
              body: 'For questions regarding these Terms, contact us at legal@staynear.ph.',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PRIVACY POLICY PAGE
// ════════════════════════════════════════════════════════════════════════════

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _InnerPage(
      title: 'Privacy Policy',
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DocHeader(
              icon: Icons.policy_outlined,
              iconColor: Color(0xFF8B5CF6),
              title: 'Privacy Policy',
              subtitle: 'Last updated: March 1, 2026',
            ),
            const SizedBox(height: 24),
            _DocSection(
              title: '1. Information We Collect',
              body: 'We collect information you provide directly, such as your name, email address, phone number, and address. We also collect usage data, device information, and location data.',
            ),
            _DocSection(
              title: '2. How We Use Your Information',
              body: 'Your information is used to provide and improve our services, process transactions, send notifications, verify your identity, and respond to your requests. We do not sell your personal data.',
            ),
            _DocSection(
              title: '3. Data Sharing',
              body: 'We may share your information with property owners you interact with, service providers who assist our operations, and authorities when required by law.',
            ),
            _DocSection(
              title: '4. Location Data',
              body: 'Location data is used only to show relevant listings near you. You may revoke location access at any time through your device settings.',
            ),
            _DocSection(
              title: '5. Data Security',
              body: 'We implement industry-standard security measures including encryption, secure servers, and regular security audits.',
            ),
            _DocSection(
              title: '6. Your Rights',
              body: 'You have the right to access, correct, or delete your personal data. You may also request a copy of your data by contacting our privacy team.',
            ),
            _DocSection(
              title: '7. Cookies & Tracking',
              body: 'We use analytics tools to understand how users interact with our app. This data is anonymized and aggregated.',
            ),
            _DocSection(
              title: "8. Children's Privacy",
              body: 'Staynear is not intended for users under 18 years of age. We do not knowingly collect personal information from minors.',
            ),
            _DocSection(
              title: '9. Contact Us',
              body: 'For privacy-related concerns, contact our Data Protection Officer at privacy@staynear.ph.',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Document widgets ──────────────────────────────────────────────────────

class _DocHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _DocHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(context))),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMid)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocSection extends StatelessWidget {
  final String title;
  final String body;
  final bool isLast;

  const _DocSection({
    required this.title,
    required this.body,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context))),
            const SizedBox(height: 8),
            Text(body,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textMid, height: 1.65)),
          ],
        ),
      ),
    );
  }
}
