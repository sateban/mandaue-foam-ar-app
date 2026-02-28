class ProductVariation {
  final String color;
  final String imageUrl;
  final String? modelUrl;

  ProductVariation({
    required this.color,
    required this.imageUrl,
    this.modelUrl,
  });
}

class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final String material;
  final String color;
  final String imageUrl;
  final double rating;
  final int reviews;
  bool isFavorite;
  String? discount;
  String? description;
  int? quantity;
  bool? inStock;
  String? modelUrl;
  double? modelScale;
  final Map<String, ProductVariation>? variations;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.material,
    required this.color,
    required this.imageUrl,
    required this.rating,
    required this.reviews,
    this.isFavorite = false,
    this.discount,
    this.description,
    this.quantity,
    this.inStock = true,
    this.modelUrl,
    this.modelScale,
    this.variations,
  });

  /// Returns all variations including the default one
  List<ProductVariation> getAllVariations() {
    final list = <ProductVariation>[];
    // Add base variation first
    list.add(
      ProductVariation(color: color, imageUrl: imageUrl, modelUrl: modelUrl),
    );
    // Add variations from the map
    if (variations != null) {
      list.addAll(variations!.values);
    }
    return list;
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    Map<String, ProductVariation>? variations;
    if (map['variation'] is Map) {
      variations = {};
      (map['variation'] as Map).forEach((color, details) {
        if (details is Map) {
          variations![color] = ProductVariation(
            color: color,
            imageUrl: details['imageUrl'] ?? '',
            modelUrl: details['modelUrl'],
          );
        }
      });
    }

    return Product(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? '',
      material: map['material'] ?? '',
      color: map['color'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: (map['reviews'] as num?)?.toInt() ?? 0,
      isFavorite: map['isFavorite'] ?? false,
      discount: map['discount'],
      description: map['description'],
      quantity: map['quantity'] as int?,
      inStock: map['inStock'] ?? true,
      modelUrl: map['modelUrl'],
      modelScale: (map['modelScale'] as num?)?.toDouble(),
      variations: variations,
    );
  }
}
