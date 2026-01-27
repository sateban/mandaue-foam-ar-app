import 'package:flutter/material.dart';

import 'cart_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'shop_shell_scope.dart';

class ShopShell extends StatefulWidget {
  const ShopShell({this.initialIndex = 0, super.key});

  final int initialIndex;

  @override
  State<ShopShell> createState() => _ShopShellState();
}

class _ShopShellState extends State<ShopShell> {
  int _currentIndex = 0;
  int _previousIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(showBottomNav: false),
    CartScreen(showBottomNav: false),
    OrdersScreen(showBottomNav: false),
    ProfileScreen(showBottomNav: false),
  ];

  void _onTap(int newIndex) {
    if (newIndex == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = newIndex;
    });
  }

  @override
  void initState() {
    super.initState();
    final idx = widget.initialIndex.clamp(0, _pages.length - 1);
    _currentIndex = idx;
    _previousIndex = idx;
  }

  @override
  Widget build(BuildContext context) {
    final direction = _currentIndex >= _previousIndex ? 1 : -1;

    return ShopShellScope(
      setTab: _onTap,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              final offsetTween = Tween<Offset>(
                begin: Offset(0.12 * direction, 0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic));
              return SlideTransition(
                position: animation.drive(offsetTween),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_currentIndex),
              child: _pages[_currentIndex],
            ),
          ),
        ),
        bottomNavigationBar: _BottomNav(
          currentIndex: _currentIndex,
          onTap: _onTap,
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              label: 'Home',
              icon: Icons.home,
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              label: 'Cart',
              icon: Icons.shopping_cart,
              selected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            _NavItem(
              label: 'Orders',
              icon: Icons.shopping_bag,
              selected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
            _NavItem(
              label: 'Profile',
              icon: Icons.person,
              selected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFDB022),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF1E3A8A), size: 24),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.grey, size: 24),
      ),
    );
  }
}
