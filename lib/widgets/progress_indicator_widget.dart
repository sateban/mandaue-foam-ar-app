import 'package:flutter/material.dart';

class CheckoutProgressIndicator extends StatelessWidget {
  final int currentStep; // 0 = Checkout, 1 = Address, 2 = Payment

  const CheckoutProgressIndicator({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          _buildStep(0, 'Checkout'),
          _buildConnector(0),
          _buildStep(1, 'Address'),
          _buildConnector(1),
          _buildStep(2, 'Payment'),
        ],
      ),
    );
  }

  Widget _buildStep(int step, String label) {
    final isActive = step <= currentStep;
    final isCurrent = step == currentStep;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? const Color(0xFFFDB022) : Colors.grey[300],
          ),
          child: Center(
            child: Icon(
              step < currentStep ? Icons.check : Icons.circle,
              size: step < currentStep ? 20 : 12,
              color: isActive ? Colors.white : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? const Color(0xFF1E3A8A) : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(int step) {
    final isActive = step < currentStep;

    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24),
        color: isActive ? const Color(0xFFFDB022) : Colors.grey[300],
      ),
    );
  }
}
