import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../services/firebase_service.dart';
import '../../providers/user_provider.dart';
import '../../widgets/authenticated_image.dart';
import 'track_order_screen.dart';
import 'write_review_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userId = userProvider.userId;

    if (!userProvider.isAuthenticated) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Please log in to view your orders.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(color: Color(0xFF1E3A8A)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1E3A8A),
              unselectedLabelColor: Colors.grey,
              indicator: BoxDecoration(
                color: const Color(0xFFFDB022),
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService.getOrders(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFDB022)),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final orderMaps = snapshot.data ?? [];
          final allOrders = orderMaps.map((m) {
            final typedMap = Map<String, dynamic>.from(m);
            if (typedMap['items'] != null) {
              typedMap['items'] = (typedMap['items'] as List)
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList();
            }
            if (typedMap['shippingAddress'] != null) {
              typedMap['shippingAddress'] = Map<String, dynamic>.from(
                typedMap['shippingAddress'] as Map,
              );
            }
            return Order.fromMap(typedMap);
          }).toList();

          final pendingOrders = allOrders
              .where(
                (o) =>
                    o.status == OrderStatus.pending ||
                    o.status == OrderStatus.processing ||
                    o.status == OrderStatus.shipped,
              )
              .toList();

          final completedOrders = allOrders
              .where((o) => o.status == OrderStatus.delivered)
              .toList();

          final cancelledOrders = allOrders
              .where((o) => o.status == OrderStatus.cancelled)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildPendingList(pendingOrders),
              _buildCompletedList(completedOrders),
              _buildCancelledList(cancelledOrders),
            ],
          );
        },
      ),
    );
  }

  // ─── Pending Tab ───────────────────────────────────────────────────────────

  Widget _buildPendingList(List<Order> orders) {
    if (orders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.shopping_bag_outlined,
        isIconYellow: false,
        title: 'No Pending Orders',
        message: "You don't have any active orders right now.",
        buttonText: 'Start Shopping',
        onButton: () => _navigateToShop(),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) => _buildPendingOrderCard(orders[i]),
    );
  }

  Widget _buildPendingOrderCard(Order order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.orderNumber,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              _buildStatusChip(order.status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Items
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildOrderItemRow(item),
            ),
          ),

          const Divider(height: 1),
          const SizedBox(height: 12),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${order.items.length} items',
                style: TextStyle(color: Colors.grey[600]),
              ),
              Row(
                children: [
                  const Text('Total: ', style: TextStyle(color: Colors.grey)),
                  Text(
                  '₱${order.total.toStringAsFixed(2).replaceAllMapped(
                        RegExp(r'(\d)(?=(\d{3})+\.)'),
                        (Match m) => '${m[1]},',
                      )}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/order-receipt',
                      arguments: order.id,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E3A8A),
                    side: const BorderSide(color: Color(0xFF1E3A8A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('View Details'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrackOrderScreen(order: order),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDB022),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Track Order'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Completed Tab ─────────────────────────────────────────────────────────

  Widget _buildCompletedList(List<Order> orders) {
    if (orders.isEmpty) {
      return _buildEmptyState(
        customIcon: Icons.inventory_2_outlined,
        isIconYellow: true,
        title: 'No Completed Orders Yet',
        message: "Once you finish your first purchase, you'll see it here.",
        buttonText: 'Start Shopping',
        onButton: () => _navigateToShop(),
      );
    }

    // Flatten all items from completed orders into individual cards
    final List<({OrderItem item, Order order})> itemRows = [];
    for (final order in orders) {
      for (final item in order.items) {
        itemRows.add((item: item, order: order));
      }
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemRows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final entry = itemRows[i];
        return _buildCompletedItemCard(entry.item, entry.order);
      },
    );
  }

  Widget _buildCompletedItemCard(OrderItem item, Order order) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Product image
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AuthenticatedImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.contain,
                errorWidget: Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: Colors.grey[400],
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${(item.price * item.quantity).toStringAsFixed(2).replaceAllMapped(
                        RegExp(r'(\d)(?=(\d{3})+\.)'),
                        (Match m) => '${m[1]},',
                      )}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Buttons
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          WriteReviewScreen(item: item, orderId: order.id),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDB022),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Write Review',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrackOrderScreen(order: order),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View Status',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1E3A8A),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Cancelled Tab ─────────────────────────────────────────────────────────

  Widget _buildCancelledList(List<Order> orders) {
    if (orders.isEmpty) {
      return _buildEmptyState(
        customIconWidget: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFFDB022).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.close_rounded,
              color: Color(0xFFFDB022),
              size: 64,
            ),
          ),
        ),
        title: 'Cancel Order empty',
        message:
            "Good news! You don't have any cancelled orders. Everything is on track!",
        buttonText: 'Discover More',
        onButton: () => _navigateToShop(),
      );
    }

    final List<({OrderItem item, Order order})> itemRows = [];
    for (final order in orders) {
      for (final item in order.items) {
        itemRows.add((item: item, order: order));
      }
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemRows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final entry = itemRows[i];
        return _buildCancelledItemCard(entry.item, entry.order);
      },
    );
  }

  Widget _buildCancelledItemCard(OrderItem item, Order order) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Product image
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AuthenticatedImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.contain,
                errorWidget: Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: Colors.grey[400],
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${(item.price * item.quantity).toStringAsFixed(2).replaceAllMapped(
                        RegExp(r'(\d)(?=(\d{3})+\.)'),
                        (Match m) => '${m[1]},',
                      )}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Buttons
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item.productName} added to cart'),
                      backgroundColor: const Color(0xFFFDB022),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDB022),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Re-Order',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrackOrderScreen(order: order),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View Status',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1E3A8A),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Shared helpers ────────────────────────────────────────────────────────

  Widget _buildOrderItemRow(OrderItem item) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AuthenticatedImage(
              imageUrl: item.imageUrl,
              fit: BoxFit.contain,
              errorWidget: Center(
                child: Icon(
                  Icons.image_outlined,
                  color: Colors.grey[400],
                  size: 24,
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
                item.productName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${item.quantity} x ₱${item.price.toStringAsFixed(2).replaceAllMapped(
                      RegExp(r'(\d)(?=(\d{3})+\.)'),
                      (Match m) => '${m[1]},',
                    )}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getStatusText(status),
        style: TextStyle(
          color: _getStatusColor(status),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    IconData? icon,
    IconData? customIcon,
    Widget? customIconWidget,
    bool isIconYellow = false,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onButton,
  }) {
    Widget iconWidget;
    if (customIconWidget != null) {
      iconWidget = customIconWidget;
    } else {
      iconWidget = Icon(
        customIcon ?? icon ?? Icons.inbox_outlined,
        size: 64,
        color: isIconYellow ? const Color(0xFFFDB022) : Colors.grey[400],
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onButton,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDB022),
                  foregroundColor: const Color(0xFF1E3A8A),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.processing:
        return Colors.blue;
      case OrderStatus.shipped:
        return Colors.purple;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  void _navigateToShop() {
    // Pop back to the shop shell / home tab
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
