import 'package:flutter/material.dart';
import '../../widgets/empty_state_widget.dart';
import '../../models/order.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({this.showBottomNav = true, super.key});

  final bool showBottomNav;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Order> _pendingOrders = [
    Order(
      id: '1',
      orderNumber: 'ORD-2024-001',
      orderDate: DateTime.now().subtract(const Duration(days: 2)),
      status: OrderStatus.pending,
      items: [
        OrderItem(
          productId: '1',
          productName: 'Crafted chair',
          imageUrl: 'assets/images/chair.png',
          quantity: 1,
          price: 135.00,
          color: 'Brown',
        ),
        OrderItem(
          productId: '2',
          productName: 'Cozy couch',
          imageUrl: 'assets/images/couch.png',
          quantity: 1,
          price: 190.00,
          color: 'Beige',
        ),
      ],
      subtotal: 325.00,
      shippingCharge: 8.00,
      discount: 0.00,
      tax: 10.00,
      trackingNumber: 'TRK123456789',
    ),
  ];

  final List<Order> _completedOrders = [];
  final List<Order> _cancelledOrders = [];

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
          'My Orders',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          indicator: BoxDecoration(
            color: const Color(0xFFFDB022),
            borderRadius: BorderRadius.circular(25),
          ),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(_pendingOrders, OrderStatus.pending),
          _buildOrderList(_completedOrders, OrderStatus.delivered),
          _buildOrderList(_cancelledOrders, OrderStatus.cancelled),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<Order> orders, OrderStatus status) {
    if (orders.isEmpty) {
      return _buildEmptyState(status);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _buildOrderCard(orders[index]);
      },
    );
  }

  Widget _buildEmptyState(OrderStatus status) {
    String title, message, buttonText;

    switch (status) {
      case OrderStatus.pending:
        title = 'No Pending Orders';
        message =
            'Looks like you haven\'t placed any orders waiting to be processed.';
        buttonText = 'Start Shopping';
        break;
      case OrderStatus.delivered:
        title = 'No Completed Orders';
        message = 'You don\'t have any completed orders yet.';
        buttonText = 'Start Shopping';
        break;
      case OrderStatus.cancelled:
        title = 'No Cancelled Orders';
        message = 'You don\'t have any cancelled orders.';
        buttonText = 'Start Shopping';
        break;
      default:
        title = 'No Orders';
        message = 'You don\'t have any orders yet.';
        buttonText = 'Start Shopping';
    }

    return EmptyStateWidget(
      icon: Icons.hourglass_empty,
      title: title,
      message: message,
      buttonText: buttonText,
      onButtonPressed: () {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      },
    );
  }

  Widget _buildOrderCard(Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chair_outlined,
                      size: 30,
                      color: Colors.grey[400],
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
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        Text(
                          'Qty: ${item.quantity.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      if (order.status == OrderStatus.pending)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/track-order',
                              arguments: order,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFDB022),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'Track Order',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
