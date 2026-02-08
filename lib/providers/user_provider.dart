import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Provider to manage user authentication state
/// Handles both real Firebase Auth and 'virtual' guest sessions for testing/demo
class UserProvider extends ChangeNotifier {
  User? _firebaseUser;
  String? _guestId;
  String? _guestEmail;
  String? _guestName;

  UserProvider() {
    // Listen to real Firebase Auth changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _firebaseUser = user;
      notifyListeners();
    });
  }

  /// Whether the user is signed in (either via Firebase or Guest session)
  bool get isAuthenticated => _firebaseUser != null || _guestId != null;

  /// Get the unique identifier for the current user
  String get userId {
    if (_firebaseUser != null) return _firebaseUser!.uid;
    if (_guestId != null) return _guestId!;
    return 'guest_user';
  }

  /// Get the email for the current user
  String get userEmail {
    if (_firebaseUser != null) return _firebaseUser!.email ?? '';
    if (_guestEmail != null) return _guestEmail!;
    return 'guest@example.com';
  }

  /// Get the display name for the current user
  String get userName {
    if (_firebaseUser != null) return _firebaseUser!.displayName ?? 'User';
    if (_guestName != null) return _guestName!;
    return 'Guest User';
  }

  /// Manually set a guest user session (useful for bypassing auth config issues)
  void setGuestUser({required String id, required String email, String? name}) {
    _guestId = id;
    _guestEmail = email;
    _guestName = name;
    print('UserProvider: Guest session started for $email (ID: $id)');
    notifyListeners();
  }

  /// Sign out from all sessions
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    _guestId = null;
    _guestEmail = null;
    _guestName = null;
    print('UserProvider: Signed out successfully');
    notifyListeners();
  }
}
