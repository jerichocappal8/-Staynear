import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> authenticate() async {
    try {
      bool canCheck = await _auth.canCheckBiometrics;
      bool isSupported = await _auth.isDeviceSupported();

      if (!canCheck || !isSupported) {
        return false;
      }

      bool authenticated = await _auth.authenticate(
        localizedReason: 'Authenticate to access your account',
        biometricOnly: true,
      );

      return authenticated;
    } catch (e) {
      return false;
    }
  }
}