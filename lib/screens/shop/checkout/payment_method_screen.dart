import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../../../widgets/progress_indicator_widget.dart';
import '../../../models/payment_method.dart';
import '../../../models/order.dart';
import '../../../models/address.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/firebase_service.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  PaymentType? _selectedPaymentType = PaymentType.debitCard;
  bool _isProcessing = false;
  Map<String, dynamic>? _shippingAddress;

  final List<PaymentMethodOption> _paymentMethods = [
    PaymentMethodOption(type: PaymentType.visa, label: 'Visa'),
    PaymentMethodOption(type: PaymentType.debitCard, label: 'Debit Card'),
    PaymentMethodOption(type: PaymentType.paypal, label: 'PayPal'),
    PaymentMethodOption(type: PaymentType.googlePay, label: 'Google pay'),
    PaymentMethodOption(type: PaymentType.cash, label: 'Cash'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('address')) {
      _shippingAddress = args['address'];
    }
  }

  Future<void> _processOrder() async {
    if (_shippingAddress == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Shipping address invalid')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final userId = userProvider.userId;

      if (cartProvider.items.isEmpty) {
        throw Exception('Cart is empty');
      }

      // Calculate totals
      final subtotal = cartProvider.subtotal;
      final shipping = 8.00; // Fixed for now
      final tax = subtotal * 0.05; // 5% tax
      final discount = 10.00; // Fixed promo for now
      final total = subtotal + shipping + tax - discount;

      // Create Order Items
      final orderItems = cartProvider.items.map((cartItem) {
        return OrderItem(
          productId: cartItem.productId,
          productName: cartItem.name,
          imageUrl: cartItem.imageUrl,
          quantity: cartItem.quantity,
          price: cartItem.price,
          color: cartItem.color,
        );
      }).toList();

      // Create Order
      final orderId = const Uuid().v4();
      final orderNumber =
          'ORD-${Random().nextInt(99999).toString().padLeft(5, '0')}';

      // Parse shipping address
      final address = Address.fromMap(_shippingAddress!);

      final order = Order(
        id: orderId,
        userId: userId,
        orderNumber: orderNumber,
        orderDate: DateTime.now(),
        status: OrderStatus.pending,
        items: orderItems,
        subtotal: subtotal,
        shippingCharge: shipping,
        discount: discount,
        tax: tax,
        shippingAddress: address,
        paymentMethod: _selectedPaymentType.toString().split('.').last,
        paymentStatus: 'paid', // Assuming success for demo
      );

      // Save to Firebase
      await FirebaseService.createOrder(userId, order);

      // Clear Cart
      await cartProvider.clearCart();

      // Navigate to success
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/payment-success',
          arguments: {'orderId': orderId},
        );
      }
    } catch (e) {
      print('Error processing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to place order: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If no address passed, redirect back (or show error)
    // For safety, we check in didChangeDependencies or build,
    // but better to handle it gracefully.

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
          'Payment',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const CheckoutProgressIndicator(currentStep: 2),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select payment method',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Payment methods list
                      ...List.generate(_paymentMethods.length, (index) {
                        final method = _paymentMethods[index];
                        return _buildPaymentOption(method);
                      }),
                    ],
                  ),
                ),
              ),
              // Pay now button
              Container(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _processOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDB022),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Pay now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(PaymentMethodOption method) {
    final isSelected = _selectedPaymentType == method.type;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? const Color(0xFFFDB022) : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RadioListTile<PaymentType>(
        value: method.type,
        groupValue: _selectedPaymentType,
        onChanged: (PaymentType? value) {
          setState(() {
            _selectedPaymentType = value;
          });
        },
        title: Row(
          children: [
            Icon(_getPaymentIcon(method.type), size: 24),
            const SizedBox(width: 12),
            Text(
              method.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        activeColor: const Color(0xFFFDB022),
      ),
    );
  }

  IconData _getPaymentIcon(PaymentType type) {
    switch (type) {
      case PaymentType.visa:
        return Icons.credit_card;
      case PaymentType.debitCard:
        return Icons.credit_card;
      case PaymentType.paypal:
        return Icons.paypal;
      case PaymentType.googlePay:
        return Icons.g_mobiledata;
      case PaymentType.cash:
        return Icons.money;
    }
  }
}

class PaymentMethodOption {
  final PaymentType type;
  final String label;

  PaymentMethodOption({required this.type, required this.label});
}
