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
  });
}
