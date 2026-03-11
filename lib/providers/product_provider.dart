import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/firebase_service.dart';
import '../services/filebase_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _products = [];
  Set<String> _favoriteIds = {};
  bool _isLoading = false;
  String? _error;

  // Single subscription for products stream
  StreamSubscription<List<Map<String, dynamic>>>? _productsSubscription;
  // Single subscription for favorites stream
  StreamSubscription<List<String>>? _favoritesSubscription;

  List<Map<String, dynamic>> get products => _products;

  /// Returns only the favorited products
  List<Map<String, dynamic>> get favoriteProducts =>
      _products.where((p) => _favoriteIds.contains(p['id']?.toString() ?? '')).toList();

  bool get isLoading => _isLoading;
  String? get error => _error;
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  /// Called once on app start. Loads products + favorites, then starts real-time listeners.
  Future<void> loadProducts() async {
    if (_isLoading) return; // Guard against concurrent loads
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('ProductProvider: Starting initial load...');

      // Step 1 – Load favorite IDs for current user (one-shot read)
      final user = FirebaseService.getCurrentUser();
      if (user != null) {
        final ids = await FirebaseService.getFavoriteProductIds(user.uid);
        _favoriteIds = ids.toSet();
        print('ProductProvider: Loaded ${_favoriteIds.length} favorite IDs');

        // Step 2 – Start favourites real-time listener ONCE
        _startFavoritesListener(user.uid);
      }

      // Step 3 – One-shot read for products (fast initial paint)
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

    // Step 4 – Start products real-time listener ONCE
    _startProductsListener();
  }

  // ─── Private: real-time listeners ─────────────────────────────────────────

  void _startProductsListener() {
    if (_productsSubscription != null) return; // Already listening

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
    // Cancel any existing subscription before creating a new one
    _favoritesSubscription?.cancel();
    _favoritesSubscription = null;

    print('ProductProvider: Starting favourites real-time listener for $userId...');
    _favoritesSubscription = FirebaseService.streamFavoriteProductIds(userId).listen(
      (ids) {
        final newSet = ids.toSet();
        if (newSet.length == _favoriteIds.length && newSet.containsAll(_favoriteIds)) {
          // No actual change – skip notify to avoid spurious rebuilds
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

  // ─── Favorite helpers ──────────────────────────────────────────────────────

  void _applyFavoritesToProducts() => _applyFavoritesToList(_products);

  void _applyFavoritesToList(List<Map<String, dynamic>> list) {
    for (final p in list) {
      p['isFavorite'] = _favoriteIds.contains(p['id']?.toString() ?? '');
    }
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Toggle a product's favourite status.
  /// Does an optimistic local update immediately, then syncs to Firebase.
  /// The real-time favourites stream will re-confirm the final state.
  Future<void> toggleProductFavorite(String productId) async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) throw Exception('User not authenticated');

    // -- Optimistic update --
    final wasFavorite = _favoriteIds.contains(productId);
    if (wasFavorite) {
      _favoriteIds.remove(productId);
    } else {
      _favoriteIds.add(productId);
    }
    _applyFavoritesToProducts();
    notifyListeners(); // <-- ONE notify, reflecting optimistic state

    try {
      // Sync to Firebase (the favourites stream will fire afterwards and confirm)
      await FirebaseService.toggleFavorite(user.uid, productId);
      print('ProductProvider: Toggled favourite for $productId → ${!wasFavorite}');
    } catch (e) {
      print('ProductProvider: Error toggling favourite – rolling back: $e');
      // Rollback
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

  /// Returns the live product map for a given id (with up-to-date isFavorite).
  Map<String, dynamic>? getProductById(String productId) {
    try {
      return _products.firstWhere((p) => p['id']?.toString() == productId);
    } catch (_) {
      return null;
    }
  }

  /// Whether a product id is currently favourited.
  bool isFavorite(String productId) => _favoriteIds.contains(productId);

  /// Reload favourites from Firebase (e.g. after sign-in).
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

      // Re-attach listener in case user just signed in
      _startFavoritesListener(user.uid);

      notifyListeners();
      print('ProductProvider: loadUserFavorites – ${_favoriteIds.length} IDs');
    } catch (e) {
      print('ProductProvider: Error loading user favourites: $e');
    }
  }

  /// Called when the user signs out.
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

  /// Used by HomeScreen stream to push transformed products.
  /// Kept for backward compat but ProductProvider now owns the stream itself.
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
