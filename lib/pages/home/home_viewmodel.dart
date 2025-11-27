import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// --- STATE --- ///
class HomeState {
  final int currentIndex;
  final bool isLoggingOut;
  final String? errorMessage;

  const HomeState({
    this.currentIndex = 0,
    this.isLoggingOut = false,
    this.errorMessage,
  });

  HomeState copyWith({
    int? currentIndex,
    bool? isLoggingOut,
    String? errorMessage,
  }) {
    return HomeState(
      currentIndex: currentIndex ?? this.currentIndex,
      isLoggingOut: isLoggingOut ?? this.isLoggingOut,
      errorMessage: errorMessage,
    );
  }
}

/// --- INTENTS --- ///
abstract class HomeIntent {
  const HomeIntent();
}

class HomeSelectTabIntent extends HomeIntent {
  final int index;
  const HomeSelectTabIntent(this.index);
}

class HomeLogoutIntent extends HomeIntent {
  const HomeLogoutIntent();
}

/// --- VIEWMODEL --- ///
class HomeViewModel extends ChangeNotifier {
  HomeState _state = const HomeState();
  HomeState get state => _state;

  final FirebaseAuth _auth;
  final FlutterSecureStorage _storage;

  HomeViewModel({
    FirebaseAuth? auth,
    FlutterSecureStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? const FlutterSecureStorage();

  void _setState(HomeState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> onIntent(HomeIntent intent) async {
    if (intent is HomeSelectTabIntent) {
      _handleSelectTab(intent.index);
    } else if (intent is HomeLogoutIntent) {
      await _handleLogout();
    }
  }

  void _handleSelectTab(int index) {
    _setState(
      _state.copyWith(
        currentIndex: index,
        errorMessage: null,
      ),
    );
  }

  Future<void> _handleLogout() async {
    _setState(
      _state.copyWith(
        isLoggingOut: true,
        errorMessage: null,
      ),
    );

    try {
      // Nettoyage des infos utilisateur, comme avant
      await _storage.delete(key: 'userId');
      await _storage.delete(key: 'googleUserId'); // bonus : ce qu’on a stocké au login
      await _auth.signOut();

      _setState(
        _state.copyWith(
          isLoggingOut: false,
          errorMessage: null,
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        print('Erreur de logout: $e');
        print(st);
      }
      _setState(
        _state.copyWith(
          isLoggingOut: false,
          errorMessage: 'Erreur lors de la déconnexion : $e',
        ),
      );
    }
  }
}
