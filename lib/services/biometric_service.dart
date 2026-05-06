import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> authenticate() async {
    try {
      bool canCheck = await _auth.canCheckBiometrics;
      bool isSupported = await _auth.isDeviceSupported();

      debugPrint('[BiometricService] canCheckBiometrics=$canCheck isDeviceSupported=$isSupported');

      if (!canCheck || !isSupported) {
        debugPrint('[BiometricService] Biometric unavailable on this device — skipping.');
        return false;
      }

      bool authenticated = await _auth.authenticate(
        localizedReason: 'Authenticate to access your account',
        biometricOnly: true,
      );

      debugPrint('[BiometricService] authenticate() returned $authenticated');
      return authenticated;
    } catch (e) {
      debugPrint('[BiometricService] Exception during authenticate(): $e');
      return false;
    }
  }
}