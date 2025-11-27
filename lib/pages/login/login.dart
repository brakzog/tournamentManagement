import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'login_viewmodel.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    // On suppose que LoginViewModel est déjà fourni plus haut
    // via MultiProvider dans main.dart.
    final viewModel = context.watch<LoginViewModel>();
    final state = viewModel.state;

    return Scaffold(
      appBar: AppBar(
        title: Text('login_title'.tr()),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Erreur éventuelle
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Loader
                if (state.isLoading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('loading'.tr()),
                  const SizedBox(height: 24),
                ],

                // Bouton Google
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: state.isLoading
                        ? null
                        : () => viewModel.onIntent(const LoginWithGoogleIntent()),
                    child: Text('connect_google'.tr()),
                  ),
                ),

                const SizedBox(height: 16),

                // Bouton Apple (iOS uniquement)
                if (Platform.isIOS)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: SignInWithAppleButton(
                      onPressed: state.isLoading
                          ? null
                          : () =>
                          viewModel.onIntent(const LoginWithAppleIntent()),
                      style: SignInWithAppleButtonStyle.black,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
