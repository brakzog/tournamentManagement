import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:tournament_management/pages/home/home.dart';

import 'login_presenter.dart';
import 'login_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart'; // Assurez-vous d'importer easy_localization

class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<LoginViewModel>(context);
    final presenter = LoginPresenter(viewModel);

    // Si la connexion réussit, navigue vers la page Home
    if (viewModel.isSuccess) {
      Future.microtask(() {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      });
    }

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
              style: TextStyle(fontSize: 18),
            ).tr(),
            SizedBox(height: 20),
            viewModel.isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('connect_google').tr(),
                      ],
                    ),
                  ),
            if (viewModel.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  viewModel.errorMessage!,
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: 10),
            if (Platform.isIOS)
              Container(
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
