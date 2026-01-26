import 'package:flutter/material.dart';
import '../../../widgets/progress_indicator_widget.dart';
import '../../../models/payment_method.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  PaymentType? _selectedPaymentType = PaymentType.debitCard;

  final List<PaymentMethodOption> _paymentMethods = [
    PaymentMethodOption(type: PaymentType.visa, label: 'Visa'),
    PaymentMethodOption(type: PaymentType.debitCard, label: 'Debit Card'),
    PaymentMethodOption(type: PaymentType.paypal, label: 'PayPal'),
    PaymentMethodOption(type: PaymentType.googlePay, label: 'Google pay'),
    PaymentMethodOption(type: PaymentType.cash, label: 'Cash'),
  ];

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
          'Payment',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
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
                onPressed: () {
                  Navigator.pushNamed(context, '/payment-success');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDB022),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Pay now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
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
