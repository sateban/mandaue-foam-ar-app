import 'package:flutter/material.dart';

class SetFingerprintScreen extends StatelessWidget {
  const SetFingerprintScreen({super.key});

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
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/account-setup-success');
            },
            child: const Text(
              'Skip',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              // Fingerprint icon
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFDB022).withValues(alpha: 0.1),
                ),
                child: const Center(
                  child: Icon(
                    Icons.fingerprint,
                    size: 120,
                    color: Color(0xFFFDB022),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              const Text(
                'Set Your Fingerprint',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add a fingerprint to make your account more secure',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const Spacer(),
              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement fingerprint setup
                    Navigator.pushNamed(context, '/account-setup-success');
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
