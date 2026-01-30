import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';
import '../services/filebase_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load products from Firebase Realtime Database
  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('ProductProvider: Loading products from Firebase...');
      final loadedProducts = await FirebaseService.readListData('/products');
      
      // Transform Firebase paths to full Filebase URLs
      final filebaseService = FilebaseService();
      _products = filebaseService.transformProductsWithFilebaseUrls(loadedProducts);
      
      print('ProductProvider: Successfully loaded ${_products.length} products');
      _error = null;
    } catch (e) {
      print('ProductProvider: Error loading products: $e');
      _error = 'Failed to load products: $e';
      _products = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Stream products from Firebase Realtime Database
  Stream<List<Map<String, dynamic>>> get productStream {
    return FirebaseService.streamListData('/products');
  }

  /// Get product by ID
  Map<String, dynamic>? getProductById(String productId) {
    try {
      return _products.firstWhere((product) => product['id'] == productId);
    } catch (e) {
      return null;
    }
  }

  /// Filter products by category
  List<Map<String, dynamic>> getProductsByCategory(String category) {
    return _products
        .where((product) => product['category']?.toString().toLowerCase() == category.toLowerCase())
        .toList();
  }

  /// Search products by name
  List<Map<String, dynamic>> searchProducts(String query) {
    final lowerQuery = query.toLowerCase();
    return _products
        .where((product) =>
            product['name']?.toString().toLowerCase().contains(lowerQuery) ?? false)
        .toList();
  }

  /// Clear products
  void clearProducts() {
    _products = [];
    _error = null;
    notifyListeners();
  }
}
