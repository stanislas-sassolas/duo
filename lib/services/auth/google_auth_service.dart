import 'package:google_sign_in/google_sign_in.dart';

/// Obtient un jeton d'identité Google (pour lier ou retrouver un compte Duo).
///
/// [serverClientId] est l'identifiant « client Web » OAuth du projet Firebase
/// (créé quand le fournisseur Google est activé dans la console) : Android
/// l'exige pour délivrer un jeton utilisable par Firebase Auth.
class GoogleAuthService {
  GoogleAuthService._();

  static const String serverClientId =
      '214389581006-h2i7bkplf01odas07ggtoo2c1497q8ms.apps.googleusercontent.com';

  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
    _initialized = true;
  }

  /// Ouvre le choix du compte Google et renvoie son jeton d'identité, ou
  /// `null` si l'utilisateur annule.
  static Future<String?> pickAccountIdToken() async {
    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Oublie le compte Google choisi (déconnexion).
  static Future<void> signOut() async {
    if (!_initialized) return;
    await GoogleSignIn.instance.signOut();
  }
}
