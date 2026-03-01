import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../widgets/authenticated_image.dart';

class TrackOrderScreen extends StatelessWidget {
  final Order order;

  const TrackOrderScreen({required this.order, super.key});

  // Determine which step index is the "active" (current) step (0-based)
  int get _activeStepIndex {
    switch (order.status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.processing:
        return 1;
      case OrderStatus.shipped:
        return 2;
      case OrderStatus.delivered:
        return 3;
      case OrderStatus.cancelled:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    final estimatedDelivery =
        order.estimatedDelivery ?? order.orderDate.add(const Duration(days: 4));

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
          'Track Order',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product Card (first item) ──────────────────────────────────
            if (firstItem != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AuthenticatedImage(
                          imageUrl: firstItem.imageUrl,
                          fit: BoxFit.contain,
                          errorWidget: Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: Colors.grey[400],
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            firstItem.productName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Qty: ${firstItem.quantity.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${firstItem.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Order Details ──────────────────────────────────────────────
            const Text(
              'Order Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Order ID', order.orderNumber),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Expected Delivery Date',
              _formatDisplayDate(estimatedDelivery),
              valueColor: const Color(0xFF1E3A8A),
            ),
            const SizedBox(height: 28),

            // ── Order Status Timeline ──────────────────────────────────────
            const Text(
              'Order Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 16),

            _buildStatusTimeline(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? const Color(0xFF1E3A8A),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTimeline() {
    final steps = [
      _TrackStep(
        title: 'Order placed',
        date: order.orderDate,
        icon: Icons.inventory_2_outlined,
      ),
      _TrackStep(
        title: 'In progress',
        date: order.orderDate.add(const Duration(hours: 1, minutes: 15)),
        icon: Icons.access_time_outlined,
      ),
      _TrackStep(
        title: 'Shipped',
        date: order.orderDate.add(const Duration(days: 2)),
        icon: Icons.local_shipping_outlined,
        isExpected:
            order.status == OrderStatus.pending ||
            order.status == OrderStatus.processing,
      ),
      _TrackStep(
        title: 'Order delivered',
        date:
            order.estimatedDelivery ??
            order.orderDate.add(const Duration(days: 4)),
        icon: Icons.inventory_outlined,
        isExpected: order.status != OrderStatus.delivered,
      ),
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        // A step is "done" if its index <= activeStepIndex
        final isDone = index <= _activeStepIndex;
        final isActive = index == _activeStepIndex;
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline column
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  // Circle
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? const Color(0xFF4CAF50)
                          : isDone
                          ? Colors.grey[400]
                          : Colors.grey[200],
                      border: isDone && !isActive
                          ? Border.all(color: Colors.grey[400]!, width: 1)
                          : null,
                    ),
                    child: Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                  // Connector line
                  if (!isLast)
                    Container(width: 2, height: 56, color: Colors.grey[300]),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            step.isExpected
                                ? 'Expected on ${_formatDisplayDate(step.date)}'
                                : _formatFullDateTime(step.date),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (!isLast) const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    // Step icon on the right
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        step.icon,
                        color: const Color(0xFF1E3A8A),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  String _formatDisplayDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  String _formatFullDateTime(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
        ? 12
        : date.hour;
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]}, ${date.year}  |  $hour:$minute $amPm';
  }
}

class _TrackStep {
  final String title;
  final DateTime date;
  final IconData icon;
  final bool isExpected;

  const _TrackStep({
    required this.title,
    required this.date,
    required this.icon,
    this.isExpected = false,
  });
}
