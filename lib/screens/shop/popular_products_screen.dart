import 'package:flutter/material.dart';
import '../../data/dummy_data.dart';
import 'filter_modal.dart';

class PopularProductsScreen extends StatefulWidget {
  const PopularProductsScreen({super.key});

  @override
  State<PopularProductsScreen> createState() => _PopularProductsScreenState();
}

class _PopularProductsScreenState extends State<PopularProductsScreen> {
  late List<Map<String, dynamic>> _products;
  late List<Map<String, dynamic>> _filteredProducts;
  int _itemsToShow = 4;
  final int _itemsPerLoad = 4;
  List<String> _selectedCategories = [];
  double _minPrice = 0;
  double _maxPrice = 500;
  List<String> _selectedMaterials = [];
  List<String> _selectedColors = [];

  @override
  void initState() {
    super.initState();
    _products = List.from(dummyProducts);
    _filteredProducts = List.from(dummyProducts);
  }

  void _applyFilters(List<String> categories, double minPrice, double maxPrice,
      List<String> materials, List<String> colors) {
    setState(() {
      _selectedCategories = categories;
      _minPrice = minPrice;
      _maxPrice = maxPrice;
      _selectedMaterials = materials;
      _selectedColors = colors;
      _filterProducts();
    });
  }

  void _filterProducts() {
    _filteredProducts = _products.where((product) {
      bool categoryMatch = _selectedCategories.isEmpty ||
          _selectedCategories.contains(product['category']);
      bool priceMatch =
          product['price'] >= _minPrice && product['price'] <= _maxPrice;
      bool materialMatch = _selectedMaterials.isEmpty ||
          _selectedMaterials.contains(product['material']);
      bool colorMatch =
          _selectedColors.isEmpty || _selectedColors.contains(product['color']);

      return categoryMatch && priceMatch && materialMatch && colorMatch;
    }).toList();
  }

  void _loadMoreItems() {
    setState(() {
      _itemsToShow = (_itemsToShow + _itemsPerLoad).clamp(0, _filteredProducts.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Popular Products',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A8A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFFFDB022), size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FilterModal(
                    selectedCategories: _selectedCategories,
                    minPrice: _minPrice,
                    maxPrice: _maxPrice,
                    selectedMaterials: _selectedMaterials,
                    selectedColors: _selectedColors,
                    onApply: _applyFilters,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _itemsToShow + 1, // +1 for load more button
          itemBuilder: (context, index) {
            if (index == _itemsToShow) {
              // Load more button
              if (_itemsToShow < _filteredProducts.length) {
                return GestureDetector(
                  onTap: _loadMoreItems,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFDB022),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add,
                            color: Color(0xFFFDB022),
                            size: 32,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Load More',
                            style: TextStyle(
                              color: Color(0xFFFDB022),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }
            return _buildProductCard(_filteredProducts[index]);
          },
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Image.network(
                      product['imageUrl'] ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: Colors.grey,
                            size: 48,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (product['discount'] != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDB022),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product['discount'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {},
                    child: Icon(
                      product['isFavorite']
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: product['isFavorite'] ? Colors.red : Colors.grey,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'],
                  style: const TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${product['price'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFDB022), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${product['rating']}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
