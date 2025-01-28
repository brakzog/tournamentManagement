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

  Future<void> connectWithGoogle() async {
    _isLoading = true;
    /*notifyListeners();

    try {
      _user = await _googleSignIn.signIn();
      if (_user != null) {
        _errorMessage = null;
        _isSuccess = true; // Marquer la connexion comme réussie
      } else {
        _isSuccess = false;
        _errorMessage = "Connexion annulée par l'utilisateur.";
      }
    } catch (e) {
      _isSuccess = false;
      _errorMessage = "Erreur lors de la connexion : $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }*/
    try {
     // Utilisez Google Sign-In pour l'authentification
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    // Obtenez l'ID utilisateur Google
    final googleUserId = googleUser?.id;

    // Stockez l'ID utilisateur Google de manière sécurisée
    await const FlutterSecureStorage().write(key: "googleUserId", value: googleUserId);
    
    // Obtenez les informations d'authentification
    final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

    // Connectez-vous à Firebase avec les informations d'authentification Google
    final AuthCredential? credential = GoogleAuthProvider.credential(
          accessToken: googleAuth?.accessToken,
          idToken: googleAuth?.idToken,
        );
    if(credential != null)
      await FirebaseAuth.instance.signInWithCredential(credential);  
      _isSuccess = true; // Marquer la connexion comme réussie    
      notifyListeners();

    } catch (e) {
      _isSuccess = false;
      notifyListeners();
      // Gérez les erreurs d'authentification
      if (kDebugMode) {
        print("Erreur d'authentification Google : $e");
      }
    }
  }


  Future<void> connectWithApple() async {
    _isLoading = true;
    notifyListeners();

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final email = credential.email ?? "Email inconnu";
      print('Utilisateur connecté avec Apple, email : $email');

      _errorMessage = null;
      _isSuccess = true;
    } catch (e) {
      _isSuccess = false;
      _errorMessage = "Erreur lors de la connexion avec Apple : $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}