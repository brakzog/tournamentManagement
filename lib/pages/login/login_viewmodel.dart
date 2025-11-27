import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// --- MVI : STATE --- ///
class LoginState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;

  const LoginState({
    this.isLoading = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  LoginState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage,
    );
  }
}

/// --- MVI : INTENTS --- ///
abstract class LoginIntent {
  const LoginIntent();
}

class LoginWithGoogleIntent extends LoginIntent {
  const LoginWithGoogleIntent();
}

class LoginWithAppleIntent extends LoginIntent {
  const LoginWithAppleIntent();
}

/// --- VIEWMODEL / CONTROLLER MVI --- ///
class LoginViewModel extends ChangeNotifier {
  LoginState _state = const LoginState();
  LoginState get state => _state;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  static const _secureStorage = FlutterSecureStorage();

  LoginViewModel({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// Point d’entrée MVI
  Future<void> onIntent(LoginIntent intent) async {
    if (intent is LoginWithGoogleIntent) {
      await _handleGoogleSignIn();
    } else if (intent is LoginWithAppleIntent) {
      await _handleAppleSignIn();
    }
  }

  void _setState(LoginState newState) {
    _state = newState;
    notifyListeners();
  }

  /// --- GOOGLE SIGN-IN (API v7) --- ///
  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;

    // Si tu as un clientId / serverClientId, tu peux les passer ici
    await _googleSignIn.initialize();
    _googleInitialized = true;
  }

  Future<void> _handleGoogleSignIn() async {
    _setState(
      _state.copyWith(
        isLoading: true,
        isSuccess: false,
        errorMessage: null,
      ),
    );

    try {
      await _ensureGoogleInitialized();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw Exception(
          "La méthode authenticate() n'est pas supportée sur cette plateforme.",
        );
      }

      // Nouvelle API : authenticate()
      final GoogleSignInAccount account =
      await _googleSignIn.authenticate(scopeHint: const ['email']);

      // En v7, authentication est synchrone
      final googleAuth = account.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception("Google n'a pas fourni d'idToken.");
      }

      // Credential Firebase
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
       // accessToken: googleAuth.accessToken, <== plus nécessaire aujourd hui
      );

      await _auth.signInWithCredential(credential);

      // On garde ton stockage sécurisé
      await _secureStorage.write(key: "googleUserId", value: account.id);

      _setState(
        _state.copyWith(
          isLoading: false,
          isSuccess: true,
          errorMessage: null,
        ),
      );
    } on GoogleSignInException catch (e, st) {
      // Gestion du "cancel" propre
      if (e.code == GoogleSignInExceptionCode.canceled) {
        _setState(
          _state.copyWith(
            isLoading: false,
            isSuccess: false,
            errorMessage: null,
          ),
        );
      } else {
        final message =
            "Erreur d'authentification Google : ${e.description ?? e.toString()}";
        if (kDebugMode) {
          print(message);
          print(st);
        }
        _setState(
          _state.copyWith(
            isLoading: false,
            isSuccess: false,
            errorMessage: message,
          ),
        );
      }
    } catch (e, st) {
      final message = "Erreur d'authentification Google : $e";
      if (kDebugMode) {
        print(message);
        print(st);
      }
      _setState(
        _state.copyWith(
          isLoading: false,
          isSuccess: false,
          errorMessage: message,
        ),
      );
    }
  }

  /// --- APPLE SIGN-IN (Firebase + nonce) --- ///
  Future<void> _handleAppleSignIn() async {
    _setState(
      _state.copyWith(
        isLoading: true,
        isSuccess: false,
        errorMessage: null,
      ),
    );

    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        // Important pour certaines versions de Firebase : utiliser authorizationCode comme accessToken
        accessToken: appleCredential.authorizationCode,
      );

      await _auth.signInWithCredential(oauthCredential);

      _setState(
        _state.copyWith(
          isLoading: false,
          isSuccess: true,
          errorMessage: null,
        ),
      );
    } on SignInWithAppleException catch (e, st) {
      // Cancel = pas d’erreur UI
      final isCanceled = e.hashCode == AuthorizationErrorCode.canceled;
      final msg = isCanceled
          ? null
          : "Apple Sign-In a échoué : ${e.toString()}";

      if (kDebugMode) {
        print(msg);
        print(st);
      }

      _setState(
        _state.copyWith(
          isLoading: false,
          isSuccess: false,
          errorMessage: msg,
        ),
      );
    } catch (e, st) {
      final message = "Erreur d'authentification Apple : $e";
      if (kDebugMode) {
        print(message);
        print(st);
      }
      _setState(
        _state.copyWith(
          isLoading: false,
          isSuccess: false,
          errorMessage: message,
        ),
      );
    }
  }

  /// --- Helpers Apple nonce --- ///
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
          (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
