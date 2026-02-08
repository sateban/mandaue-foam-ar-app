import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/authenticated_image.dart';
import '../../providers/cart_provider.dart';
import '../../models/cart_item.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({this.showBottomNav = true, super.key});

  final bool showBottomNav;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _promoController = TextEditingController();
  double _discount = 0.0;

  @override
  void initState() {
    super.initState();
    // Load cart when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().loadCart();
    });
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  double get _shippingCharge => 8.00;
  double get _tax => 10.00;

  void _updateQuantity(String id, int delta, CartProvider cartProvider) async {
    final item = cartProvider.items.firstWhere((item) => item.id == id);
    final newQuantity = item.quantity + delta;

    if (newQuantity > 0) {
      try {
        await cartProvider.updateQuantity(id, newQuantity);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating quantity: $e')),
          );
        }
      }
    }
  }

  void _removeItem(String id, CartProvider cartProvider) async {
    try {
      await cartProvider.removeItem(id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item removed from cart')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error removing item: $e')));
      }
    }
  }

  void _applyPromoCode(double subtotal) {
    // Mock promo code logic
    if (_promoController.text.toLowerCase() == 'save10') {
      setState(() {
        _discount = subtotal * 0.1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promo code applied! 10% discount')),
      );
    } else if (_promoController.text.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid promo code')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'My Cart',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFDB022)),
            );
          }

          if (cartProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading cart',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cartProvider.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => cartProvider.loadCart(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (cartProvider.items.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.shopping_cart_outlined,
              title: 'Oops! Cart Looks Empty',
              message:
                  'Looks like you haven\'t picked anything yet. Start exploring now!',
              buttonText: 'Add Products',
              onButtonPressed: () {
                Navigator.pop(context);
              },
            );
          }

          final subtotal = cartProvider.subtotal;
          final total = subtotal + _shippingCharge - _discount + _tax;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cartProvider.items.length,
                  itemBuilder: (context, index) {
                    return _buildCartItem(
                      cartProvider.items[index],
                      cartProvider,
                    );
                  },
                ),
              ),
              _buildSummary(subtotal, total, cartProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCartItem(CartItem item, CartProvider cartProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Product image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: AuthenticatedImage(
              imageUrl: item.imageUrl,
              fit: BoxFit.cover,
              placeholder: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: const Color(0xFFFDB022),
                ),
              ),
              errorWidget: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 30,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.color,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${item.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),
          // Quantity controls
          Row(
            children: [
              IconButton(
                onPressed: () => _updateQuantity(item.id, -1, cartProvider),
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.grey,
              ),
              Text(
                item.quantity.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: () => _updateQuantity(item.id, 1, cartProvider),
                icon: const Icon(Icons.add_circle),
                color: const Color(0xFFFDB022),
              ),
            ],
          ),
          // Delete button
          IconButton(
            onPressed: () => _removeItem(item.id, cartProvider),
            icon: const Icon(Icons.delete_outline),
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(
    double subtotal,
    double total,
    CartProvider cartProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Promo code
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoController,
                  decoration: InputDecoration(
                    hintText: 'Enter promo code',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _applyPromoCode(subtotal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Price breakdown
          _buildPriceRow('Subtotal', subtotal),
          _buildPriceRow('Shipping Charge', _shippingCharge),
          if (_discount > 0)
            _buildPriceRow('Coupon Discount', -_discount, isDiscount: true),
          _buildPriceRow('Tax', _tax),
          const Divider(height: 24),
          _buildPriceRow('Total', total, isTotal: true),
          const SizedBox(height: 16),
          // Checkout button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: cartProvider.items.isEmpty
                  ? null
                  : () {
                      Navigator.pushNamed(context, '/shipping-address');
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDB022),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'Checkout Now',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? const Color(0xFF1E3A8A) : Colors.grey[600],
            ),
          ),
          Text(
            isDiscount
                ? '-\$${amount.abs().toStringAsFixed(2)}'
                : '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal
                  ? const Color(0xFF1E3A8A)
                  : isDiscount
                  ? Colors.green
                  : const Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    );
  }
}
