import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../services/filebase_service.dart';
import '../../models/product.dart';
import '../../utils/slide_route.dart';
import 'product_detail_screen.dart';
import '../../widgets/authenticated_image.dart';
import '../../providers/product_provider.dart';
import 'filter_modal.dart';

class PopularProductsScreen extends StatefulWidget {
  const PopularProductsScreen({super.key});

  @override
  State<PopularProductsScreen> createState() => _PopularProductsScreenState();
}

class _PopularProductsScreenState extends State<PopularProductsScreen> {
  late List<Product> _products;
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

  void _onProductProviderUpdate() {
    if (!mounted) return;
    final productProvider = context.read<ProductProvider>();
    setState(() {
      // Update Product model objects in our local lists
      for (var p in _products) {
        final provP = productProvider.getProductById(p.id);
        if (provP != null) {
          p.isFavorite = provP['isFavorite'] ?? false;
        }
      }

      for (var p in _filteredProducts) {
        final provP = productProvider.getProductById(p.id);
        if (provP != null) {
          p.isFavorite = provP['isFavorite'] ?? false;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _products = [];
    _filteredProducts = [];

    // Register listener for ProductProvider to sync favorites across screens
    context.read<ProductProvider>().addListener(_onProductProviderUpdate);

    _loadPopularProducts();
    _loadUserFavorites();
  }

  Future<void> _loadUserFavorites() async {
    try {
      final productProvider = context.read<ProductProvider>();
      await productProvider.loadUserFavorites();
      print('✅ User favorites loaded in PopularProductsScreen');
    } catch (e) {
      print('Error loading user favorites: $e');
    }
  }

  Future<void> _loadPopularProducts() async {
    try {
      setState(() {
        _isLoadingProducts = true;
      });

      final filebaseService = FilebaseService();

      // Cancel previous subscription if it exists
      _productsSubscription?.cancel();

      // Listen to real-time updates from Firebase
      _productsSubscription = FirebaseService.streamListData('/products').listen(
        (productsList) {
          if (!mounted) return;

          // Filter only popular products (isPopular == true)
          final popularProducts = productsList.where((product) {
            return product['isPopular'] == true;
          }).toList();

          // Transform Firebase paths to full Filebase URLs
          final transformedProducts = filebaseService
              .transformProductsWithFilebaseUrls(popularProducts);

          // Convert to Product models for robust mapping and to fix null errors
          final convertedProducts = transformedProducts.map<Product>((map) {
            return Product.fromMap(map);
          }).toList();

          setState(() {
            _products = convertedProducts;
            _filteredProducts = List.from(_products);
            _isLoadingProducts = false;
          });
        },
        onError: (error) {
          print('Error loading popular products: $error');
          setState(() {
            _isLoadingProducts = false;
          });
        },
      );
    } catch (e) {
      print('Error in _loadPopularProducts: $e');
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  @override
  void dispose() {
    // Unregister ProductProvider listener
    try {
      context.read<ProductProvider>().removeListener(_onProductProviderUpdate);
    } catch (_) {}

    _productsSubscription?.cancel();
    super.dispose();
  }

  void _applyFilters(
    List<String> categories,
    double minPrice,
    double maxPrice,
    List<String> materials,
    List<String> colors,
  ) {
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
      bool categoryMatch =
          _selectedCategories.isEmpty ||
          _selectedCategories.contains(product.category);
      bool priceMatch =
          product.price >= _minPrice && product.price <= _maxPrice;
      bool materialMatch =
          _selectedMaterials.isEmpty ||
          _selectedMaterials.contains(product.material);
      bool colorMatch =
          _selectedColors.isEmpty || _selectedColors.contains(product.color);

      return categoryMatch && priceMatch && materialMatch && colorMatch;
    }).toList();
  }

  void _loadMoreItems() {
    setState(() {
      _itemsToShow = (_itemsToShow + _itemsPerLoad).clamp(
        0,
        _filteredProducts.length,
      );
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
      body: _isLoadingProducts
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFFDB022)),
              ),
            )
          : _filteredProducts.isEmpty
          ? const Center(
              child: Text(
                'No popular products found',
                style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 16),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
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
                  if (index == _itemsToShow &&
                      _itemsToShow < _filteredProducts.length) {
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
        Navigator.of(
          context,
        ).push(slideRoute(ProductDetailScreen(product: product)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: AuthenticatedImage(imageUrl: product.imageUrl),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () {
                        try {
                          final productProvider = context
                              .read<ProductProvider>();
                          final wasIsFavorite = product.isFavorite;

                          // Optimistic update
                          product.isFavorite = !wasIsFavorite;
                          setState(() {});

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  product.isFavorite
                                      ? 'Added to favorites'
                                      : 'Removed from favorites',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }

                          // Update Firebase
                          productProvider
                              .toggleProductFavorite(product.id)
                              .catchError((e) {
                                // Rollback on error
                                product.isFavorite = wasIsFavorite;
                                if (mounted) {
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Failed to update favorites',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              });
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please sign in to add favorites',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          product.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 18,
                          color: product.isFavorite ? Colors.red : Colors.grey,
                        ),
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
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₱${product.price.toStringAsFixed(2).replaceAllMapped(
                              RegExp(r'(\d)(?=(\d{3})+\.)'),
                              (Match m) => '${m[1]},',
                            )}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFDB022),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Color(0xFFFDB022),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${product.rating}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
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
