import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:the_apple_sign_in/the_apple_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    checkLoggedInState();

    TheAppleSignIn.onCredentialRevoked?.listen((_) {
      if (kDebugMode) {
        print("Credentials revoked");
      }
    });
  }

  void checkLoggedInState() async {
    final userId = await const FlutterSecureStorage().read(key: "userId");
    if (userId == null) {
      if (kDebugMode) {
        print("No stored user ID");
      }
      return;
    }

    final credentialState = await TheAppleSignIn.getCredentialState(userId);
    switch (credentialState.status) {
      case CredentialStatus.authorized:
        if (kDebugMode) {
          print("getCredentialState returned authorized");
        }
        break;

      case CredentialStatus.error:
        if (kDebugMode) {
          print(
              "getCredentialState returned an error: ${credentialState.error?.localizedDescription}");
        }
        break;

      case CredentialStatus.revoked:
        if (kDebugMode) {
          print("getCredentialState returned revoked");
        }
        break;

      case CredentialStatus.notFound:
        if (kDebugMode) {
          print("getCredentialState returned not found");
        }
        break;

      case CredentialStatus.transferred:
        if (kDebugMode) {
          print("getCredentialState returned not transferred");
        }
        break;
    }
  }

  void logInApple() async {
    final AuthorizationResult result = await TheAppleSignIn.performRequests([
      const AppleIdRequest(requestedScopes: [Scope.email, Scope.fullName])
    ]);

    switch (result.status) {
      /*case AuthorizationStatus.authorized:

        // Store user ID
        await const FlutterSecureStorage()
            .write(key: "userId", value: result.credential?.user);

        // Navigate to next page

        break;*/

      case AuthorizationStatus.authorized:
        try {
          final AuthCredential credential =
              OAuthProvider("apple.com").credential(
            idToken: String.fromCharCodes(
                result.credential?.identityToken as Iterable<int>),
            accessToken: String.fromCharCodes(
                result.credential?.authorizationCode as Iterable<int>),
          );

          final authResult =
              await FirebaseAuth.instance.signInWithCredential(credential);

          // Stockez l'ID utilisateur Apple de manière sécurisée
          await const FlutterSecureStorage()
              .write(key: "appleUserId", value: authResult.user?.uid);

          // ignore: use_build_context_synchronously
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) {
                // Retournez la page de destination (par exemple, HomePage)
                return const HomePage();
              },
            ),
          );
        } catch (e) {
          // Gérez les erreurs d'authentification Firebase
          if (kDebugMode) {
            print("Erreur d'authentification Firebase avec Apple : $e");
          }
        }
        break;

      case AuthorizationStatus.error:
        if (kDebugMode) {
          print("Sign in failed: ${result.error?.localizedDescription}");
        }

        break;

      case AuthorizationStatus.cancelled:
        if (kDebugMode) {
          print('User cancelled');
        }
        break;
    }
  }

  void _signInWithGoogle() async {
    try {
      // Utilisez Google Sign-In pour l'authentification
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser != null) {
        // Obtenez l'ID utilisateur Google
        final googleUserId = googleUser.id;

        // Stockez l'ID utilisateur Google de manière sécurisée
        await const FlutterSecureStorage()
            .write(key: "googleUserId", value: googleUserId);

        // Obtenez les informations d'authentification
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Connectez-vous à Firebase avec les informations d'authentification Google
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);

        // Une fois connecté, vous pouvez effectuer des actions supplémentaires si nécessaire
        // Par exemple, rediriger l'utilisateur vers la page principale.
        // ignore: use_build_context_synchronously
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) {
              // Retournez la page de destination (par exemple, HomePage)
              return const HomePage();
            },
          ),
        );
      }
    } catch (e) {
      // Gérez les erreurs d'authentification
      if (kDebugMode) {
        print("Erreur d'authentification Google : $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Se connecter")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _signInWithGoogle,
              child: const Text("Se connecter avec Google"),
            ),
            /*ElevatedButton(
              onPressed: () async {
                // Connexion avec Apple
                final user = await _signInWithApple();
                if (user != null) {
                  // Redirigez l'utilisateur vers la page principale.
                }
              },
              child: const Text("Se connecter avec Apple"),
            ),*/
            AppleSignInButton(
              onPressed: logInApple,
            )
          ],
        ),
      ),
    );
  }
}
