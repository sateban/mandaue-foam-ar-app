import 'package:flutter/material.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../models/coupon.dart';

class CouponsScreen extends StatelessWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Coupon> coupons = [
      Coupon(
        id: '1',
        code: 'SAVE10',
        title: '10% Off',
        description: 'Get 10% off on all furniture',
        type: CouponType.percentage,
        value: 10,
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        minimumPurchase: 100,
      ),
      Coupon(
        id: '2',
        code: 'WELCOME20',
        title: '\$20 Off',
        description: 'Save \$20 on your first purchase',
        type: CouponType.fixed,
        value: 20,
        expiryDate: DateTime.now().add(const Duration(days: 15)),
        minimumPurchase: 150,
      ),
    ];

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
          'Coupons',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: coupons.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.local_offer_outlined,
              title: 'No Coupons',
              message: 'You don\'t have any coupons available at the moment.',
              buttonText: 'Browse Products',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: coupons.length,
              itemBuilder: (context, index) {
                return _buildCouponCard(coupons[index]);
              },
            ),
    );
  }

  Widget _buildCouponCard(Coupon coupon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFDB022), Color(0xFFFFD700)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coupon.discountText,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      coupon.title,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  coupon.code,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFDB022),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            coupon.description,
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Valid until ${coupon.expiryDate.day}/${coupon.expiryDate.month}/${coupon.expiryDate.year}',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
