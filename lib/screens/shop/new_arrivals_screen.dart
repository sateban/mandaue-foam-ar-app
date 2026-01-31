import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../services/filebase_service.dart';
import 'filter_modal.dart';

class NewArrivalsScreen extends StatefulWidget {
  const NewArrivalsScreen({super.key});

  @override
  State<NewArrivalsScreen> createState() => _NewArrivalsScreenState();
}

class _NewArrivalsScreenState extends State<NewArrivalsScreen> {
  late List<Map<String, dynamic>> _products;
  late List<Map<String, dynamic>> _filteredProducts;
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

  @override
  void initState() {
    super.initState();
    _products = [];
    _filteredProducts = [];
    _scrollController.addListener(_onScroll);
    _loadNewArrivalProducts();
  }

  Future<void> _loadNewArrivalProducts() async {
    try {
      setState(() {
        _isLoadingProducts = true;
      });

      final filebaseService = FilebaseService();

      // Cancel previous subscription if it exists
      _productsSubscription?.cancel();

      // Listen to real-time updates from Firebase
      _productsSubscription = FirebaseService.streamListData('/products')
          .listen(
            (productsList) {
              if (!mounted) return;
              
              // Filter only new arrival products (isNewArrival == true)
              final newArrivalProducts = productsList.where((product) {
                return product['isNewArrival'] == true;
              }).toList();
              
              // Transform Firebase paths to full Filebase URLs
              final transformedProducts = filebaseService.transformProductsWithFilebaseUrls(newArrivalProducts);
              
              setState(() {
                _products = transformedProducts;
                _filteredProducts = List.from(_products);
                _isLoadingProducts = false;
              });
            },
            onError: (error) {
              print('Error loading new arrival products: $error');
              setState(() {
                _isLoadingProducts = false;
              });
            },
          );
    } catch (e) {
      print('Error in _loadNewArrivalProducts: $e');
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _productsSubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (_itemsToShow < _filteredProducts.length) {
        _loadMoreItems();
      }
    }
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
      _itemsToShow = 4; // Reset to initial items when filtering
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
                style: TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontSize: 16,
                ),
              ),
            )
          : ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        itemCount: _itemsToShow + (_itemsToShow < _filteredProducts.length ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _itemsToShow && _itemsToShow < _filteredProducts.length) {
            // Loading indicator
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

  Widget _buildNewArrivalItem(Map<String, dynamic> product) {
    return Container(
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
              child: _AuthenticatedArrivalImage(
                imageUrl: product['imageUrl'] ?? '',
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
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
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${product['price'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Color(0xFFFDB022), size: 14),
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
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Icon(
              product['isFavorite'] ? Icons.favorite : Icons.favorite_border,
              color: product['isFavorite'] ? Colors.red : Colors.grey,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

/// Authenticated image widget for new arrivals that fetches images from Filebase
class _AuthenticatedArrivalImage extends StatelessWidget {
  final String imageUrl;

  const _AuthenticatedArrivalImage({required this.imageUrl});

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
            size: 40,
          ),
        );
      },
    );
  }
}
