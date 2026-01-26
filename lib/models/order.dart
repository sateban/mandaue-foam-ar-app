enum OrderStatus { pending, processing, shipped, delivered, cancelled }

class OrderItem {
  final String productId;
  final String productName;
  final String imageUrl;
  final int quantity;
  final double price;
  final String? color;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.quantity,
    required this.price,
    this.color,
  });

  double get total => price * quantity;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'price': price,
      'color': color,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      imageUrl: json['imageUrl'] as String,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      color: json['color'] as String?,
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final DateTime orderDate;
  final OrderStatus status;
  final List<OrderItem> items;
  final double subtotal;
  final double shippingCharge;
  final double discount;
  final double tax;
  final String? trackingNumber;
  final DateTime? estimatedDelivery;

  Order({
    required this.id,
    required this.orderNumber,
    required this.orderDate,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.shippingCharge,
    required this.discount,
    required this.tax,
    this.trackingNumber,
    this.estimatedDelivery,
  });

  double get total => subtotal + shippingCharge - discount + tax;

  String get statusText {
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'orderDate': orderDate.toIso8601String(),
      'status': status.toString(),
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'shippingCharge': shippingCharge,
      'discount': discount,
      'tax': tax,
      'trackingNumber': trackingNumber,
      'estimatedDelivery': estimatedDelivery?.toIso8601String(),
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      orderNumber: json['orderNumber'] as String,
      orderDate: DateTime.parse(json['orderDate'] as String),
      status: OrderStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => OrderStatus.pending,
      ),
      items: (json['items'] as List)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      shippingCharge: (json['shippingCharge'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      tax: (json['tax'] as num).toDouble(),
      trackingNumber: json['trackingNumber'] as String?,
      estimatedDelivery: json['estimatedDelivery'] != null
          ? DateTime.parse(json['estimatedDelivery'] as String)
          : null,
    );
  }
}
