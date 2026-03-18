import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/firebase_service.dart';
import '../services/filebase_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _products = [];
  Set<String> _favoriteIds = {};
  bool _isLoading = false;
  String? _error;

  StreamSubscription<List<Map<String, dynamic>>>? _productsSubscription;
  StreamSubscription<List<String>>? _favoritesSubscription;

  List<Map<String, dynamic>> get products => _products;

  List<Map<String, dynamic>> get favoriteProducts =>
      _products.where((p) => _favoriteIds.contains(p['id']?.toString() ?? '')).toList();

  bool get isLoading => _isLoading;
  String? get error => _error;
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  Future<void> loadProducts() async {
    if (_isLoading) return; 
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('ProductProvider: Starting initial load...');

      final user = FirebaseService.getCurrentUser();
      if (user != null) {
        final ids = await FirebaseService.getFavoriteProductIds(user.uid);
        _favoriteIds = ids.toSet();
        print('ProductProvider: Loaded ${_favoriteIds.length} favorite IDs');

        _startFavoritesListener(user.uid);
      }

      final rawProducts = await FirebaseService.readListData('/products');
      final filebaseService = FilebaseService();
      _products = filebaseService.transformProductsWithFilebaseUrls(rawProducts);
      _applyFavoritesToProducts();

      print('ProductProvider: Loaded ${_products.length} products');
    } catch (e) {
      print('ProductProvider: Error on initial load: $e');
      _error = 'Failed to load products: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    _startProductsListener();
  }

  void _startProductsListener() {
    if (_productsSubscription != null) return; 

    print('ProductProvider: Starting products real-time listener...');
    _productsSubscription = FirebaseService.streamListData('/products').listen(
      (rawList) {
        if (rawList.isEmpty) return;

        final filebaseService = FilebaseService();
        final updated = filebaseService.transformProductsWithFilebaseUrls(rawList);
        _applyFavoritesToList(updated);
        _products = updated;

        print('ProductProvider: Products stream update – ${_products.length} items');
        notifyListeners();
      },
      onError: (e) {
        print('ProductProvider: Products stream error: $e');
      },
    );
  }

  void _startFavoritesListener(String userId) {
    _favoritesSubscription?.cancel();
    _favoritesSubscription = null;

    print('ProductProvider: Starting favourites real-time listener for $userId...');
    _favoritesSubscription = FirebaseService.streamFavoriteProductIds(userId).listen(
      (ids) {
        final newSet = ids.toSet();
        if (newSet.length == _favoriteIds.length && newSet.containsAll(_favoriteIds)) {
          return;
        }
        _favoriteIds = newSet;
        _applyFavoritesToProducts();
        print('ProductProvider: Favourites stream update – ${_favoriteIds.length} favourites');
        notifyListeners();
      },
      onError: (e) {
        print('ProductProvider: Favourites stream error: $e');
      },
    );
  }

  void _applyFavoritesToProducts() => _applyFavoritesToList(_products);

  void _applyFavoritesToList(List<Map<String, dynamic>> list) {
    for (final p in list) {
      p['isFavorite'] = _favoriteIds.contains(p['id']?.toString() ?? '');
    }
  }

  Future<void> toggleProductFavorite(String productId) async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) throw Exception('User not authenticated');

    final wasFavorite = _favoriteIds.contains(productId);
    if (wasFavorite) {
      _favoriteIds.remove(productId);
    } else {
      _favoriteIds.add(productId);
    }
    _applyFavoritesToProducts();
    notifyListeners(); 

    try {
      await FirebaseService.toggleFavorite(user.uid, productId);
      print('ProductProvider: Toggled favourite for $productId → ${!wasFavorite}');
    } catch (e) {
      print('ProductProvider: Error toggling favourite – rolling back: $e');
      if (wasFavorite) {
        _favoriteIds.add(productId);
      } else {
        _favoriteIds.remove(productId);
      }
      _applyFavoritesToProducts();
      notifyListeners();
      rethrow;
    }
  }

  Map<String, dynamic>? getProductById(String productId) {
    try {
      return _products.firstWhere((p) => p['id']?.toString() == productId);
    } catch (_) {
      return null;
    }
  }

  bool isFavorite(String productId) => _favoriteIds.contains(productId);

  Future<void> loadUserFavorites() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) {
      _favoriteIds = {};
      _applyFavoritesToProducts();
      notifyListeners();
      return;
    }

    try {
      final ids = await FirebaseService.getFavoriteProductIds(user.uid);
      _favoriteIds = ids.toSet();
      _applyFavoritesToProducts();

      _startFavoritesListener(user.uid);

      notifyListeners();
      print('ProductProvider: loadUserFavorites – ${_favoriteIds.length} IDs');
    } catch (e) {
      print('ProductProvider: Error loading user favourites: $e');
    }
  }

  void clearProducts() {
    _products = [];
    _favoriteIds = {};
    _error = null;
    _productsSubscription?.cancel();
    _productsSubscription = null;
    _favoritesSubscription?.cancel();
    _favoritesSubscription = null;
    notifyListeners();
  }

  void updateProducts(List<Map<String, dynamic>> newProducts) {
    _applyFavoritesToList(newProducts);
    _products = newProducts;
    notifyListeners();
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _favoritesSubscription?.cancel();
    super.dispose();
  }
}
