import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeViewModel extends ChangeNotifier {
  int _currentIndex = 0; // Onglet sélectionné.
  int get currentIndex => _currentIndex;

  void updateTabIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  
  Future<void> logout() async {
	final storage = const FlutterSecureStorage();
	await storage.delete(key: 'userId');
	await FirebaseAuth.instance.signOut();
  }
}
