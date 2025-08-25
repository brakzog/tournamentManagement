import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:tournament_management/pages/home/home.dart';

import 'login_presenter.dart';
import 'login_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart'; // Assurez-vous d'importer easy_localization

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();
    final presenter = LoginPresenter(viewModel);

    // ❌ IMPORTANT : plus AUCUNE navigation ici.
    // On ne pousse pas Home sur succès : Root écoute authStateChanges() et fait la bascule.

    return Scaffold(
      appBar: AppBar(title: Text('login_title').tr()),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'connect_google',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ).tr(),
            const SizedBox(height: 20),

            // Bouton Google
            if (viewModel.isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 4,
                ),
                onPressed: presenter.onGoogleSignInTapped,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('connect_google').tr(),
                  ],
                ),
              ),

            // Erreur éventuelle
            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                viewModel.errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 10),

            // Bouton Apple (iOS uniquement)
            if (Platform.isIOS)
              SizedBox(
                height: 50,
                child: SignInWithAppleButton(
                  onPressed: presenter.onAppleSignInTapped,
                  style: SignInWithAppleButtonStyle.black,
                ),
              ),
          ],
        ),
      ),
    );
  }
}