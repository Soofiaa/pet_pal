import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Verifica si el dispositivo soporta autenticación biométrica
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  /// Verifica si hay biometría configurada en el dispositivo
  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  /// Lista de biometrías disponibles
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Autentica al usuario usando biometría
  /// 
  /// [localizedReason] es el mensaje que se muestra al usuario
  /// Returns true si la autenticación fue exitosa, false en caso contrario
  static Future<bool> authenticate({
    required String localizedReason,
    bool useErrorDialogs = true,
    bool stickyAuth = false,
    bool biometricOnly = false,
  }) async {
    try {
      final bool canCheck = await canCheckBiometrics();
      final bool supported = await isDeviceSupported();
      final available = await getAvailableBiometrics();
      debugPrint('BiometricService: canCheck=$canCheck supported=$supported available=$available');
      final bool canAuthenticate = canCheck && supported;
      if (!canAuthenticate) {
        return false;
      }

      final bool authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: biometricOnly,
        ),
      );
      debugPrint('BiometricService: authenticated=$authenticated');
      return authenticated;
    } on PlatformException catch (e) {
      // El usuario canceló o hubo un error
      debugPrint('BiometricService: PlatformException code=${e.code} message=${e.message}');
      return false;
    } catch (e) {
      debugPrint('BiometricService: error $e');
      return false;
    }
  }

  /// Cancela cualquier autenticación en progreso
  static Future<void> cancelAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (e) {
      // Ignorar errores al cancelar
    }
  }
}
