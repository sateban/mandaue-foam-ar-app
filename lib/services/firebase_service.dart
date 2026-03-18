import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'filebase_service.dart';

class FirebaseService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static FirebaseDatabase getDatabase() => _database;
  static FirebaseAuth getAuth() => _auth;
  static User? getCurrentUser() => _auth.currentUser;

  static Future<User?> registerWithEmailPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    try {
      print('DEBUG: Attempting to register user with email: $email');
      
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;
      
      if (user != null) {
        await user.updateDisplayName('$firstName $lastName');
        
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

      if (firstName != null || lastName != null) {
        final displayName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
        await user.updateDisplayName(displayName);
      }

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

  static Future<String?> uploadProfilePicture(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently logged in');
      }

      print('DEBUG: Uploading profile picture for user: ${user.uid}');

      final fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref('profiles/${user.uid}/$fileName');

      final uploadTask = ref.putFile(imageFile);
      final taskSnapshot = await uploadTask;

      final downloadUrl = await taskSnapshot.ref.getDownloadURL();
      print('DEBUG: Profile picture uploaded successfully: $downloadUrl');

      await updateData('users/${user.uid}', {
        'profilePicsUrl': downloadUrl,
      });

      return downloadUrl;
    } catch (e) {
      print('DEBUG: Error uploading profile picture: $e');
      rethrow;
    }
  }

  static Future<void> deleteOldProfilePicture() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final listResult = await _storage.ref('profiles/${user.uid}').listAll();
      for (var file in listResult.items) {
        await file.delete();
      }
      print('DEBUG: Old profile pictures deleted');
    } catch (e) {
      print('DEBUG: Error deleting old profile picture: $e');
    }
  }

  static Future<File> compressProfileImage(File imageFile) async {
    try {
      print('DEBUG: Compressing profile image...');
      
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      int width = image.width;
      int height = image.height;
      
      if (width > 500 || height > 500) {
        final maxSize = 500;
        if (width > height) {
          height = (height * maxSize / width).toInt();
          width = maxSize;
        } else {
          width = (width * maxSize / height).toInt();
          height = maxSize;
        }
        print('DEBUG: Resizing image to ${width}x${height}');
      }

      final resized = img.copyResize(
        image,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      );

      final compressed = img.encodeJpg(resized, quality: 85);
      
      final tempDir = Directory.systemTemp;
      final compressedFile = File('${tempDir.path}/profile_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await compressedFile.writeAsBytes(compressed);
      
      final originalSize = (bytes.length / 1024 / 1024).toStringAsFixed(2);
      final compressedSize = (compressed.length / 1024 / 1024).toStringAsFixed(2);
      print('DEBUG: Image compressed from ${originalSize}MB to ${compressedSize}MB');
      
      return compressedFile;
    } catch (e) {
      print('DEBUG: Error compressing image: $e. Using original file.');
      return imageFile;
    }
  }

  static Future<String?> uploadProfilePictureWithFilebase(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently logged in');
      }

      print('DEBUG: Uploading profile picture to Filebase for user: ${user.uid}');

      final compressedFile = await compressProfileImage(imageFile);

      final fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final folderPath = 'profiles/${user.uid}';
      
      final objectPath = await FilebaseService().uploadFile(
        filePath: compressedFile.path,
        fileName: fileName,
        folderPath: folderPath,
        metadata: {
          'x-amz-meta-user-id': user.uid,
          'x-amz-meta-upload-time': DateTime.now().toIso8601String(),
        },
      );

      if (objectPath == null) {
        throw Exception('Filebase upload returned null');
      }

      final presignedUrl = await FilebaseService().buildPresignedImageUrl(objectPath);
      
      if (presignedUrl == null) {
        throw Exception('Failed to generate presigned URL');
      }

      print('DEBUG: Profile picture uploaded successfully to Filebase: $presignedUrl');

      await updateData('users/${user.uid}', {
        'profilePicsUrl': presignedUrl,
        'profilePictureUpdatedAt': DateTime.now().toIso8601String(),
      });

      try {
        await compressedFile.delete();
      } catch (_) {}

      return presignedUrl;
    } catch (e) {
      print('DEBUG: Error uploading profile picture to Filebase: $e');
      rethrow;
    }
  }

  static Future<bool> isEmailRegistered(String email) async {
    try {
      final list = await _auth.fetchSignInMethodsForEmail(email);

      return list.isNotEmpty;
    } catch (e) {
      print('DEBUG: Error checking email: $e');
      return false;
    }
  }

  static Future<User?> signInWithGoogle(GoogleSignInAccount googleUser) async {
    try {
      print('DEBUG: Attempting Firebase authentication with Google');
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      
      print('DEBUG: Created Google credential');
      
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      
      if (user != null) {
        print('DEBUG: Successfully signed in with Firebase via Google: ${user.email}');
        
        final existingData = await readData('users/${user.uid}');
        
        if (existingData == null) {
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

  static Future<Map<dynamic, dynamic>?> getUserData(String userId) async {
    try {
      return await readData('users/$userId');
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  static Stream<Map<dynamic, dynamic>> streamUserData(String userId) {
    return streamData('users/$userId');
  }

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

  static Future<List<Map<String, dynamic>>> readListData(String path) async {
    try {
      final snapshot = await _database.ref(path).get();
      List<Map<String, dynamic>> list = [];

      if (snapshot.exists) {
        final data = snapshot.value;

        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              list.add({'id': key, ...Map<String, dynamic>.from(value)});
            }
          });
        } else if (data is List) {
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

  static Stream<Map<dynamic, dynamic>> streamData(String path) {
    return _database.ref(path).onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as Map<dynamic, dynamic>;
      }
      return {};
    });
  }

  static Stream<List<Map<String, dynamic>>> streamListData(String path) {
    return _database.ref(path).onValue.map((event) {
      List<Map<String, dynamic>> list = [];
      if (event.snapshot.exists) {
        final data = event.snapshot.value;

        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              list.add({'id': key, ...Map<String, dynamic>.from(value)});
            }
          });
        } else if (data is List) {
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

  static Future<void> writeData(String path, Map<String, dynamic> data) async {
    try {
      await _database.ref(path).set(data);
    } catch (e) {
      print('Error writing data: $e');
    }
  }

  static Future<void> updateData(String path, Map<String, dynamic> data) async {
    try {
      await _database.ref(path).update(data);
    } catch (e) {
      print('Error updating data: $e');
    }
  }

  static Future<void> deleteData(String path) async {
    try {
      await _database.ref(path).remove();
    } catch (e) {
      print('Error deleting data: $e');
    }
  }

  static Future<void> saveAddress(
    String userId,
    Map<String, dynamic> addressData,
  ) async {
    try {
      final String? addressId = addressData['id'];
      if (addressId == null || addressId.isEmpty) {
        final newRef = _database.ref('users/$userId/addresses').push();
        addressData['id'] = newRef.key;
        await newRef.set(addressData);
      } else {
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

  static Future<void> createOrder(
    String userId,
    Map<String, dynamic> orderData,
  ) async {
    try {
      final newRef = _database.ref('users/$userId/orders').push();
      orderData['id'] = newRef.key;
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
      list.sort((a, b) {
        DateTime? dateA = DateTime.tryParse(a['orderDate'] ?? '');
        DateTime? dateB = DateTime.tryParse(b['orderDate'] ?? '');
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });
      return list;
    });
  }

  static Future<bool> toggleFavorite(String userId, String productId) async {
    try {
      final favoritePath = 'users/$userId/favorites/$productId';
      final snapshot = await _database.ref(favoritePath).get();
      
      if (snapshot.exists) {
        await _database.ref(favoritePath).remove();
        print('DEBUG: Removed product $productId from favorites');
        return false;
      } else {
        await _database.ref(favoritePath).set({
          'productId': productId,
          'addedAt': DateTime.now().toIso8601String(),
        });
        print('DEBUG: Added product $productId to favorites');
        return true;
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      rethrow;
    }
  }

  static Future<bool> isFavorite(String userId, String productId) async {
    try {
      final snapshot = await _database.ref('users/$userId/favorites/$productId').get();
      return snapshot.exists;
    } catch (e) {
      print('Error checking favorite status: $e');
      return false;
    }
  }

  static Future<List<String>> getFavoriteProductIds(String userId) async {
    try {
      final snapshot = await _database.ref('users/$userId/favorites').get();
      List<String> favorites = [];
      
      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map;
        favorites = data.keys.cast<String>().toList();
      }
      
      return favorites;
    } catch (e) {
      print('Error getting favorite products: $e');
      return [];
    }
  }

  static Stream<List<String>> streamFavoriteProductIds(String userId) {
    return _database.ref('users/$userId/favorites').onValue.map((event) {
      List<String> favorites = [];
      if (event.snapshot.exists && event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        favorites = data.keys.cast<String>().toList();
      }
      return favorites;
    });
  }
}