import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  String? _emailError;
  bool _isLoading = false;

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _handlePasswordReset() async {
    setState(() {
      _emailError = null;
    });

    bool isValid = true;

    if (_emailController.text.isEmpty) {
      setState(() => _emailError = 'Email is required');
      isValid = false;
    } else if (!_validateEmail(_emailController.text)) {
      setState(() => _emailError = 'Please enter a valid email address');
      isValid = false;
    }

    if (!isValid) {
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      print('DEBUG: Sending password reset email to: ${_emailController.text}');

      await FirebaseService.sendPasswordResetEmail(_emailController.text);

      if (!mounted) return;

      print('DEBUG: Password reset email sent successfully');

      setState(() => _isLoading = false);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password reset link sent to ${_emailController.text}. Please check your email.',
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      print(
        'DEBUG: FirebaseAuthException - Code: ${e.code}, Message: ${e.message}',
      );

      String errorMessage = 'Password reset failed';

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email address.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is invalid.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many requests. Please try again later.';
          break;
        default:
          errorMessage =
              e.message ?? 'Password reset failed. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.red,
        ),
      );

      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;

      print('DEBUG: Unexpected error during password reset: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'An unexpected error occurred. Please try again.',
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.red,
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: SafeArea(
        child: Column(
          children: [
            // Back button
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),

            // Header
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
                              color: const Color(0xFFFDB022),
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
                    'Forgot Your Password?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Provide your email so we can help you reset your password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

            // White card
            Expanded(
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
                        const SizedBox(height: 24),

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
                          style: const TextStyle(color: Colors.black),
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

                        const SizedBox(height: 40),

                        // Next button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handlePasswordReset,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFDB022),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 0,
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Send Reset Link',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 200),
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
