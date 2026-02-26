import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/firebase_service.dart';
import '../services/filebase_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<Map<String, dynamic>>>? _productsSubscription;
  bool _isListeningToRealtime = false;

  List<Map<String, dynamic>> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load products from Firebase Realtime Database with real-time listening
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

    // Start listening to real-time updates if not already listening
    _startRealtimeListener();
  }

  /// Start listening to real-time product updates
  void _startRealtimeListener() {
    if (_isListeningToRealtime) return;
    
    _isListeningToRealtime = true;
    print('ProductProvider: Starting real-time listener for products...');
    
    _productsSubscription = FirebaseService.streamListData('/products').listen(
      (productsList) {
        if (productsList.isEmpty) {
          print('ProductProvider: Received empty product list');
          return;
        }

        // Transform Firebase paths to full Filebase URLs
        final filebaseService = FilebaseService();
        final updatedProducts = filebaseService.transformProductsWithFilebaseUrls(productsList);
        
        // Check if products actually changed to avoid unnecessary rebuilds
        if (_hasProductsChanged(updatedProducts)) {
          _products = updatedProducts;
          print('ProductProvider: Updated ${_products.length} products from real-time stream');
          notifyListeners();
        }
      },
      onError: (error) {
        print('ProductProvider: Error in real-time listener: $error');
        _error = 'Real-time update error: $error';
        _isListeningToRealtime = false;
        notifyListeners();
      },
    );
  }

  /// Check if products have changed
  bool _hasProductsChanged(List<Map<String, dynamic>> newProducts) {
    if (newProducts.length != _products.length) return true;
    
    // Compare products
    for (int i = 0; i < newProducts.length; i++) {
      final newProduct = newProducts[i];
      final oldProduct = _products[i];
      
      // Check if critical fields changed (stock, price, etc.)
      if (newProduct['id'] != oldProduct['id'] ||
          newProduct['stock'] != oldProduct['stock'] ||
          newProduct['price'] != oldProduct['price']) {
        return true;
      }
    }
    
    return false;
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

  /// Dispose and clean up resources
  @override
  void dispose() {
    _productsSubscription?.cancel();
    _isListeningToRealtime = false;
    super.dispose();
  }
}
