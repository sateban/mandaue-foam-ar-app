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

  Map<String, dynamic> toMap() => toJson();

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      color: json['color'] as String?,
    );
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) =>
      OrderItem.fromJson(map);
}

class Order {
  final String id;
  final String userId;
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
  // New fields
  final Map<String, dynamic>? shippingAddress;
  final String? paymentMethod;
  final String? paymentStatus;

  Order({
    required this.id,
    required this.userId,
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
    this.shippingAddress,
    this.paymentMethod,
    this.paymentStatus,
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
      'userId': userId,
      'orderNumber': orderNumber,
      'orderDate': orderDate.toIso8601String(),
      'status': status.toString(), // or status.name if Dart >= 2.15
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'shippingCharge': shippingCharge,
      'discount': discount,
      'tax': tax,
      'trackingNumber': trackingNumber,
      'estimatedDelivery': estimatedDelivery?.toIso8601String(),
      'shippingAddress': shippingAddress,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      orderDate:
          DateTime.tryParse(json['orderDate'] as String? ?? '') ??
          DateTime.now(),
      status: OrderStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => OrderStatus.pending,
      ),
      items:
          (json['items'] as List?)
              ?.map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      shippingCharge: (json['shippingCharge'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      trackingNumber: json['trackingNumber'] as String?,
      estimatedDelivery: json['estimatedDelivery'] != null
          ? DateTime.tryParse(json['estimatedDelivery'] as String)
          : null,
      shippingAddress: json['shippingAddress'] as Map<String, dynamic>?,
      paymentMethod: json['paymentMethod'] as String?,
      paymentStatus: json['paymentStatus'] as String?,
    );
  }

  factory Order.fromMap(Map<String, dynamic> map) => Order.fromJson(map);
}
