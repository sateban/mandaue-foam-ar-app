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

class NewArrivalsScreen extends StatefulWidget {
  const NewArrivalsScreen({super.key});

  @override
  State<NewArrivalsScreen> createState() => _NewArrivalsScreenState();
}

class _NewArrivalsScreenState extends State<NewArrivalsScreen> {
  late List<Product> _products;
  late List<Product> _filteredProducts;
  int _itemsToShow = 4;
  final int _itemsPerLoad = 4;
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.addListener(_onScroll);

    context.read<ProductProvider>().addListener(_onProductProviderUpdate);

    _loadNewArrivalProducts();
    _loadUserFavorites();
  }

  Future<void> _loadUserFavorites() async {
    try {
      final productProvider = context.read<ProductProvider>();
      await productProvider.loadUserFavorites();
    } catch (e) {
    }
  }

  Future<void> _loadNewArrivalProducts() async {
    try {
      setState(() {
        _isLoadingProducts = true;
      });

      final filebaseService = FilebaseService();

      _productsSubscription?.cancel();

      _productsSubscription = FirebaseService.streamListData('/products').listen(
        (productsList) {
          if (!mounted) return;

          final newArrivalProducts = productsList.where((product) {
            return product['isNewArrival'] == true;
          }).toList();

          final transformedProducts = filebaseService
              .transformProductsWithFilebaseUrls(newArrivalProducts);

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
          setState(() {
            _isLoadingProducts = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  @override
  void dispose() {
    try {
      context.read<ProductProvider>().removeListener(_onProductProviderUpdate);
    } catch (_) {}

    _scrollController.dispose();
    _productsSubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (_itemsToShow < _filteredProducts.length) {
        _loadMoreItems();
      }
    }
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
      _itemsToShow = 4; 
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
          'New Arrivals',
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
                'No new arrival products found',
                style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 16),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              itemCount:
                  _itemsToShow +
                  (_itemsToShow < _filteredProducts.length ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _itemsToShow &&
                    _itemsToShow < _filteredProducts.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFFFDB022)),
                      ),
                    ),
                  );
                }
                if (index >= _filteredProducts.length) {
                  return const SizedBox.shrink();
                }
                return _buildNewArrivalItem(_filteredProducts[index]);
              },
            ),
    );
  }

  Widget _buildNewArrivalItem(Product product) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(slideRoute(ProductDetailScreen(product: product)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AuthenticatedImage(imageUrl: product.imageUrl),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
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
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₱${product.price.toStringAsFixed(2).replaceAllMapped(
                              RegExp(r'(\d)(?=(\d{3})+\.)'),
                              (Match m) => '${m[1]},',
                            )}',
                        style: const TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Color(0xFFFDB022),
                            size: 14,
                          ),
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
                ],
              ),
            ),
            Consumer<ProductProvider>(
              builder: (context, provider, _) {
                final isFav = provider.isFavorite(product.id);
                return GestureDetector(
                  onTap: () {
                    provider.toggleProductFavorite(product.id).catchError((e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to update favorites'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
