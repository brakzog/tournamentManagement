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

   // ===== APPLE =====
  String _generateNonce([int length = 32]) {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }
  String _sha256ofString(String input) => sha256.convert(utf8.encode(input)).toString();

  Future<void> connectWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();

    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final webOptions = null;

      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: hashedNonce,
        webAuthenticationOptions: webOptions,
      );

      // Crée le credential Firebase
      final oauth = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        rawNonce: rawNonce,
        // IMPORTANT pour Android (flux web): passer aussi l'authorizationCode en accessToken
        accessToken: apple.authorizationCode,
      );

      await FirebaseAuth.instance.signInWithCredential(oauth);

      _isSuccess = true; // Root basculera vers Home
    } on SignInWithAppleAuthorizationException catch (e, st) {
      _isSuccess = false;
      _errorMessage = (e.code == AuthorizationErrorCode.canceled)
          ? null
          : "Apple Sign-In a échoué : ${e.message}";
      if (kDebugMode) { print(_errorMessage); print(st); }
    } catch (e, st) {
      _isSuccess = false;
      _errorMessage = "Erreur d'authentification Apple : $e";
      if (kDebugMode) { print(_errorMessage); print(st); }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}