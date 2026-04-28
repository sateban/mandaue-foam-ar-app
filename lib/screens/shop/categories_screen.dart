import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import '../../data/dummy_data.dart';
import '../../providers/product_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/filebase_service.dart';
import 'item_category_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late List<String> _categories;
  Map<String, String> _categoryImageUrls = Map.from(categoryImageUrls);
  Map<String, int> _categoryQuantities =
      {}; // Store quantity counts by category
  StreamSubscription<List<Map<String, dynamic>>>? _categoriesSubscription;

  @override
  void initState() {
    super.initState();
    _categories = List.from(categories);
    _loadFirebaseCategories();
    // Load products immediately
    Future.microtask(() {
      final productProvider = context.read<ProductProvider>();
      print(
        'ProductProvider initial products: ${productProvider.products.length}',
      );
      if (productProvider.products.isEmpty) {
        print('Loading products from Firebase...');
        productProvider.loadProducts();
      }
      // Calculate category stocks from products
      _calculateCategoryStocks(productProvider.products);
    });
  }

  void _calculateCategoryStocks(List<Map<String, dynamic>> products) {
    final Map<String, int> categoryQuantities = {};

    // Get quantity from first product in each category
    for (final product in products) {
      final category = product['category'] as String? ?? 'Other';
      print("categoryx: ${category}");
      // Only set if not already set (first product in category)
      // if (!categoryQuantities.containsKey(category)) {
        // final quantity = product['quantity'] as int? ?? 0;
        categoryQuantities[category] = (categoryQuantities[category] ?? 0) + 1;
      // }
    }

    setState(() {
      _categoryQuantities = categoryQuantities;
    });

    print('✅ Category quantities calculated: $_categoryQuantities');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'All Categories',
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<ProductProvider>(
          builder: (context, productProvider, child) {
            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                return _buildCategoryCard(_categories[index], productProvider);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String category, ProductProvider productProvider) {
    // Get quantity count directly from category data
    final productCount = _categoryQuantities[category] ?? 0;

    print('🔍 Category: $category | Total quantity: $productCount');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemCategoryScreen(categoryName: category),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _AuthenticatedCategoryImage(
                  imageUrl: _categoryImageUrls[category] ?? '',
                  cacheWidth: 128,
                  cacheHeight: 128,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // if (kDebugMode && (_categoryImageUrls[category] ?? '').isNotEmpty)
            //   Padding(
            //     padding: const EdgeInsets.symmetric(horizontal: 8.0),
            //     child: Text(
            //       _categoryImageUrls[category]!.truncate(34),
            //       textAlign: TextAlign.center,
            //       style: const TextStyle(
            //         color: Colors.grey,
            //         fontSize: 10,
            //         overflow: TextOverflow.ellipsis,
            //       ),
            //     ),
            //   ),
            const SizedBox(height: 8),
            Text(
              category,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFDB022),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$productCount items',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _categoriesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadFirebaseCategories() async {
    try {
      final categoriesData = await FirebaseService.readListData('categories');
      print('✅ Categories loaded from Firebase: ${categoriesData.length}');

      final filebase = FilebaseService();
      final Map<String, String> firebaseMapLower = {};

      for (final cat in categoriesData) {
        final name =
            (cat['name'] ?? cat['title'] ?? cat['id'])?.toString() ?? '';
        var imageUrl = _extractImageUrl(cat);
        if (imageUrl.isEmpty) continue;
        if (!imageUrl.startsWith('http')) {
          imageUrl = filebase.buildFilebaseImageUrl(imageUrl);
        }
        firebaseMapLower[name.toLowerCase()] = imageUrl;
      }

      setState(() {
        // override existing categories
        for (final categoryName in _categories) {
          final lower = categoryName.toLowerCase();
          if (firebaseMapLower.containsKey(lower)) {
            _categoryImageUrls[categoryName] = firebaseMapLower[lower]!;
          }
        }
        // add any new categories from firebase
        firebaseMapLower.forEach((lowerName, url) {
          if (!_categories.any((c) => c.toLowerCase() == lowerName)) {
            final cap = _capitalize(lowerName);
            _categories.add(cap);
            _categoryImageUrls[cap] = url;
          }
        });
      });

      // Listen to products stream and recalculate stocks whenever they change
      FirebaseService.streamListData('/products').listen(
        (products) {
          if (!mounted) return;
          _calculateCategoryStocks(products);
        },
        onError: (e) {
          print('Error streaming products: $e');
        },
      );
    } catch (e) {
      print('Error loading Firebase categories: $e');
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _extractImageUrl(Map<String, dynamic> cat) {
    // Common keys and nested shapes to check
    final candidates = ['imageUrl', 'image_url', 'image', 'url', 'src', 'path'];

    for (final key in candidates) {
      final val = cat[key];
      if (val == null) continue;
      if (val is String && val.isNotEmpty) return val;
      if (val is Map) {
        // try nested keys
        final nested =
            (val['url'] ?? val['imageUrl'] ?? val['src'] ?? val['path']);
        if (nested is String && nested.isNotEmpty) return nested;
      }
    }

    // Sometimes data is nested under 'image' as a list or map
    if (cat['image'] is List && (cat['image'] as List).isNotEmpty) {
      final first = (cat['image'] as List).first;
      if (first is String && first.isNotEmpty) return first;
      if (first is Map) {
        final nested = (first['url'] ?? first['imageUrl'] ?? first['src']);
        if (nested is String && nested.isNotEmpty) return nested;
      }
    }

    return '';
  }
}

/// Widget that fetches images via FilebaseService (authenticated) and falls back
/// to `Image.network` if bytes aren't available (covers public and private files).
class _AuthenticatedCategoryImage extends StatelessWidget {
  final String imageUrl;
  final int? cacheWidth;
  final int? cacheHeight;

  const _AuthenticatedCategoryImage({
    required this.imageUrl,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const Center(
        child: Icon(Icons.image_outlined, color: Colors.grey, size: 32),
      );
    }

    return FutureBuilder<Uint8List?>(
      future: FilebaseService().getImageBytes(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Color(0xFFFDB022)),
              ),
            ),
          );
        }

        // If bytes are available (authenticated fetch), show them
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          );
        }

        // Else, fall back to Image.network (publicly accessible)
        return Image.network(
          imageUrl,
          fit: BoxFit.contain,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.image_outlined, color: Colors.grey, size: 32),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFDB022)),
              ),
            );
          },
        );
      },
    );
  }
}
