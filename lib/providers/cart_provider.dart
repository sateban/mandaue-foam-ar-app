import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../services/firebase_service.dart';

/// Cart Provider with Firebase Realtime Database integration
///
/// Firebase Structure:
/// /carts/{userId}/items/{cartItemId}
///   - productId: string
///   - name: string
///   - color: string
///   - price: number
///   - quantity: number
///   - imageUrl: string
///   - addedAt: ISO8601 timestamp
///   - updatedAt: ISO8601 timestamp
class CartProvider extends ChangeNotifier {
  List<CartItem> _items = [];
  bool _isLoading = false;
  String? _error;

  List<CartItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get itemCount => _items.length;
  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);

  /// Get current user ID from Firebase Auth
  String? get _userId {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return user.uid;
    }
    // For testing/development: use a default user ID if not authenticated
    return 'guest_user';
  }

  /// Get the cart path for the current user
  String get _cartPath => '/carts/$_userId/items';

  /// Calculate subtotal
  double get subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  /// Load cart items from Firebase
  Future<void> loadCart() async {
    if (_userId == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('CartProvider: Loading cart from Firebase for user: $_userId');
      final cartData = await FirebaseService.readListData(_cartPath);

      _items = cartData
          .map((item) => CartItem.fromJson(item['id'] as String, item))
          .toList();

      // Sort by most recently added
      _items.sort((a, b) => b.addedAt.compareTo(a.addedAt));

      print('CartProvider: Successfully loaded ${_items.length} cart items');
      _error = null;
    } catch (e) {
      print('CartProvider: Error loading cart: $e');
      _error = 'Failed to load cart: $e';
      _items = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Stream cart items in real-time
  Stream<List<CartItem>> get cartStream {
    if (_userId == null) {
      return Stream.value([]);
    }

    return FirebaseService.streamListData(_cartPath).map((cartData) {
      final items = cartData
          .map((item) => CartItem.fromJson(item['id'] as String, item))
          .toList();

      // Sort by most recently added
      items.sort((a, b) => b.addedAt.compareTo(a.addedAt));

      // Update local state
      _items = items;
      return items;
    });
  }

  /// Add item to cart
  Future<void> addToCart({required Product product, int quantity = 1}) async {
    if (_userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if product already exists in cart
      final existingIndex = _items.indexWhere(
        (item) => item.productId == product.id,
      );

      if (existingIndex != -1) {
        // Update quantity of existing item
        await updateQuantity(
          _items[existingIndex].id,
          _items[existingIndex].quantity + quantity,
        );
      } else {
        // Add new item to cart
        final now = DateTime.now();
        final newItem = CartItem(
          id: '', // Firebase will generate the ID
          productId: product.id,
          name: product.name,
          color: product.color,
          price: product.price,
          quantity: quantity,
          imageUrl: product.imageUrl,
          addedAt: now,
          updatedAt: now,
        );

        // Push to Firebase (generates unique key)
        final dbRef = FirebaseService.getDatabase().ref(_cartPath);
        final newItemRef = dbRef.push();

        await newItemRef.set(newItem.toJson());

        print(
          'CartProvider: Added ${product.name} to cart (quantity: $quantity)',
        );

        // Reload cart to get the new item with Firebase-generated ID
        await loadCart();
      }
    } catch (e) {
      print('CartProvider: Error adding to cart: $e');
      throw Exception('Failed to add to cart: $e');
    }
  }

  /// Update item quantity
  Future<void> updateQuantity(String itemId, int newQuantity) async {
    if (_userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      if (newQuantity <= 0) {
        // Remove item if quantity is 0 or less
        await removeItem(itemId);
        return;
      }

      final itemPath = '$_cartPath/$itemId';
      await FirebaseService.updateData(itemPath, {
        'quantity': newQuantity,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      print('CartProvider: Updated quantity for item $itemId to $newQuantity');

      // Update local state
      final index = _items.indexWhere((item) => item.id == itemId);
      if (index != -1) {
        _items[index] = _items[index].copyWith(
          quantity: newQuantity,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      print('CartProvider: Error updating quantity: $e');
      throw Exception('Failed to update quantity: $e');
    }
  }

  /// Remove item from cart
  Future<void> removeItem(String itemId) async {
    if (_userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final itemPath = '$_cartPath/$itemId';
      await FirebaseService.deleteData(itemPath);

      print('CartProvider: Removed item $itemId from cart');

      // Update local state
      _items.removeWhere((item) => item.id == itemId);
      notifyListeners();
    } catch (e) {
      print('CartProvider: Error removing item: $e');
      throw Exception('Failed to remove item: $e');
    }
  }

  /// Clear entire cart
  Future<void> clearCart() async {
    if (_userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await FirebaseService.deleteData(_cartPath);

      print('CartProvider: Cleared cart for user $_userId');

      _items = [];
      notifyListeners();
    } catch (e) {
      print('CartProvider: Error clearing cart: $e');
      throw Exception('Failed to clear cart: $e');
    }
  }

  /// Get item by product ID
  CartItem? getItemByProductId(String productId) {
    try {
      return _items.firstWhere((item) => item.productId == productId);
    } catch (e) {
      return null;
    }
  }

  /// Check if product is in cart
  bool isInCart(String productId) {
    return _items.any((item) => item.productId == productId);
  }

  /// Get quantity of a specific product in cart
  int getProductQuantity(String productId) {
    final item = getItemByProductId(productId);
    return item?.quantity ?? 0;
  }
}
