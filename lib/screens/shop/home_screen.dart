import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import '../../data/dummy_data.dart' show categories, categoryImageUrls;
import '../../providers/product_provider.dart';
import '../../utils/slide_route.dart';
import '../../services/firebase_service.dart';
import '../../services/filebase_service.dart';
import '../../models/product.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'product_detail_screen.dart';
import 'shop_shell_scope.dart';
import 'package:logger/logger.dart';

var l = Logger();
class HomeScreen extends StatefulWidget {
  const HomeScreen({this.showBottomNav = true, super.key});

  final bool showBottomNav;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _allFirebaseProducts = [];
  List<String> _selectedCategories = [];
  double _minPrice = 0;
  double _maxPrice = 500;
  List<String> _selectedMaterials = [];
  List<String> _selectedColors = [];
  // Hero carousel
  late final PageController _heroPageController;
  int _heroCurrentIndex = 0;
  late List<String> _heroSlides;
  late List<String> _heroNames;
  Timer? _heroTimer;
  DateTime _lastHeroInteraction = DateTime.now();
  
  // Categories scroll
  late ScrollController _categoriesScrollController;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  // Search dropdown
  late TextEditingController _searchController;
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchDropdown = false;

  // Stream subscription for Firebase products
  StreamSubscription<List<Map<String, dynamic>>>? _productsSubscription;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _categoriesScrollController = ScrollController();
    _categoriesScrollController.addListener(_updateCategoriesScrollState);
    
    // Get products from ProductProvider (loaded from Firebase after sign-in)
    final productProvider = context.read<ProductProvider>();
    _filteredProducts = List.from(productProvider.products);

    // Load Firebase products
    _loadFirebaseProducts();
    
    // Test Filebase credentials to diagnose 403 issue
    _testFilebaseConnection();

    // prepare hero slides (take up to 5 product images as slides)
    _heroSlides = _filteredProducts
        .take(5)
        .map<String>((p) => (p['imageUrl'] as String?) ?? '')
        .toList();
    _heroNames = _filteredProducts
        .take(5)
        .map<String>((p) => (p['name'] as String?) ?? '')
        .toList();
    if (_heroSlides.isEmpty) {
      _heroSlides = List.filled(5, '');
      _heroNames = List.filled(5, 'Astra Wood\nChair');
    } else if (_heroSlides.length < 5) {
      // pad to 5 slides
      _heroSlides = List.from(_heroSlides)
        ..addAll(List.filled(5 - _heroSlides.length, ''));
      _heroNames = List.from(_heroNames)
        ..addAll(List.filled(5 - _heroNames.length, 'Astra Wood\nChair'));
    }
    _heroPageController = PageController();
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_heroPageController.hasClients) return;
      
      // Check if user has recently interacted - pause auto-slide for 8 seconds
      final timeSinceInteraction = DateTime.now().difference(_lastHeroInteraction);
      if (timeSinceInteraction.inSeconds < 8) {
        // User interacted recently, skip auto-slide
        return;
      }
      
      _heroCurrentIndex = (_heroCurrentIndex + 1) % _heroSlides.length;
      _heroPageController.animateToPage(
        _heroCurrentIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadFirebaseProducts() async {
    try {
      final List<Map<String, dynamic>> productsData =
          await FirebaseService.readListData('products');

      print("✅ Products loaded from Firebase: ${productsData.length}");
      
      // Show first product path before transformation
      if (productsData.isNotEmpty) {
        print("📝 Sample Firebase imageUrl: ${productsData.first['imageUrl']}");
      }

      // Transform Firebase paths to full Filebase URLs
      final filebaseService = FilebaseService();
      final transformedProducts = filebaseService.transformProductsWithFilebaseUrls(productsData);
      
      // Show first product path after transformation
      if (transformedProducts.isNotEmpty) {
        print("🔄 After transformation: ${transformedProducts.first['imageUrl']}");
      }

      // Update hero slides from products with isHeroBanner == true
      _updateHeroSlidesFromProducts(transformedProducts);

      // Cancel previous subscription if it exists
      _productsSubscription?.cancel();

      // Listen to real-time updates
      _productsSubscription = FirebaseService.streamListData('/products')
          .listen(
            (productsList) {
              // ignore: avoid_print
              print('Stream products received: ${productsList.length} items');
              if (!mounted) return;
              
              // Transform Firebase paths to full Filebase URLs
              final transformedStreamProducts = filebaseService.transformProductsWithFilebaseUrls(productsList);
              
              // Update hero slides from products with isHeroBanner == true
              _updateHeroSlidesFromProducts(transformedStreamProducts);
              
              setState(() {
                _allFirebaseProducts = transformedStreamProducts;
                _filteredProducts = List.from(_allFirebaseProducts);
              });
              // Re-run search if there's an active search query
              if (_searchController.text.isNotEmpty) {
                _searchProducts(_searchController.text);
              }
            },
            onError: (error) {
              // ignore: avoid_print
              print('Error reading products: $error');
            },
          );

      if (!mounted) return;

      setState(() {
        _allFirebaseProducts = transformedProducts;
        _filteredProducts = List.from(_allFirebaseProducts);
      });
    } catch (e) {
      if (!mounted) return;
      print('Error loading Firebase products: $e');
    }
  }

  /// Test Filebase connection and credentials
  Future<void> _testFilebaseConnection() async {
    final filebaseService = FilebaseService();
    final result = await filebaseService.testCredentials();
    print('\n🧪 Filebase Credential Test Result:');
    print('   Status Code: ${result['statusCode']}');
    print('   Success: ${result['success']}');
    print('   Message: ${result['message']}');
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroPageController.dispose();
    _searchController.dispose();
    _categoriesScrollController.removeListener(_updateCategoriesScrollState);
    _categoriesScrollController.dispose();
    _productsSubscription?.cancel();
    super.dispose();
  }

  // ignore: unused_element
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
    _filteredProducts = _allFirebaseProducts.where((product) {
      bool categoryMatch =
          _selectedCategories.isEmpty ||
          _selectedCategories.contains(product['category']);
      bool priceMatch =
          product['price'] >= _minPrice && product['price'] <= _maxPrice;
      bool materialMatch =
          _selectedMaterials.isEmpty ||
          _selectedMaterials.contains(product['material']);
      bool colorMatch =
          _selectedColors.isEmpty || _selectedColors.contains(product['color']);

      return categoryMatch && priceMatch && materialMatch && colorMatch;
    }).toList();
  }

  /// Update categories scroll button visibility based on scroll position
  void _updateCategoriesScrollState() {
    setState(() {
      _canScrollLeft = _categoriesScrollController.offset > 0;
      _canScrollRight =
          _categoriesScrollController.offset <
          _categoriesScrollController.position.maxScrollExtent;
    });
  }

  /// Scroll categories list left
  void _scrollCategoriesLeft() {
    _categoriesScrollController.animateTo(
      _categoriesScrollController.offset - 120,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Scroll categories list right
  void _scrollCategoriesRight() {
    _categoriesScrollController.animateTo(
      _categoriesScrollController.offset + 120,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Filter products by isHeroBanner == true and update hero carousel slides
  void _updateHeroSlidesFromProducts(List<Map<String, dynamic>> products) {
    final heroBannerProducts = products
        .where((p) => p['isHeroBanner'] == true)
        .toList();
    
    if (heroBannerProducts.isEmpty) {
      // Use default placeholder if no hero banners found
      _heroSlides = List.filled(1, '');
      _heroNames = List.filled(1, 'Astra Wood\nChair');
      _heroCurrentIndex = 0;
      return;
    }

    // Extract URLs and names from hero banner products (show only actual banners)
    _heroSlides = heroBannerProducts
        .map<String>((p) => (p['imageUrl'] as String?) ?? '')
        .toList();
    _heroNames = heroBannerProducts
        .map<String>((p) => (p['name'] as String?) ?? 'Product')
        .toList();

    // Reset carousel index if needed
    if (_heroCurrentIndex >= _heroSlides.length) {
      _heroCurrentIndex = 0;
    }

    print('✨ Hero banners updated: ${_heroSlides.length} slides loaded');
    
    // Pre-cache hero banner images for instant display when sliding
    // Filter out empty URLs for pre-caching
    final nonEmptyUrls = _heroSlides.where((url) => url.isNotEmpty).toList();
    if (nonEmptyUrls.isNotEmpty) {
      final filebaseService = FilebaseService();
      // Don't await - background pre-caching
      filebaseService.preCacheImages(nonEmptyUrls);
    }
  }

  void _searchProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _searchResults = [];
        _showSearchDropdown = false;
      } else {
        _showSearchDropdown = true;
        final lowerQuery = query.toLowerCase();

        // Search in Firebase products
        List<Map<String, dynamic>> productsToSearch = _allFirebaseProducts;

        // ignore: avoid_print
        // print('Searching in ${_allFirebaseProducts.isNotEmpty ? 'Firebase' : 'Dummy'} products');
        // print('Total products available: ${productsToSearch.length}');
        // print('Query: $lowerQuery');

        _searchResults = productsToSearch
            .where((product) {
              final name = (product['name'] ?? '').toString().toLowerCase();
              final category = (product['category'] ?? '')
                  .toString()
                  .toLowerCase();
              final material = (product['material'] ?? '')
                  .toString()
                  .toLowerCase();
              final description = (product['description'] ?? '')
                  .toString()
                  .toLowerCase();

              final matches =
                  name.contains(lowerQuery) ||
                  category.contains(lowerQuery) ||
                  material.contains(lowerQuery) ||
                  description.contains(lowerQuery);

              if (matches) {
                // ignore: avoid_print
                // print('Match found: ${product['name']}');
              }

              return matches;
            })
            .take(8)
            .toList();

        // ignore: avoid_print
        // print('Search results: ${_searchResults.length} found');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with logo and search
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              width: 70,
                              // height: 30,
                              errorBuilder: (contesxt, error, stackTrace) {
                                return Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDB022),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'mandauefoam',
                                  style: TextStyle(
                                    color: Color(0xFF006ab2),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'home store',
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 41, 41, 41),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.notifications_outlined,
                                color: Color(0xFF1E3A8A),
                              ),
                              onPressed: () {
                                Navigator.pushNamed(context, '/notifications');
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.shopping_cart_outlined,
                                color: Color(0xFF1E3A8A),
                              ),
                              onPressed: () {
                                final shell = ShopShellScope.maybeOf(context);
                                if (shell != null && !widget.showBottomNav) {
                                  shell.setTab(1);
                                  return;
                                }
                                Navigator.of(
                                  context,
                                ).push(slideRoute(const CartScreen()));
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Search bar with dropdown
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(color: Colors.black),
                                onChanged: _searchProducts,
                                onTap: () {
                                  if (_searchController.text.isNotEmpty) {
                                    setState(() {
                                      _showSearchDropdown = true;
                                    });
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search...',
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                  border: InputBorder.none,
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Colors.grey,
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _showSearchDropdown = false;
                                              _searchResults = [];
                                            });
                                          },
                                        )
                                      : null,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Hero Banner
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF8B6F47),
                            Color.fromARGB(255, 255, 226, 206),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _heroNames[_heroCurrentIndex],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: null,
                                  style: const ButtonStyle(
                                    backgroundColor: WidgetStatePropertyAll(
                                      Colors.white,
                                    ),
                                    padding: WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Buy Now',
                                    style: TextStyle(
                                      color: Color(0xFF1E3A8A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: Column(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: PageView.builder(
                                      controller: _heroPageController,
                                      itemCount: _heroSlides.length,
                                      onPageChanged: (i) {
                                        // Record user interaction to pause auto-slide
                                        _lastHeroInteraction = DateTime.now();
                                        setState(() => _heroCurrentIndex = i);
                                      },
                                      itemBuilder: (context, index) {
                                        final url = _heroSlides[index];
                                        if (url.isEmpty) {
                                          return Container(
                                            color: Colors.white.withOpacity(
                                              0.12,
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.image_not_supported,
                                                color: Colors.white,
                                                size: 40,
                                              ),
                                            ),
                                          );
                                        }
                                        return AuthenticatedImage(
                                          imageUrl: url,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_heroSlides.length, (
                                    i,
                                  ) {
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      width: _heroCurrentIndex == i ? 10 : 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _heroCurrentIndex == i
                                            ? Colors.white
                                            : Colors.white54,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Categories Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Categories',
                          style: TextStyle(
                            color: Color(0xFF1E3A8A),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/categories');
                          },
                          child: const Text(
                            'View all',
                            style: TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          controller: _categoriesScrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () {},
                                child: Container(
                                  width: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: _AuthenticatedCategoryImage(
                                            imageUrl: categoryImageUrls[categories[index]] ?? '',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        categories[index],
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF1E3A8A),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Left arrow button
                      if (_canScrollLeft)
                        Positioned(
                          left: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(2, 0),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _scrollCategoriesLeft,
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.arrow_back,
                                    color: Color(0xFF1E3A8A),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Right arrow button
                      if (_canScrollRight)
                        Positioned(
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(-2, 0),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _scrollCategoriesRight,
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    color: Color(0xFF1E3A8A),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Popular Products Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Popular Products',
                          style: TextStyle(
                            color: Color(0xFF1E3A8A),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            // IconButton(
                            //   icon: const Icon(Icons.tune,
                            //       color: Color(0xFFFDB022), size: 24),
                            //   onPressed: () {
                            //     Navigator.push(
                            //       context,
                            //       MaterialPageRoute(
                            //         builder: (context) => FilterModal(
                            //           selectedCategories: _selectedCategories,
                            //           minPrice: _minPrice,
                            //           maxPrice: _maxPrice,
                            //           selectedMaterials: _selectedMaterials,
                            //           selectedColors: _selectedColors,
                            //           onApply: _applyFilters,
                            //         ),
                            //       ),
                            //     );
                            //   },
                            // ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/popular-products',
                                );
                              },
                              child: const Text(
                                'View all',
                                style: TextStyle(
                                  color: Color(0xFF1E3A8A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: _filteredProducts.take(4).toList().length,
                      itemBuilder: (context, index) {
                        final products = _filteredProducts.take(4).toList();
                        if (index >= products.length) {
                          return const SizedBox.shrink();
                        }
                        final product = products[index];
                        return _buildProductCard(product);
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // New Arrivals Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'New Arrivals',
                          style: TextStyle(
                            color: Color(0xFF1E3A8A),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            // IconButton(
                            //   icon: const Icon(Icons.tune,
                            //       color: Color(0xFFFDB022), size: 24),
                            //   onPressed: () {
                            //     Navigator.push(
                            //       context,
                            //       MaterialPageRoute(
                            //         builder: (context) => FilterModal(
                            //           selectedCategories: _selectedCategories,
                            //           minPrice: _minPrice,
                            //           maxPrice: _maxPrice,
                            //           selectedMaterials: _selectedMaterials,
                            //           selectedColors: _selectedColors,
                            //           onApply: _applyFilters,
                            //         ),
                            //       ),
                            //     );
                            //   },
                            // ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/new-arrivals');
                              },
                              child: const Text(
                                'View all',
                                style: TextStyle(
                                  color: Color(0xFF1E3A8A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _filteredProducts.take(4).length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return _buildNewArrivalItem(product);
                      },
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Search dropdown overlay (positioned above scroll content)
            if (_showSearchDropdown)
              Positioned(
                top: 16 + 70 + 16, // logo height + padding + spacing
                left: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.35,
                  ),
                  child: _searchResults.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'No results found for "${_searchController.text}"',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final product = _searchResults[index];
                            return ListTile(
                              dense: true,
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.grey[200],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: AuthenticatedImage(
                                    imageUrl: product['imageUrl'] ?? '',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              title: Text(
                                product['name'],
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E3A8A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '\$${product['price'].toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              onTap: () {
                                _searchController.clear();
                                setState(() {
                                  _showSearchDropdown = false;
                                  _searchResults = [];
                                });
                                // Create Product object from search result data
                                final selectedProduct = Product(
                                  id: product['id']?.toString() ?? '',
                                  name: product['name'] ?? '',
                                  price:
                                      (product['price'] as num?)?.toDouble() ??
                                      0.0,
                                  category: product['category'] ?? '',
                                  material: product['material'] ?? '',
                                  color: product['color'] ?? '',
                                  imageUrl: product['imageUrl'] ?? '',
                                  rating:
                                      (product['rating'] as num?)?.toDouble() ??
                                      0.0,
                                  reviews:
                                      (product['reviews'] as num?)?.toInt() ??
                                      0,
                                  isFavorite: product['isFavorite'] ?? false,
                                  discount: product['discount'],
                                  description: product['description'],
                                  quantity: product['quantity'] as int?,
                                  inStock: product['inStock'] ?? true,
                                );
                                // Navigate to product detail screen
                                Navigator.of(context).push(
                                  slideRoute(
                                    ProductDetailScreen(
                                      product: selectedProduct,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Home
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDB022),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.home,
                              color: Color(0xFF1E3A8A),
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Home',
                              style: TextStyle(
                                color: Color(0xFF1E3A8A),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Cart
                    GestureDetector(
                      onTap: () {
                        final shell = ShopShellScope.maybeOf(context);
                        if (shell != null && !widget.showBottomNav) {
                          shell.setTab(1);
                          return;
                        }
                        Navigator.of(
                          context,
                        ).push(slideRoute(const CartScreen()));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shopping_cart,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ),
                    ),
                    // Orders
                    GestureDetector(
                      onTap: () {
                        final shell = ShopShellScope.maybeOf(context);
                        if (shell != null && !widget.showBottomNav) {
                          shell.setTab(2);
                          return;
                        }
                        Navigator.of(
                          context,
                        ).push(slideRoute(const OrdersScreen()));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shopping_bag,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ),
                    ),
                    // Profile
                    GestureDetector(
                      onTap: () {
                        final shell = ShopShellScope.maybeOf(context);
                        if (shell != null && !widget.showBottomNav) {
                          shell.setTab(3);
                          return;
                        }
                        Navigator.of(
                          context,
                        ).push(slideRoute(const ProfileScreen()));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButton: null,
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final imageUrl = product['imageUrl'] ?? '';
    if (imageUrl.isNotEmpty) {
      print('🖼️  Product: ${product['name']} | URL: $imageUrl');
    }
    
    return GestureDetector(
      onTap: () {
        final selectedProduct = Product(
          id: product['id']?.toString() ?? '',
          name: product['name'] ?? '',
          price: (product['price'] as num?)?.toDouble() ?? 0.0,
          category: product['category'] ?? '',
          material: product['material'] ?? '',
          color: product['color'] ?? '',
          imageUrl: product['imageUrl'] ?? '',
          rating: (product['rating'] as num?)?.toDouble() ?? 0.0,
          reviews: (product['reviews'] as num?)?.toInt() ?? 0,
          isFavorite: product['isFavorite'] ?? false,
          discount: product['discount'],
          description: product['description'],
          quantity: product['quantity'] as int?,
          inStock: product['inStock'] ?? true,
        );
        Navigator.of(context).push(
          slideRoute(
            ProductDetailScreen(product: selectedProduct),
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
                    child: AuthenticatedImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
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
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
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

  Widget _buildNewArrivalItem(Map<String, dynamic> product) {
    final imageUrl = product['imageUrl'] ?? '';
    return GestureDetector(
      onTap: () {
        final selectedProduct = Product(
          id: product['id']?.toString() ?? '',
          name: product['name'] ?? '',
          price: (product['price'] as num?)?.toDouble() ?? 0.0,
          category: product['category'] ?? '',
          material: product['material'] ?? '',
          color: product['color'] ?? '',
          imageUrl: product['imageUrl'] ?? '',
          rating: (product['rating'] as num?)?.toDouble() ?? 0.0,
          reviews: (product['reviews'] as num?)?.toInt() ?? 0,
          isFavorite: product['isFavorite'] ?? false,
          discount: product['discount'],
          description: product['description'],
          quantity: product['quantity'] as int?,
          inStock: product['inStock'] ?? true,
        );
        Navigator.of(context).push(
          slideRoute(
            ProductDetailScreen(product: selectedProduct),
          ),
        );
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AuthenticatedImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
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
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFDB022),
                          size: 14,
                        ),
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
      ),
    );
  }
}

Future<void> showNotificationPanel(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Notifications',
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation1, animation2) {
      return SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: 0,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut)),
        child: FadeTransition(opacity: anim1, child: child),
      );
    },
  );
}
/// Widget to load images with AWS Signature V4 authentication
class AuthenticatedImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  const AuthenticatedImage({
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    super.key,
  });

  @override
  State<AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<AuthenticatedImage> {
  late Future<Uint8List?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = FilebaseService().getImageBytes(widget.imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Colors.grey[400],
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          print('❌ Image load error: ${snapshot.error}');
          return Center(
            child: Icon(
              Icons.image_outlined,
              color: Colors.grey,
              size: 48,
            ),
          );
        }

        return Image.memory(
          snapshot.data!,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
        );
      },
    );
  }
}

/// Authenticated image widget for categories that fetches images from Filebase
/// Caches the fetch Future so parent rebuilds (e.g., carousel slide) won't re-trigger downloads.
class _AuthenticatedCategoryImage extends StatefulWidget {
  final String imageUrl;

  const _AuthenticatedCategoryImage({required this.imageUrl});

  @override
  State<_AuthenticatedCategoryImage> createState() => _AuthenticatedCategoryImageState();
}

class _AuthenticatedCategoryImageState extends State<_AuthenticatedCategoryImage> {
  late Future<Uint8List?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = FilebaseService().getImageBytes(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant _AuthenticatedCategoryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageFuture = FilebaseService().getImageBytes(widget.imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _imageFuture,
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

        // Fallback: render a network image (public) or placeholder
        if (widget.imageUrl.isNotEmpty) {
          return Image.network(
            widget.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(
                  Icons.image_outlined,
                  color: Colors.grey,
                  size: 24,
                ),
              );
            },
          );
        }

        return const Center(
          child: Icon(
            Icons.image_outlined,
            color: Colors.grey,
            size: 24,
          ),
        );
      },
    );
  }
}