enum PaymentType { visa, debitCard, paypal, googlePay, cash }

class PaymentMethod {
  final String id;
  final PaymentType type;
  final String displayName;
  final String? cardNumber; // Last 4 digits for cards
  final String? expiryDate;
  final bool isDefault;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.displayName,
    this.cardNumber,
    this.expiryDate,
    this.isDefault = false,
  });

  String get iconAsset {
    switch (type) {
      case PaymentType.visa:
        return 'assets/images/visa_logo.png';
      case PaymentType.debitCard:
        return 'assets/images/mastercard_logo.png';
      case PaymentType.paypal:
        return 'assets/images/paypal_logo.png';
      case PaymentType.googlePay:
        return 'assets/images/googlepay_logo.png';
      case PaymentType.cash:
        return 'assets/images/cash_icon.png';
    }
  }

  PaymentMethod copyWith({
    String? id,
    PaymentType? type,
    String? displayName,
    String? cardNumber,
    String? expiryDate,
    bool? isDefault,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      cardNumber: cardNumber ?? this.cardNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'displayName': displayName,
      'cardNumber': cardNumber,
      'expiryDate': expiryDate,
      'isDefault': isDefault,
    };
  }

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as String,
      type: PaymentType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => PaymentType.cash,
      ),
      displayName: json['displayName'] as String,
      cardNumber: json['cardNumber'] as String?,
      expiryDate: json['expiryDate'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}
