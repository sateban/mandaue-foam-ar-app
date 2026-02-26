import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../services/firebase_service.dart';
import '../../services/filebase_service.dart';
import '../../providers/product_provider.dart';
import 'filter_modal.dart';
import 'product_detail_screen.dart';

class ItemCategoryScreen extends StatefulWidget {
  final String categoryName;

  const ItemCategoryScreen({required this.categoryName, super.key});

  @override
  State<ItemCategoryScreen> createState() => _ItemCategoryScreenState();
}

class _ItemCategoryScreenState extends State<ItemCategoryScreen> {
  late List<Product> _allProducts;
  late List<Product> _filteredProducts;
  int _itemsToShow = 4;
  final int _itemsPerLoad = 4;
  List<String> _selectedCategories = [];
  double _minPrice = 0;
  double _maxPrice = 500;
  List<String> _selectedMaterials = [];
  List<String> _selectedColors = [];
  StreamSubscription<List<Map<String, dynamic>>>? _productsSubscription;
  bool _isLoadingProducts = false;
  
  // Cache for products by category
  static final Map<String, List<Product>> _categoryCache = {};

  @override
  void initState() {
    super.initState();
    _allProducts = [];
    _filteredProducts = [];
    _selectedCategories = [widget.categoryName]; // Pre-select the category
    _loadCategoryProducts();
    _loadUserFavorites();
  }

  Future<void> _loadUserFavorites() async {
    try {
      final productProvider = context.read<ProductProvider>();
      await productProvider.loadUserFavorites();
      print('✅ User favorites loaded in ItemCategoryScreen');
    } catch (e) {
      print('Error loading user favorites: $e');
    }
  }

  Future<void> _loadCategoryProducts() async {
    try {
      setState(() {
        _isLoadingProducts = true;
      });

      // Check cache first
      if (_categoryCache.containsKey(widget.categoryName)) {
        setState(() {
          _allProducts = _categoryCache[widget.categoryName]!;
          _filterProducts();
          _isLoadingProducts = false;
        });
        return;
      }

      // Cancel previous subscription if it exists
      _productsSubscription?.cancel();

      // Listen to real-time updates from Firebase
      _productsSubscription = FirebaseService.streamListData('/products')
          .listen(
            (productsList) {
              if (!mounted) return;
              
              // Convert Firebase products to Product model and filter by category
              final convertedProducts = productsList
                  .where((productMap) => productMap['category'] == widget.categoryName)
                  .map((productMap) {
                return Product(
                  id: productMap['id'] ?? '',
                  name: productMap['name'] ?? 'Unknown',
                  price: (productMap['price'] ?? 0).toDouble(),
                  category: productMap['category'] ?? 'Other',
                  material: productMap['material'] ?? 'N/A',
                  color: productMap['color'] ?? 'N/A',
                  imageUrl: productMap['imageUrl'] ?? '',
                  rating: (productMap['rating'] ?? 0).toDouble(),
                  reviews: productMap['reviews'] ?? 0,
                  isFavorite: productMap['isFavorite'] ?? false,
                  discount: productMap['discount'],
                  description: productMap['description'],
                  quantity: productMap['quantity'],
                  inStock: productMap['inStock'] ?? true,
                  modelUrl: productMap['modelUrl'],
                  modelScale: (productMap['modelScale'] ?? 1.0).toDouble(),
                );
              }).toList();
              
              setState(() {
                _allProducts = convertedProducts;
                // Cache the results
                _categoryCache[widget.categoryName] = convertedProducts;
                _filterProducts();
                _isLoadingProducts = false;
              });
            },
            onError: (error) {
              print('Error loading category products: $error');
              setState(() {
                _isLoadingProducts = false;
              });
            },
          );
    } catch (e) {
      print('Error in _loadCategoryProducts: $e');
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    super.dispose();
  }

  void _applyFilters(List<String> categories, double minPrice, double maxPrice,
      List<String> materials, List<String> colors) {
    setState(() {
      // Only allow the current category to be selected
      _selectedCategories = [widget.categoryName];
      _minPrice = minPrice;
      _maxPrice = maxPrice;
      _selectedMaterials = materials;
      _selectedColors = colors;
      _itemsToShow = 4; // Reset pagination when filters change
      _filterProducts();
    });
  }

  void _filterProducts() {
    _filteredProducts = _allProducts.where((product) {
      // Category is always the current category
      bool categoryMatch = product.category == widget.categoryName;
      bool priceMatch =
          product.price >= _minPrice && product.price <= _maxPrice;
      bool materialMatch = _selectedMaterials.isEmpty ||
          _selectedMaterials.contains(product.material);
      bool colorMatch =
          _selectedColors.isEmpty || _selectedColors.contains(product.color);

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
        title: Text(
          widget.categoryName,
          style: const TextStyle(
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
      body: _isLoadingProducts
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFFFDB022)),
            ),
          )
        : _filteredProducts.isEmpty
          ? Center(
              child: Text(
                'No products found in ${widget.categoryName}',
                style: const TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _itemsToShow >= _filteredProducts.length 
            ? _filteredProducts.length 
            : _itemsToShow + 1, // +1 for load more button
          itemBuilder: (context, index) {
            if (index == _itemsToShow && _itemsToShow < _filteredProducts.length) {
              // Load more button
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
            if (index >= _filteredProducts.length) {
              return const SizedBox.shrink();
            }
            return _buildProductCard(_filteredProducts[index]);
          },
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Container(
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
                      child: _AuthenticatedProductImage(
                        imageUrl: product.imageUrl,
                      ),
                    ),
                  ),
                  if (product.discount != null)
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
                          product.discount!,
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
                      onTap: () {
                        try {
                          final productProvider = context.read<ProductProvider>();
                          final wasFavorite = product.isFavorite;
                          
                          // Optimistic update - update UI immediately
                          product.isFavorite = !wasFavorite;
                          setState(() {});
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  product.isFavorite ? 'Added to favorites' : 'Removed from favorites',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                          
                          // Update Firebase in background without awaiting
                          productProvider.toggleProductFavorite(product.id)
                            .catchError((e) {
                              // Rollback on error
                              product.isFavorite = wasFavorite;
                              if (mounted) {
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to update favorites'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                              print('Error toggling favorite: $e');
                            });
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please sign in to add favorites'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                          print('Error toggling favorite: $e');
                        }
                      },
                      child: Icon(
                        product.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: product.isFavorite ? Colors.red : Colors.grey,
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
                    product.name,
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
                    '\$${product.price.toStringAsFixed(2)}',
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
                        '${product.rating}',
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
      ),
    );
  }
}

/// Authenticated image widget that fetches images from Filebase with proper auth
class _AuthenticatedProductImage extends StatelessWidget {
  final String imageUrl;

  const _AuthenticatedProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: FilebaseService().getImageBytes(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFFFDB022)),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
          );
        }
        
        return const Center(
          child: Icon(
            Icons.image_outlined,
            color: Colors.grey,
            size: 48,
          ),
        );
      },
    );
  }
}
