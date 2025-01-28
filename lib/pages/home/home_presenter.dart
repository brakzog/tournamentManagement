import 'home_viewmodel.dart';

class HomePresenter {
  final HomeViewModel viewModel;

  HomePresenter(this.viewModel);

  void onTabSelected(int index) {
    viewModel.updateTabIndex(index);
  }

  Future<void> onLogoutTapped() async {
    await viewModel.logoutUser();
  }
}
