import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginViewModel extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  GoogleSignInAccount? _user;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSuccess => _isSuccess;
  GoogleSignInAccount? get user => _user;

  // ===== GOOGLE =====
  Future<void> connectWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _isSuccess = false; // user cancelled
        return;
      }
      _user = googleUser;

      await const FlutterSecureStorage()
          .write(key: "googleUserId", value: googleUser.id);

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      _isSuccess = true; // Root basculera automatiquement
    } catch (e, st) {
      _isSuccess = false;
      _errorMessage = "Erreur d'authentification Google : $e";
      if (kDebugMode) {
        print(_errorMessage);
        print(st);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===== APPLE → FIREBASE =====

  // Nonce utilitaire
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> connectWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();

    try {
      // 1) Apple Sign-In avec nonce
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleIdCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // 2) Crée le credential Firebase (Apple = oauth 'apple.com')
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleIdCredential.identityToken,
        rawNonce: rawNonce,
        // accessToken n'est pas requis pour Apple natif
      );

      // 3) Connecte-toi à Firebase
      await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      _isSuccess = true; // Root passera à Home
    } on SignInWithAppleAuthorizationException catch (e, st) {
      // Erreurs natives Apple (userCancelled, etc.)
      _isSuccess = false;
      if (e.code == AuthorizationErrorCode.canceled) {
        _errorMessage = null; // annulation = pas d'erreur visible
      } else {
        _errorMessage = "Apple Sign-In a échoué : ${e.message}";
      }
      if (kDebugMode) {
        print(_errorMessage);
        print(st);
      }
    } catch (e, st) {
      _isSuccess = false;
      _errorMessage = "Erreur d'authentification Apple : $e";
      if (kDebugMode) {
        print(_errorMessage);
        print(st);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}