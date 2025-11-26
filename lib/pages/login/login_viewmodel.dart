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

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize();
    _googleInitialized = true;
  }
  Future<void> connectWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();

    try {
      // 1) S'assurer que GoogleSignIn est initialisé (nouvelle API)
      await _ensureGoogleSignInInitialized();

      // 2) Lancer le flux d'authentification explicite
      //    (équivalent du bouton "SIGN IN" de l'exemple)
      final GoogleSignInAccount account = await _googleSignIn.authenticate(
        scopeHint: const ['email'], // optionnel mais courant
      );

      _user = account;

      await const FlutterSecureStorage()
          .write(key: "googleUserId", value: account.id);

      // 4) Récupérer les tokens (API v7)
      //    `authentication` est maintenant synchro, pas besoin de `await`.
      final googleAuth = account.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception("Google n'a pas fourni de idToken.");
      }

      // 5) Créer le credential Firebase et se logger
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        // accessToken : optionnel avec les versions récentes, Firebase a surtout besoin du idToken.
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      _isSuccess = true; // ton Root pourra basculer comme avant
    } on GoogleSignInException catch (e, st) {
      // En v7, l’annulation renvoie une exception avec code "canceled"
      final codeString = e.code.toString(); // type interne, on passe par toString
      final isCanceled = codeString.contains('canceled');

      if (isCanceled) {
        _isSuccess = false;
        _errorMessage = null;
        if (kDebugMode) {
          print("Google sign-in canceled: $e");
          print(st);
        }
      } else {
        _isSuccess = false;
        _errorMessage = "Erreur d'authentification Google : ${e.code} - ${e.description}";
        if (kDebugMode) {
          print(_errorMessage);
          print(st);
        }
      }
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