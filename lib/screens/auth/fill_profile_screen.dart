import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/firebase_service.dart';
import '../../services/filebase_service.dart';

class FillProfileScreen extends StatefulWidget {
  const FillProfileScreen({super.key});

  @override
  State<FillProfileScreen> createState() => _FillProfileScreenState();
}

class _FillProfileScreenState extends State<FillProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedGender;
  File? _selectedImage;
  String? _uploadedImageUrl;
  String _selectedCountryCode = '+63'; // Default to Philippines
  
  // Country codes map with country names
  final Map<String, String> _countryCodes = {
    '+1': 'USA/Canada',
    '+63': 'Philippines',
    '+44': 'United Kingdom',
    '+91': 'India',
    '+86': 'China',
    '+81': 'Japan',
    '+33': 'France',
    '+49': 'Germany',
    '+39': 'Italy',
    '+34': 'Spain',
    '+61': 'Australia',
    '+64': 'New Zealand',
    '+27': 'South Africa',
    '+55': 'Brazil',
    '+52': 'Mexico',
    '+1-809': 'Dominican Republic',
    '+65': 'Singapore',
    '+60': 'Malaysia',
    '+66': 'Thailand',
    '+84': 'Vietnam',
    '+62': 'Indonesia',
    '+92': 'Pakistan',
    '+88': 'Bangladesh',
    '+234': 'Nigeria',
    '+254': 'Kenya',
    '+358': 'Finland',
    '+46': 'Sweden',
    '+47': 'Norway',
    '+45': 'Denmark',
    '+31': 'Netherlands',
    '+32': 'Belgium',
    '+41': 'Switzerland',
    '+43': 'Austria',
    '+48': 'Poland',
    '+420': 'Czech Republic',
    '+36': 'Hungary',
    '+380': 'Ukraine',
    '+7': 'Russia',
    '+90': 'Turkey',
    '+966': 'Saudi Arabia',
    '+971': 'UAE',
    '+965': 'Kuwait',
    '+974': 'Qatar',
    '+212': 'Morocco',
    '+216': 'Tunisia',
    '+213': 'Algeria',
    '+20': 'Egypt',
  };

  @override
  void dispose() {
    _fullNameController.dispose();
    _nicknameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 6570),
      ), // 18 years ago
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = '${picked.day}/${picked.month}/${picked.year}';
      });
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
          // Upload profile picture using Filebase
          final url = await FirebaseService.uploadProfilePictureWithFilebase(imageFile);
          
          if (mounted) {
            Navigator.pop(context); // Close loading dialog
            setState(() {
              _uploadedImageUrl = url;
            });

            // Pre-cache the uploaded image
            if (url != null && url.isNotEmpty) {
              _cacheNetworkImage(url);
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile picture uploaded successfully'),
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
        // Cache in Flutter's image cache for faster rendering
        precacheImage(NetworkImage(imageUrl), context).then((_) {
          print('DEBUG: Image cached in Flutter: $imageUrl');
        }).catchError((e) {
          print('DEBUG: Error caching in Flutter: $e');
        });
        
        // Also cache in FilebaseService for byte-level caching (prevents re-download)
        FilebaseService().getImageBytes(imageUrl).then((bytes) {
          if (bytes != null) {
            print('✨ Image bytes cached (${bytes.length} bytes): ${imageUrl.split('/').last}');
          }
        }).catchError((e) {
          print('DEBUG: Error caching image bytes: $e');
        });
      }
    } catch (e) {
      print('DEBUG: Error in _cacheNetworkImage: $e');
    }
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
          'Fill Your Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Profile photo
                Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
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
                            : (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty)
                                ? Image.network(
                                    _uploadedImageUrl!,
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
                                      print('DEBUG: Image load error for $_uploadedImageUrl: $error');
                                      return Icon(Icons.person, size: 60, color: Colors.grey[400]);
                                    },
                                  )
                                : Icon(Icons.person, size: 60, color: Colors.grey[400]),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1E3A8A),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.edit,
                            size: 20,
                            color: Colors.white,
                          ),
                          onPressed: _pickProfilePicture,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Full Name
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Nickname
                TextFormField(
                  controller: _nicknameController,
                  decoration: InputDecoration(
                    labelText: 'Nickname',
                    hintText: 'Enter your nickname',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Date of Birth
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: _selectDate,
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    hintText: 'Select your date of birth',
                    suffixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    suffixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Phone Number with country code dropdown
                Row(
                  children: [
                    // Country code dropdown
                    Expanded(
                      flex: 2,
                      child: DropdownButton<String>(
                        value: _selectedCountryCode,
                        isExpanded: true,
                        items: _countryCodes.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(
                              '${entry.key} ${entry.value}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCountryCode = newValue;
                            });
                          }
                        },
                        underline: Container(
                          height: 1,
                          color: Colors.grey[300],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Phone number input
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: 'Enter your phone number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Gender
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: ['Male', 'Female', 'Other'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedGender = newValue;
                    });
                  },
                ),
                const SizedBox(height: 32),
                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/create-pin');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDB022),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
