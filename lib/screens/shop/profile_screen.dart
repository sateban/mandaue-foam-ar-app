import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({this.showBottomNav = true, super.key});

  final bool showBottomNav;

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
            const Text(
              'John Doe',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
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
              onTap: () => Navigator.pushNamed(context, '/shipping-addresses'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.shopping_bag_outlined,
              title: 'My Orders',
              onTap: () => Navigator.pushNamed(context, '/orders'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.favorite_outline,
              title: 'Wishlist',
              onTap: () => Navigator.pushNamed(context, '/wishlist'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.credit_card_outlined,
              title: 'My Cards',
              onTap: () => Navigator.pushNamed(context, '/my-cards'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.more_horiz,
              title: 'More',
              onTap: () => Navigator.pushNamed(context, '/more-settings'),
            ),
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
                color: const Color(0xFFFDB022).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFFFDB022)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
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
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/lets-you-in',
                  (route) => false,
                );
              },
              child: const Text('Log Out', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
