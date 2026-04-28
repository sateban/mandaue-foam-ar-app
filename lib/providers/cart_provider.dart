import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../services/firebase_service.dart';
import 'user_provider.dart';

class CartProvider extends ChangeNotifier {
  List<CartItem> _items = [];
  bool _isLoading = false;
  String? _error;
  UserProvider? _userProvider;

  void updateUser(UserProvider userProvider) {
    if (_userProvider?.userId != userProvider.userId) {
      print(
        'CartProvider: User changed from ${_userProvider?.userId} to ${userProvider.userId}',
      );
      _userProvider = userProvider;
      loadCart();
    } else {
      _userProvider = userProvider;
    }
  }

  List<CartItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get itemCount => _items.length;
  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);

  String? get _userId {
    return _userProvider?.userId ?? 'guest_user';
  }

  String get _cartPath => '/carts/$_userId/items';

  double get subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

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

  Stream<List<CartItem>> get cartStream {
    if (_userId == null) {
      return Stream.value([]);
    }

    return FirebaseService.streamListData(_cartPath).map((cartData) {
      final items = cartData
          .map((item) => CartItem.fromJson(item['id'] as String, item))
          .toList();

      items.sort((a, b) => b.addedAt.compareTo(a.addedAt));

      _items = items;
      return items;
    });
  }

  Future<void> addToCart({
    required Product product,
    int quantity = 1,
    String? colorOverride,
    String? imageUrlOverride,
  }) async {
    if (_userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final selectedColor = colorOverride ?? product.color;
      final selectedImageUrl = imageUrlOverride ?? product.imageUrl;

      final existingIndex = _items.indexWhere(
        (item) => item.productId == product.id && item.color == selectedColor,
      );

      if (existingIndex != -1) {
        await updateQuantity(
          _items[existingIndex].id,
          _items[existingIndex].quantity + quantity,
        );
      } else {
        final now = DateTime.now();
        final newItem = CartItem(
          id: '', 
          productId: product.id,
          name: product.name,
          color: selectedColor,
          price: product.price,
          quantity: quantity,
          imageUrl: selectedImageUrl,
          addedAt: now,
          updatedAt: now,
        );

        final dbRef = FirebaseService.getDatabase().ref(_cartPath);
        final newItemRef = dbRef.push();

        await newItemRef.set(newItem.toJson());

        print(
          'CartProvider: Added ${product.name} to cart (quantity: $quantity)',
        );

        await loadCart();
      }
    } catch (e) {
      print('CartProvider: Error adding to cart: $e');
      throw Exception('Failed to add to cart: $e');
    }
  }

  Future<void> updateQuantity(String itemId, int newQuantity) async {
    if (_userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      if (newQuantity <= 0) {
        await removeItem(itemId);
        return;
      }

      final itemPath = '$_cartPath/$itemId';
      await FirebaseService.updateData(itemPath, {
        'quantity': newQuantity,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      print('CartProvider: Updated quantity for item $itemId to $newQuantity');

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

  Future<void> removeItem(String itemId) async {
    if (_userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final itemPath = '$_cartPath/$itemId';
      await FirebaseService.deleteData(itemPath);

      print('CartProvider: Removed item $itemId from cart');

      _items.removeWhere((item) => item.id == itemId);
      notifyListeners();
    } catch (e) {
      print('CartProvider: Error removing item: $e');
      throw Exception('Failed to remove item: $e');
    }
  }

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

  CartItem? getItemByProductId(String productId) {
    try {
      return _items.firstWhere((item) => item.productId == productId);
    } catch (e) {
      return null;
    }
  }

  bool isInCart(String productId) {
    return _items.any((item) => item.productId == productId);
  }

  int getProductQuantity(String productId) {
    final item = getItemByProductId(productId);
    return item?.quantity ?? 0;
  }
}
