import 'login_viewmodel.dart';

class LoginPresenter {
  final LoginViewModel viewModel;

  LoginPresenter(this.viewModel);

  void onGoogleSignInTapped() {
    viewModel.connectWithGoogle();
  }

  void onAppleSignInTapped() {
    viewModel.connectWithApple();
  }
}  
