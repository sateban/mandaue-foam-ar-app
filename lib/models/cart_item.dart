class CartItem {
  final String id; // Unique cart item ID (Firebase key)
  final String productId; // Reference to the product
  final String name;
  final String color;
  final double price;
  final int quantity;
  final String imageUrl;
  final DateTime addedAt;
  final DateTime updatedAt;

  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.color,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.addedAt,
    required this.updatedAt,
  });

  /// Create CartItem from JSON (Firebase data)
  factory CartItem.fromJson(String id, Map<String, dynamic> json) {
    return CartItem(
      id: id,
      productId: json['productId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 1,
      imageUrl: json['imageUrl'] as String? ?? '',
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Convert CartItem to JSON (for Firebase)
  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'color': color,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'addedAt': addedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  CartItem copyWith({
    String? id,
    String? productId,
    String? name,
    String? color,
    double? price,
    int? quantity,
    String? imageUrl,
    DateTime? addedAt,
    DateTime? updatedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      color: color ?? this.color,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculate total price for this item
  double get totalPrice => price * quantity;
}
