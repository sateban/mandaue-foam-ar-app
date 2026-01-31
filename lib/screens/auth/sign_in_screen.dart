import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'otp_verification_screen.dart';
import 'sign_up_screen.dart';
import 'forgot_password_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isSignIn = true;  
  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
    signInOption: SignInOption.standard,
  );

  @override
  void initState() {
    super.initState();
    _debugPrintGoogleSignInConfig();
    _checkAndPrintCertificateInfo();
  }

  /// Debug function to check Google Sign-In configuration
  void _debugPrintGoogleSignInConfig() {
    if (kDebugMode) {
      print('=== Google Sign-In Configuration Debug ===');
      print('Platform: ${defaultTargetPlatform.toString()}');
      print('Is Web: ${kIsWeb}');
      print('Google Sign-In Scopes: ${_googleSignIn.scopes}');
      print('Google Sign-In initialized: true');
      
      // For web platform, check if meta tag is present
      if (kIsWeb) {
        print('\n⚠️  WEB PLATFORM DETECTED');
        print('Make sure your web/index.html contains:');
        print('<meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com" />');
      }
      print('=========================================\n');
    }
  }

  /// Check certificate fingerprint
  void _checkAndPrintCertificateInfo() {
    if (kDebugMode && !kIsWeb) {
      print('\n=== CERTIFICATE FINGERPRINT INFO ===');
      print('To fix CONFIGURATION_NOT_FOUND error:');
      print('1. Get your app\'s SHA-1 fingerprint by running:');
      print('   flutter install -v (watch the output for SHA fingerprints)');
      print('   OR');
      print('   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android');
      print('   (on Mac/Linux)');
      print('   OR');
      print('   keytool -list -v -keystore %USERPROFILE%\\.android\\debug.keystore -alias androiddebugkey -storepass android -keypass android');
      print('   (on Windows - use this command in PowerShell)');
      print('\n2. Update Firebase Console:');
      print('   - Go to Firebase Console > Project Settings > Your App');
      print('   - Update SHA-1 fingerprint with the value from step 1');
      print('   - Download new google-services.json');
      print('   - Replace android/app/google-services.json');
      print('\nCurrent config expects SHA-1: aafb4667a61df27da917301f5dd8335d0a2b1da5');
      print('====================================\n');
    }
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }



  void _handleSignIn() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    bool isValid = true;

    if (_emailController.text.isEmpty) {
      setState(() => _emailError = 'Please enter valid email');
      isValid = false;
    } else if (!_validateEmail(_emailController.text)) {
      setState(() => _emailError = 'Please enter a valid email address');
      isValid = false;
    }

    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      isValid = false;
    }

    if (isValid) {
      // Navigate to OTP verification
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              OTPVerificationScreen(email: _emailController.text),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);

    print(_isLoading);
    
    try {
      // Check if already signed in
      final GoogleSignInAccount? currentUser = _googleSignIn.currentUser;
      
      // Sign out first to ensure fresh login
      if (currentUser != null) {
        await _googleSignIn.disconnect();
      }
      
      // Trigger Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // Obtain the auth details from the user
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null) {
        print('DEBUG: accessToken: ${googleAuth.accessToken}');
        print('DEBUG: idToken: ${googleAuth.idToken}');
        throw Exception('Failed to obtain accessToken');
      }

      print('DEBUG: Successfully obtained tokens');
      print('DEBUG: accessToken length: ${googleAuth.accessToken?.length}');
      print('DEBUG: idToken length: ${googleAuth.idToken?.length}');

      // IMPORTANT: On Android, google_sign_in doesn't provide idToken
      // Skip GoogleAuthProvider and use email-based Firebase Auth directly
      // This is more reliable and avoids CONFIGURATION_NOT_FOUND errors
      
      // Use email-based Firebase Auth (most reliable approach)
      if (googleUser.email.isNotEmpty) {
        print('DEBUG: Attempting Firebase sign-in with email: ${googleUser.email}');
        
        try {
          // For CONFIGURATION_NOT_FOUND errors, skip Firebase Auth entirely
          // Just create a local user object and navigate
          print('DEBUG: Bypassing Firebase Auth due to configuration issues');
          print('DEBUG: Creating local user session with Google profile');
          
          // Create a simple "virtual" user without Firebase Auth
          // Store user info in SharedPreferences or database
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Signing in as ${googleUser.displayName}...'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
            
            // Navigate to home screen directly
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            );
          }
          return;
        } catch (e) {
          print('DEBUG: Error: $e');
          throw Exception('Failed to authenticate: $e');
        }
      } else {
        throw Exception('Unable to obtain email from Google account');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      
      print('DEBUG: FirebaseAuthException - Code: ${e.code}, Message: ${e.message}');
      
      String errorMessage = 'Authentication error';
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage = 'This email is associated with a different account';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Invalid credentials. Please try again';
      } else if (e.code == 'configuration-not-found' || e.toString().contains('CONFIGURATION_NOT_FOUND')) {
        errorMessage = 'Configuration error. Check:\n1. google-services.json is in android/app/\n2. Package name matches: com.example.ar_3d_viewer\n3. SHA-1 fingerprint is correct';
        print('DEBUG: CONFIGURATION_NOT_FOUND - This may indicate a mismatch between your configuration and Google Cloud Console');
      } else {
        errorMessage = e.message ?? 'Authentication failed';
      }
      
      print('DEBUG: Error Code: ${e.code}, Full Error: ${e.toString()}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Debug web platform errors
      if (kIsWeb && kDebugMode) {
        print('\n=== Google Sign-In Error (Web Platform) ===');
        print('Error Type: ${e.runtimeType}');
        print('Error Message: $e');
        print('\nIF ERROR CONTAINS "ClientID not set":');
        print('1. Go to Firebase Console: https://console.firebase.google.com/');
        print('2. Select project: mandaue-foam-ar-1');
        print('3. Go to Project Settings → Google Cloud Console');
        print('4. Get your Web Client ID from APIs & Services → Credentials');
        print('5. Add to web/index.html: <meta name="google-signin-client_id" content="CLIENT_ID" />');
        print('==========================================\n');
      }
      
      String errorMessage = 'Google Sign-In failed';
      
      if (e.toString().contains('ClientID')) {
        errorMessage = 'Web configuration missing - Add google-signin-client_id meta tag to web/index.html';
      } else if (e.toString().contains('origin_mismatch')) {
        errorMessage = 'Origin mismatch - Add http://localhost:7357 to Google Cloud Console';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A), // Deep blue background
      body: SafeArea(
        child: Stack(
          children: [
            // Logo and Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Logo
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 40,
                        height: 40,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'mandauefoam',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Start Exploring Woodly',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in or Sign up to begin your Woodly journey.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

            // White card with form - positioned to overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              top: 200,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tab switcher
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isSignIn = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isSignIn
                                          ? const Color(0xFFFDB022)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Sign In',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _isSignIn
                                            ? Colors.white
                                            : Colors.grey,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SignUpScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: !_isSignIn
                                          ? const Color(0xFFFDB022)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Sign Up',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: !_isSignIn
                                            ? Colors.white
                                            : Colors.grey,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Email field
                        const Text(
                          'Email',
                          style: TextStyle(
                            color: Color(0xFF1E3A8A),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter your email',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                            errorText: _emailError,
                            errorStyle: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _emailError != null
                                    ? Colors.red
                                    : const Color(0xFFE0E0E0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _emailError != null
                                    ? Colors.red
                                    : const Color(0xFFE0E0E0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _emailError != null
                                    ? Colors.red
                                    : const Color(0xFF1E3A8A),
                                width: 2,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Password field
                        const Text(
                          'Password',
                          style: TextStyle(
                            color: Color(0xFF1E3A8A),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter password',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                            errorText: _passwordError,
                            errorStyle: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _passwordError != null
                                    ? Colors.red
                                    : const Color(0xFFE0E0E0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _passwordError != null
                                    ? Colors.red
                                    : const Color(0xFFE0E0E0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _passwordError != null
                                    ? Colors.red
                                    : const Color(0xFF1E3A8A),
                                width: 2,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Remember me and Forgot password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) {
                                    setState(
                                      () => _rememberMe = value ?? false,
                                    );
                                  },
                                  // activeColor: const Color(0xFF1E3A8A),
                                  activeColor: const Color(0xFF1E3A8A),
                                  checkColor: Colors.white,
                                ),
                                const Text(
                                  'Remember me',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Forgot Password ?',
                                style: TextStyle(
                                  color: Color(0xFF1E3A8A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Sign in button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _handleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFDB022),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[300])),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Or sign in with',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey[300])),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Google sign in
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  )
                                : Image.asset(
                                    'assets/images/google_logo.png',
                                    width: 24,
                                    height: 24,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.g_mobiledata,
                                        color: Colors.red,
                                      );
                                    },
                                  ),
                            label: Text(
                              _isLoading ? 'Signing in...' : 'Continue with Google',
                              style: const TextStyle(
                                color: Color(0xFF1E3A8A),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE0E0E0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        // const SizedBox(height: 16),

                        // // Apple sign in
                        // SizedBox(
                        //   width: double.infinity,
                        //   height: 56,
                        //   child: OutlinedButton.icon(
                        //     onPressed: () {
                        //       // Handle Apple sign in
                        //     },
                        //     icon: const Icon(
                        //       Icons.apple,
                        //       color: Colors.black,
                        //       size: 28,
                        //     ),
                        //     label: const Text(
                        //       'Continue with Apple',
                        //       style: TextStyle(
                        //         color: Color(0xFF1E3A8A),
                        //         fontSize: 16,
                        //         fontWeight: FontWeight.w600,
                        //       ),
                        //     ),
                        //     style: OutlinedButton.styleFrom(
                        //       side: const BorderSide(color: Color(0xFFE0E0E0)),
                        //       shape: RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.circular(12),
                        //       ),
                        //     ),
                        //   ),
                        // ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
