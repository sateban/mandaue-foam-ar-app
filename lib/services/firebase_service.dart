import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get Firebase Database instance
  static FirebaseDatabase getDatabase() => _database;

  /// Get Firebase Auth instance
  static FirebaseAuth getAuth() => _auth;

  /// Get current user
  static User? getCurrentUser() => _auth.currentUser;

  // ==================== AUTHENTICATION METHODS ====================

  /// Register user with email and password
  static Future<User?> registerWithEmailPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    try {
      print('DEBUG: Attempting to register user with email: $email');
      
      // Create user account
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;
      
      if (user != null) {
        // Update user profile
        await user.updateDisplayName('$firstName $lastName');
        
        // Save additional user data to Realtime Database
        await writeData('users/${user.uid}', {
          'uid': user.uid,
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'phoneNumber': phoneNumber ?? '',
          'displayName': '$firstName $lastName',
          'createdAt': DateTime.now().toIso8601String(),
          'emailVerified': user.emailVerified,
        });

        print('DEBUG: User registered successfully: ${user.email}');
        return user;
      }
      
      return null;
    } on FirebaseAuthException catch (e) {
      print('DEBUG: FirebaseAuthException during registration - Code: ${e.code}');
      print('DEBUG: Error Message: ${e.message}');
      rethrow;
    } catch (e) {
      print('DEBUG: Unexpected error during registration: $e');
      rethrow;
    }
  }

  /// Sign in user with email and password
  static Future<User?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      print('DEBUG: Attempting to sign in user with email: $email');
      
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;
      
      if (user != null) {
        print('DEBUG: User signed in successfully: ${user.email}');
        
        // Update last login timestamp
        await updateData('users/${user.uid}', {
          'lastLogin': DateTime.now().toIso8601String(),
        });
      }
      
      return user;
    } on FirebaseAuthException catch (e) {
      print('DEBUG: FirebaseAuthException during sign-in - Code: ${e.code}');
      print('DEBUG: Error Message: ${e.message}');
      rethrow;
    } catch (e) {
      print('DEBUG: Unexpected error during sign-in: $e');
      rethrow;
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    try {
      print('DEBUG: Signing out user...');
      await _auth.signOut();
      print('DEBUG: User signed out successfully');
    } catch (e) {
      print('DEBUG: Error signing out: $e');
      rethrow;
    }
  }

  /// Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      print('DEBUG: Sending password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
      print('DEBUG: Password reset email sent successfully');
    } on FirebaseAuthException catch (e) {
      print('DEBUG: FirebaseAuthException during password reset - Code: ${e.code}');
      print('DEBUG: Error Message: ${e.message}');
      rethrow;
    } catch (e) {
      print('DEBUG: Unexpected error sending password reset email: $e');
      rethrow;
    }
  }

  /// Update user password
  static Future<void> updatePassword(String newPassword) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently logged in');
      }

      print('DEBUG: Updating password for user: ${user.email}');
      await user.updatePassword(newPassword);
      print('DEBUG: Password updated successfully');
    } on FirebaseAuthException catch (e) {
      print('DEBUG: FirebaseAuthException during password update - Code: ${e.code}');
      print('DEBUG: Error Message: ${e.message}');
      rethrow;
    } catch (e) {
      print('DEBUG: Unexpected error updating password: $e');
      rethrow;
    }
  }

  /// Update user profile
  static Future<void> updateUserProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently logged in');
      }

      print('DEBUG: Updating profile for user: ${user.email}');

      // Update display name if provided
      if (firstName != null || lastName != null) {
        final displayName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
        await user.updateDisplayName(displayName);
      }

      // Update user data in Realtime Database
      final Map<String, dynamic> updateData = {};
      if (firstName != null) updateData['firstName'] = firstName;
      if (lastName != null) updateData['lastName'] = lastName;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      if (firstName != null || lastName != null) {
        updateData['displayName'] = '${firstName ?? ''} ${lastName ?? ''}'.trim();
      }

      if (updateData.isNotEmpty) {
        await FirebaseService.updateData('users/${user.uid}', updateData);
      }

      print('DEBUG: Profile updated successfully');
    } on FirebaseAuthException catch (e) {
      print('DEBUG: FirebaseAuthException during profile update - Code: ${e.code}');
      print('DEBUG: Error Message: ${e.message}');
      rethrow;
    } catch (e) {
      print('DEBUG: Unexpected error updating profile: $e');
      rethrow;
    }
  }

  /// Check if email exists
  static Future<bool> isEmailRegistered(String email) async {
    try {
      final list = await _auth.fetchSignInMethodsForEmail(email);
      return list.isNotEmpty;
    } catch (e) {
      print('DEBUG: Error checking email: $e');
      return false;
    }
  }

  /// Sign in with Google and create/update user profile
  static Future<User?> signInWithGoogle(GoogleSignInAccount googleUser) async {
    try {
      print('DEBUG: Attempting Firebase authentication with Google');
      
      // Get Google Sign-In authentication
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create credential using ID token and access token
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      
      print('DEBUG: Created Google credential');
      
      // Sign in with Firebase using the credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      
      if (user != null) {
        print('DEBUG: Successfully signed in with Firebase via Google: ${user.email}');
        
        // Check if user data exists in database
        final existingData = await readData('users/${user.uid}');
        
        if (existingData == null) {
          // Create new user profile in database
          await writeData('users/${user.uid}', {
            'uid': user.uid,
            'email': user.email ?? googleUser.email,
            'firstName': googleUser.displayName?.split(' ').first ?? 'User',
            'lastName': googleUser.displayName?.split(' ').skip(1).join(' ') ?? '',
            'displayName': user.displayName ?? googleUser.displayName ?? 'Google User',
            'photoUrl': user.photoURL ?? googleUser.photoUrl,
            'authProvider': 'google',
            'createdAt': DateTime.now().toIso8601String(),
          });
          
          print('DEBUG: Created new Google user profile');
        } else {
          // Update existing user profile with latest info
          await updateData('users/${user.uid}', {
            'lastLogin': DateTime.now().toIso8601String(),
            'displayName': user.displayName ?? googleUser.displayName,
            'photoUrl': user.photoURL ?? googleUser.photoUrl,
          });
          
          print('DEBUG: Updated existing Google user profile');
        }
        
        return user;
      }
      
      return null;
    } on FirebaseAuthException catch (e) {
      print('DEBUG: FirebaseAuthException during Google sign-in - Code: ${e.code}');
      print('DEBUG: Error Message: ${e.message}');
      rethrow;
    } catch (e) {
      print('DEBUG: Unexpected error during Google sign-in: $e');
      rethrow;
    }
  }

  /// Get user data from Realtime Database
  static Future<Map<dynamic, dynamic>?> getUserData(String userId) async {
    try {
      return await readData('users/$userId');
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  /// Stream user data in real-time
  static Stream<Map<dynamic, dynamic>> streamUserData(String userId) {
    return streamData('users/$userId');
  }

  /// Read single data once
  static Future<Map<dynamic, dynamic>?> readData(String path) async {
    try {
      final snapshot = await _database.ref(path).get();
      if (snapshot.exists) {
        return snapshot.value as Map<dynamic, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error reading data: $e');
      return null;
    }
  }

  /// Read list data once
  static Future<List<Map<String, dynamic>>> readListData(String path) async {
    try {
      final snapshot = await _database.ref(path).get();
      List<Map<String, dynamic>> list = [];

      if (snapshot.exists) {
        final data = snapshot.value;

        if (data is Map) {
          // Handle Map data structure (Firebase returns as Map with keys)
          data.forEach((key, value) {
            if (value is Map) {
              list.add({'id': key, ...Map<String, dynamic>.from(value)});
            }
          });
        } else if (data is List) {
          // Handle List data structure
          for (int i = 0; i < data.length; i++) {
            if (data[i] is Map) {
              list.add({
                'id': i.toString(),
                ...Map<String, dynamic>.from(data[i] as Map),
              });
            }
          }
        }
      }
      return list;
    } catch (e) {
      print('Error reading list data: $e');
      return [];
    }
  }

  /// Stream data in real-time
  static Stream<Map<dynamic, dynamic>> streamData(String path) {
    return _database.ref(path).onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as Map<dynamic, dynamic>;
      }
      return {};
    });
  }

  /// Stream list data in real-time
  static Stream<List<Map<String, dynamic>>> streamListData(String path) {
    return _database.ref(path).onValue.map((event) {
      List<Map<String, dynamic>> list = [];
      if (event.snapshot.exists) {
        final data = event.snapshot.value;

        if (data is Map) {
          // Handle Map data structure (Firebase returns as Map with keys)
          data.forEach((key, value) {
            if (value is Map) {
              list.add({'id': key, ...Map<String, dynamic>.from(value)});
            }
          });
        } else if (data is List) {
          // Handle List data structure
          for (int i = 0; i < data.length; i++) {
            if (data[i] is Map) {
              list.add({
                'id': i.toString(),
                ...Map<String, dynamic>.from(data[i] as Map),
              });
            }
          }
        }
      }
      return list;
    });
  }

  /// Write data
  static Future<void> writeData(String path, Map<String, dynamic> data) async {
    try {
      await _database.ref(path).set(data);
    } catch (e) {
      print('Error writing data: $e');
    }
  }

  /// Update data
  static Future<void> updateData(String path, Map<String, dynamic> data) async {
    try {
      await _database.ref(path).update(data);
    } catch (e) {
      print('Error updating data: $e');
    }
  }

  /// Delete data
  static Future<void> deleteData(String path) async {
    try {
      await _database.ref(path).remove();
    } catch (e) {
      print('Error deleting data: $e');
    }
  }

  /// Delete data
  // Address Management
  static Future<void> saveAddress(
    String userId,
    Map<String, dynamic> addressData,
  ) async {
    try {
      final String? addressId = addressData['id'];
      if (addressId == null || addressId.isEmpty) {
        // Create new
        final newRef = _database.ref('users/$userId/addresses').push();
        addressData['id'] = newRef.key;
        await newRef.set(addressData);
      } else {
        // Update existing
        await _database
            .ref('users/$userId/addresses/$addressId')
            .set(addressData);
      }
    } catch (e) {
      print('Error saving address: $e');
      rethrow;
    }
  }

  static Stream<List<Map<String, dynamic>>> getAddresses(String userId) {
    return _database.ref('users/$userId/addresses').onValue.map((event) {
      List<Map<String, dynamic>> list = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value;
        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              list.add(Map<String, dynamic>.from(value));
            }
          });
        }
      }
      return list;
    });
  }

  static Future<void> deleteAddress(String userId, String addressId) async {
    try {
      await _database.ref('users/$userId/addresses/$addressId').remove();
    } catch (e) {
      print('Error deleting address: $e');
      rethrow;
    }
  }

  // Order Management
  static Future<void> createOrder(
    String userId,
    Map<String, dynamic> orderData,
  ) async {
    try {
      final newRef = _database.ref('users/$userId/orders').push();
      orderData['id'] = newRef.key; // Ensure ID matches key
      await newRef.set(orderData);
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  static Stream<List<Map<String, dynamic>>> getOrders(String userId) {
    return _database.ref('users/$userId/orders').onValue.map((event) {
      List<Map<String, dynamic>> list = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value;
        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              list.add(Map<String, dynamic>.from(value));
            }
          });
        }
      }
      // Sort by date, newest first
      list.sort((a, b) {
        DateTime? dateA = DateTime.tryParse(a['orderDate'] ?? '');
        DateTime? dateB = DateTime.tryParse(b['orderDate'] ?? '');
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });
      return list;
    });
  }
}
