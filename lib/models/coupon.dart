enum CouponType { percentage, fixed }

class Coupon {
  final String id;
  final String code;
  final String title;
  final String description;
  final CouponType type;
  final double value; // Percentage (0-100) or fixed amount
  final DateTime expiryDate;
  final double? minimumPurchase;
  final bool isActive;

  Coupon({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.type,
    required this.value,
    required this.expiryDate,
    this.minimumPurchase,
    this.isActive = true,
  });

  bool get isExpired => DateTime.now().isAfter(expiryDate);

  String get discountText {
    if (type == CouponType.percentage) {
      return '${value.toInt()}% OFF';
    } else {
      return '\$${value.toStringAsFixed(2)} OFF';
    }
  }

  double calculateDiscount(double subtotal) {
    if (!isActive || isExpired) return 0;
    if (minimumPurchase != null && subtotal < minimumPurchase!) return 0;

    if (type == CouponType.percentage) {
      return subtotal * (value / 100);
    } else {
      return value;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'title': title,
      'description': description,
      'type': type.toString(),
      'value': value,
      'expiryDate': expiryDate.toIso8601String(),
      'minimumPurchase': minimumPurchase,
      'isActive': isActive,
    };
  }

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      type: CouponType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => CouponType.percentage,
      ),
      value: (json['value'] as num).toDouble(),
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      minimumPurchase: json['minimumPurchase'] != null
          ? (json['minimumPurchase'] as num).toDouble()
          : null,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
