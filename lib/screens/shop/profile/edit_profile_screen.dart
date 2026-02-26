import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../services/firebase_service.dart';
import '../../../services/filebase_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _profilePictureUrl;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseService.getCurrentUser();
      if (user == null) {
        setState(() {
          _errorMessage = 'No user is currently logged in';
          _isLoading = false;
        });
        return;
      }

      
      // Get user data from Firebase
      final userData = await FirebaseService.getUserData(user.uid);
      
      if (userData != null) {
        print('DEBUG: User data loaded: $userData');
        print('DEBUG: Profile picture URL: ${userData['profilePicsUrl']}');
        
        // Convert direct URL to presigned URL if needed (for old images)
        String? profileUrl = userData['profilePicsUrl'];
        if (profileUrl != null && profileUrl.isNotEmpty) {
          profileUrl = await FilebaseService().ensurePresignedUrl(profileUrl);
          print('DEBUG: Converted to presigned URL: $profileUrl');
        }
        
        setState(() {
          _firstNameController.text = userData['firstName'] ?? '';
          _lastNameController.text = userData['lastName'] ?? '';
          _emailController.text = userData['email'] ?? user.email ?? '';
          _phoneController.text = userData['phoneNumber'] ?? '';
          _profilePictureUrl = profileUrl ?? '';
          _isLoading = false;
        });
        
        // Pre-cache image if URL exists
        if (_profilePictureUrl != null && _profilePictureUrl!.isNotEmpty) {
          _cacheNetworkImage(_profilePictureUrl!);
        }
      } else {
        // If no data in database, use Firebase Auth data
        setState(() {
          _emailController.text = user.email ?? '';
          _firstNameController.text = user.displayName?.split(' ').first ?? '';
          _lastNameController.text = user.displayName?.split(' ').skip(1).join(' ') ?? '';
          _phoneController.text = '';
          _profilePictureUrl = '';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _errorMessage = 'Error loading profile: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseService.updateUserProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickProfilePicture() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        
        setState(() {
          _selectedImage = imageFile;
        });

        // Show loading dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            },
          );
        }

        try {
          // Delete old profile picture
          await FirebaseService.deleteOldProfilePicture();

          // Upload new profile picture using Filebase
          final url = await FirebaseService.uploadProfilePictureWithFilebase(imageFile);
          
          if (mounted) {
            Navigator.pop(context); // Close loading dialog
            setState(() {
              _profilePictureUrl = url;
            });

            // Pre-cache the uploaded image
            if (url != null && url.isNotEmpty) {
              _cacheNetworkImage(url);
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile picture updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            try {
              Navigator.pop(context); // Close loading dialog if still open
            } catch (_) {}
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error uploading picture: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Pre-cache network image to ensure it loads when needed
  void _cacheNetworkImage(String imageUrl) {
    try {
      if (imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
        precacheImage(NetworkImage(imageUrl), context).then((_) {
          print('DEBUG: Image cached successfully: $imageUrl');
        }).catchError((e) {
          print('DEBUG: Error caching image: $e');
        });
      }
    } catch (e) {
      print('DEBUG: Error in _cacheNetworkImage: $e');
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Profile photo
                      Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                            ),
                            child: ClipOval(
                              child: _selectedImage != null
                                  ? Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    )
                                  : (_profilePictureUrl != null && _profilePictureUrl!.isNotEmpty)
                                      ? Image.network(
                                          _profilePictureUrl!,
                                          fit: BoxFit.cover,
                                          cacheHeight: 500,
                                          cacheWidth: 500,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress.expectedTotalBytes != null
                                                    ? loadingProgress.cumulativeBytesLoaded /
                                                        loadingProgress.expectedTotalBytes!
                                                    : null,
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            print('DEBUG: Image load error for $_profilePictureUrl: $error');
                                            return Icon(Icons.person, size: 50, color: Colors.grey[400]);
                                          },
                                        )
                                      : Icon(Icons.person, size: 50, color: Colors.grey[400]),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickProfilePicture,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFFDB022),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${_firstNameController.text} ${_lastNameController.text}'.trim(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // First Name
                      TextField(
                        controller: _firstNameController,
                        style: TextStyle(color: Colors.grey[700]),
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          labelStyle: TextStyle(color: Colors.grey[700]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Last Name
                      TextField(
                        controller: _lastNameController,
                        style: TextStyle(color: Colors.grey[700]),
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          labelStyle: TextStyle(color: Colors.grey[700]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Email (Read-only)
                      TextField(
                        controller: _emailController,
                        enabled: false,
                        style: TextStyle(color: Colors.grey[700]),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          helperText: 'Email cannot be changed',
                          labelStyle: TextStyle(color: Colors.grey[700]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Phone number
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: Colors.grey[700]),
                        decoration: InputDecoration(
                          labelText: 'Phone Number (Optional)',
                          labelStyle: TextStyle(color: Colors.grey[700]),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('+1'),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                              ],
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFDB022),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[400],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
