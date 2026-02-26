import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({this.showBottomNav = true, super.key});

  final bool showBottomNav;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseService.getCurrentUser();
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Profile photo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: Icon(Icons.person, size: 50, color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<dynamic, dynamic>?>(
              future: currentUser != null ? FirebaseService.getUserData(currentUser.uid) : Future.value(null),
              builder: (context, snapshot) {
                String displayName = 'User';
                
                if (snapshot.hasData && snapshot.data != null) {
                  final userData = snapshot.data!;
                  final firstName = userData['firstName'] ?? '';
                  final lastName = userData['lastName'] ?? '';
                  displayName = '$firstName $lastName'.trim();
                } else if (currentUser?.displayName != null) {
                  displayName = currentUser!.displayName!;
                }
                
                return Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // Menu items
            _buildMenuItem(
              context,
              icon: Icons.edit_outlined,
              title: 'Edit Profile',
              onTap: () => Navigator.pushNamed(context, '/edit-profile'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.local_offer_outlined,
              title: 'Coupons',
              onTap: () => Navigator.pushNamed(context, '/coupons'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.location_on_outlined,
              title: 'Shipping Address',
              onTap: () => Navigator.pushNamed(context, '/shipping-address'),
            ),
            // _buildMenuItem(
            //   context,
            //   icon: Icons.shopping_bag_outlined,
            //   title: 'My Orders',
            //   onTap: () => Navigator.pushNamed(context, '/orders'),
            // ),
            _buildMenuItem(
              context,
              icon: Icons.favorite_outline,
              title: 'Wishlist',
              onTap: () => Navigator.pushNamed(context, '/wishlist'),
            ),
            // _buildMenuItem(
            //   context,
            //   icon: Icons.credit_card_outlined,
            //   title: 'My Cards',
            //   onTap: () => Navigator.pushNamed(context, '/my-cards'),
            // ),
            // _buildMenuItem(
            //   context,
            //   icon: Icons.more_horiz,
            //   title: 'More',
            //   onTap: () => Navigator.pushNamed(context, '/more-settings'),
            // ),
            _buildMenuItem(
              context,
              icon: Icons.logout,
              title: 'Log Out',
              onTap: () {
                _showLogoutDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFDB022).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFFFDB022)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                
                try {
                  print('DEBUG: Attempting to sign out...');
                  
                  // Show loading dialog using the outer context
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext loadingContext) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                    );
                  }
                  
                  // Sign out from Firebase
                  await FirebaseService.signOut();
                  
                  print('DEBUG: Sign out successful');
                  
                  if (context.mounted) {
                    // Close loading dialog
                    Navigator.pop(context);
                    
                    // Navigate to sign in screen using the outer context
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/sign-in',
                      (route) => false,
                    );
                    
                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Successfully logged out'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  print('DEBUG: Error during sign out: $e');
                  
                  if (context.mounted) {
                    // Close loading dialog if still open
                    try {
                      Navigator.pop(context);
                    } catch (_) {
                      // Dialog might not be open
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error logging out: $e'),
                        duration: const Duration(seconds: 3),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Log Out', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
