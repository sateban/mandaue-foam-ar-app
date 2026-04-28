import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider extends ChangeNotifier {
  User? _firebaseUser;
  String? _guestId;
  String? _guestEmail;
  String? _guestName;

  UserProvider() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _firebaseUser = user;
      notifyListeners();
    });
  }

  bool get isAuthenticated => _firebaseUser != null || _guestId != null;

  String get userId {
    if (_firebaseUser != null) return _firebaseUser!.uid;
    if (_guestId != null) return _guestId!;
    return 'guest_user';
  }

  String get userEmail {
    if (_firebaseUser != null) return _firebaseUser!.email ?? '';
    if (_guestEmail != null) return _guestEmail!;
    return 'guest@example.com';
  }

  String get userName {
    if (_firebaseUser != null) return _firebaseUser!.displayName ?? 'User';
    if (_guestName != null) return _guestName!;
    return 'Guest User';
  }

  void setGuestUser({required String id, required String email, String? name}) {
    _guestId = id;
    _guestEmail = email;
    _guestName = name;
    print('UserProvider: Guest session started for $email (ID: $id)');
    notifyListeners();
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    _guestId = null;
    _guestEmail = null;
    _guestName = null;
    print('UserProvider: Signed out successfully');
    notifyListeners();
  }
}
