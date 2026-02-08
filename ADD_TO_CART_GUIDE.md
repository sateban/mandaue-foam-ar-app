# Quick Guide: Adding "Add to Cart" to Any Screen

This guide shows how to add cart functionality to product cards in any screen.

## Prerequisites

1. Import necessary packages:
```dart
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../models/product.dart';
```

## Option 1: Quick Add Button (Product Cards)

### Simple Icon Button
```dart
Widget buildProductCard(Map<String, dynamic> productData) {
  return Card(
    child: Column(
      children: [
        // Product image, name, price, etc.
        
        // Add to Cart Button
        Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            return IconButton(
              icon: const Icon(Icons.add_shopping_cart),
              onPressed: () async {
                try {
                  // Convert Map to Product object
                  final product = Product(
                    id: productData['id']?.toString() ?? '',
                    name: productData['name'] ?? '',
                    price: (productData['price'] as num?)?.toDouble() ?? 0.0,
                    category: productData['category'] ?? '',
                    material: productData['material'] ?? '',
                    color: productData['color'] ?? '',
                    imageUrl: productData['imageUrl'] ?? '',
                    rating: (productData['rating'] as num?)?.toDouble() ?? 0.0,
                    reviews: (productData['reviews'] as num?)?.toInt() ?? 0,
                    isFavorite: productData['isFavorite'] ?? false,
                    discount: productData['discount'],
                    description: productData['description'],
                    quantity: productData['quantity'] as int?,
                    inStock: productData['inStock'] ?? true,
                    modelUrl: productData['modelUrl'],
                    modelScale: (productData['modelScale'] as num?)?.toDouble(),
                  );

                  await cartProvider.addToCart(
                    product: product,
                    quantity: 1, // Default quantity
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product.name} added to cart'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                        action: SnackBarAction(
                          label: 'View Cart',
                          textColor: Colors.white,
                          onPressed: () {
                            Navigator.pushNamed(context, '/cart');
                          },
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            );
          },
        ),
      ],
    ),
  );
}
```

## Option 2: Full Button with Quantity Selector

### With Quantity Selection
```dart
class ProductCardWithQuantity extends StatefulWidget {
  final Map<String, dynamic> productData;
  
  const ProductCardWithQuantity({required this.productData, super.key});

  @override
  State<ProductCardWithQuantity> createState() => _ProductCardWithQuantityState();
}

class _ProductCardWithQuantityState extends State<ProductCardWithQuantity> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // Product details...
          
          // Quantity Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
              ),
              Text('$_quantity', style: const TextStyle(fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => _quantity++),
              ),
            ],
          ),
          
          // Add to Cart Button
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              return ElevatedButton(
                onPressed: () async {
                  try {
                    final product = _convertToProduct(widget.productData);
                    
                    await cartProvider.addToCart(
                      product: product,
                      quantity: _quantity,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '$_quantity ${product.name}(s) added to cart',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                      setState(() => _quantity = 1); // Reset quantity
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Add to Cart'),
              );
            },
          ),
        ],
      ),
    );
  }

  Product _convertToProduct(Map<String, dynamic> data) {
    return Product(
      id: data['id']?.toString() ?? '',
      name: data['name'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] ?? '',
      material: data['material'] ?? '',
      color: data['color'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: (data['reviews'] as num?)?.toInt() ?? 0,
      isFavorite: data['isFavorite'] ?? false,
      discount: data['discount'],
      description: data['description'],
      quantity: data['quantity'] as int?,
      inStock: data['inStock'] ?? true,
      modelUrl: data['modelUrl'],
      modelScale: (data['modelScale'] as num?)?.toDouble(),
    );
  }
}
```

## Option 3: Floating Add Button (Product Detail Style)

### Positioned at Bottom
```dart
Stack(
  children: [
    // Main content
    SingleChildScrollView(
      child: Column(
        children: [
          // Product details
        ],
      ),
    ),
    
    // Floating Add to Cart Button
    Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            return ElevatedButton(
              onPressed: () async {
                // Add to cart logic
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6200EE),
                minimumSize: const Size(double.infinity, 56),
              ),
              child: const Text('Add to Cart'),
            );
          },
        ),
      ),
    ),
  ],
)
```

## Option 4: Cart Badge (Show Item Count)

### Display cart item count on cart icon
```dart
Consumer<CartProvider>(
  builder: (context, cartProvider, child) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart),
          onPressed: () {
            Navigator.pushNamed(context, '/cart');
          },
        ),
        if (cartProvider.itemCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                '${cartProvider.itemCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  },
)
```

## Helper Function: Convert Map to Product

Create a reusable helper function:

```dart
// lib/utils/product_helpers.dart
import '../models/product.dart';

class ProductHelpers {
  static Product fromMap(Map<String, dynamic> data) {
    return Product(
      id: data['id']?.toString() ?? '',
      name: data['name'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] ?? '',
      material: data['material'] ?? '',
      color: data['color'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: (data['reviews'] as num?)?.toInt() ?? 0,
      isFavorite: data['isFavorite'] ?? false,
      discount: data['discount'],
      description: data['description'],
      quantity: data['quantity'] as int?,
      inStock: data['inStock'] ?? true,
      modelUrl: data['modelUrl'],
      modelScale: (data['modelScale'] as num?)?.toDouble(),
    );
  }
}

// Usage:
final product = ProductHelpers.fromMap(productData);
await cartProvider.addToCart(product: product, quantity: 1);
```

## Best Practices

### 1. Always Check Context Mounted
```dart
if (context.mounted) {
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```

### 2. Handle Errors Gracefully
```dart
try {
  await cartProvider.addToCart(...);
} catch (e) {
  // Show error to user
}
```

### 3. Provide User Feedback
```dart
// Success
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Added to cart'),
    backgroundColor: Colors.green,
    action: SnackBarAction(
      label: 'View Cart',
      onPressed: () => Navigator.pushNamed(context, '/cart'),
    ),
  ),
);
```

### 4. Use Consumer for Reactive UI
```dart
Consumer<CartProvider>(
  builder: (context, cartProvider, child) {
    // UI updates automatically when cart changes
    return YourWidget();
  },
)
```

## Common Patterns

### Check if Product is in Cart
```dart
Consumer<CartProvider>(
  builder: (context, cartProvider, child) {
    final isInCart = cartProvider.isInCart(productId);
    
    return ElevatedButton(
      onPressed: () { /* ... */ },
      child: Text(isInCart ? 'Update Cart' : 'Add to Cart'),
    );
  },
)
```

### Show Current Quantity in Cart
```dart
Consumer<CartProvider>(
  builder: (context, cartProvider, child) {
    final quantity = cartProvider.getProductQuantity(productId);
    
    if (quantity > 0) {
      return Text('In cart: $quantity');
    }
    return const SizedBox.shrink();
  },
)
```

## Testing Your Implementation

1. **Add to cart** - Verify item appears in cart screen
2. **Check Firebase** - Verify data is saved to `/carts/{userId}/items`
3. **Add same product twice** - Verify quantity increases
4. **Error handling** - Test with network disconnected
5. **Loading states** - Verify UI shows loading during operations

## Troubleshooting

### "CartProvider not found"
- Ensure you've added `CartProvider` to `MultiProvider` in `main.dart`
- Import: `import '../../providers/cart_provider.dart';`

### "Product not added to cart"
- Check Firebase console for errors
- Verify user authentication state
- Check network connectivity
- Look for console error messages

### "Cart not updating"
- Ensure you're using `Consumer<CartProvider>`
- Check that `notifyListeners()` is called in provider
- Verify Firebase rules allow write access

## Next Steps

After adding "Add to Cart" to your screen:
1. Test the functionality
2. Verify Firebase data structure
3. Check error handling
4. Test with different user states (guest/authenticated)
5. Verify cart badge updates (if implemented)

For more details, see:
- `CART_IMPLEMENTATION_SUMMARY.md` - Full implementation details
- `FIREBASE_CART_STRUCTURE.md` - Database structure and best practices
