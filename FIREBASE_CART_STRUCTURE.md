# Firebase Cart System Documentation

## Overview
This document describes the Firebase Realtime Database structure and implementation for the shopping cart system in the Mandaue Foam AR application.

## Firebase Database Structure

### Cart Data Organization

```
/carts
  /{userId}
    /items
      /{cartItemId}
        - productId: string
        - name: string
        - color: string
        - price: number
        - quantity: number
        - imageUrl: string
        - addedAt: ISO8601 timestamp
        - updatedAt: ISO8601 timestamp
```

### Example Data

```json
{
  "carts": {
    "guest_user": {
      "items": {
        "-NxAbCdEfGhIjKlMnOpQ": {
          "productId": "prod_001",
          "name": "Modern Sofa",
          "color": "Gray",
          "price": 899.99,
          "quantity": 1,
          "imageUrl": "https://filebase.example.com/products/sofa.jpg",
          "addedAt": "2026-02-07T14:30:00.000Z",
          "updatedAt": "2026-02-07T14:30:00.000Z"
        },
        "-NxAbCdEfGhIjKlMnOpR": {
          "productId": "prod_002",
          "name": "Dining Table",
          "color": "Brown",
          "price": 599.99,
          "quantity": 2,
          "imageUrl": "https://filebase.example.com/products/table.jpg",
          "addedAt": "2026-02-07T14:35:00.000Z",
          "updatedAt": "2026-02-07T14:40:00.000Z"
        }
      }
    },
    "user_abc123": {
      "items": {
        "-NxAbCdEfGhIjKlMnOpS": {
          "productId": "prod_003",
          "name": "Office Chair",
          "color": "Black",
          "price": 299.99,
          "quantity": 1,
          "imageUrl": "https://filebase.example.com/products/chair.jpg",
          "addedAt": "2026-02-07T15:00:00.000Z",
          "updatedAt": "2026-02-07T15:00:00.000Z"
        }
      }
    }
  }
}
```

## Design Decisions

### 1. User-Specific Cart Paths
**Path Pattern:** `/carts/{userId}/items`

**Rationale:**
- Each user has their own isolated cart
- Prevents cart conflicts between users
- Easy to query and manage per-user data
- Supports both authenticated users (Firebase Auth UID) and guest users (default ID)

### 2. Firebase Push Keys for Cart Items
**Implementation:** Using `DatabaseReference.push()` to generate unique IDs

**Rationale:**
- Automatic unique ID generation
- Chronologically sortable (contains timestamp)
- No collision risk
- Simplifies concurrent cart operations

### 3. Denormalized Product Data
**Approach:** Store product details (name, price, color, imageUrl) directly in cart items

**Rationale:**
- **Performance:** No need for additional product lookups when displaying cart
- **Price Consistency:** Preserves the price at the time of adding to cart
- **Offline Support:** Cart can be displayed without fetching product data
- **Historical Accuracy:** If product details change, cart items remain unchanged

**Trade-off:** Slight data duplication, but acceptable for cart use case

### 4. Timestamps (addedAt, updatedAt)
**Format:** ISO8601 strings

**Rationale:**
- Easy to parse and display
- Sortable for "recently added" features
- Audit trail for cart modifications
- Helps with cart expiration logic (future feature)

## Implementation Details

### CartProvider Class
Located in: `lib/providers/cart_provider.dart`

**Key Methods:**
- `loadCart()` - Load cart items from Firebase
- `cartStream` - Real-time stream of cart updates
- `addToCart()` - Add product to cart (or update quantity if exists)
- `updateQuantity()` - Update item quantity
- `removeItem()` - Remove item from cart
- `clearCart()` - Clear entire cart

### CartItem Model
Located in: `lib/models/cart_item.dart`

**Features:**
- JSON serialization/deserialization
- `copyWith()` method for immutable updates
- `totalPrice` computed property

### Integration Points

#### 1. Product Detail Screen
**File:** `lib/screens/shop/product_detail_screen.dart`

**Implementation:**
```dart
Consumer<CartProvider>(
  builder: (context, cartProvider, child) {
    return ElevatedButton(
      onPressed: () async {
        await cartProvider.addToCart(
          product: widget.product,
          quantity: _quantity,
        );
      },
      child: const Text('Add to Cart'),
    );
  },
)
```

#### 2. Cart Screen
**File:** `lib/screens/shop/cart_screen.dart`

**Implementation:**
```dart
Consumer<CartProvider>(
  builder: (context, cartProvider, child) {
    if (cartProvider.isLoading) {
      return CircularProgressIndicator();
    }
    
    return ListView.builder(
      itemCount: cartProvider.items.length,
      itemBuilder: (context, index) {
        return CartItemWidget(cartProvider.items[index]);
      },
    );
  },
)
```

## Firebase Security Rules (Recommended)

```json
{
  "rules": {
    "carts": {
      "$userId": {
        ".read": "auth != null && auth.uid == $userId || $userId == 'guest_user'",
        ".write": "auth != null && auth.uid == $userId || $userId == 'guest_user'",
        "items": {
          "$itemId": {
            ".validate": "newData.hasChildren(['productId', 'name', 'color', 'price', 'quantity', 'imageUrl', 'addedAt', 'updatedAt'])",
            "productId": {
              ".validate": "newData.isString()"
            },
            "name": {
              ".validate": "newData.isString()"
            },
            "color": {
              ".validate": "newData.isString()"
            },
            "price": {
              ".validate": "newData.isNumber() && newData.val() >= 0"
            },
            "quantity": {
              ".validate": "newData.isNumber() && newData.val() > 0"
            },
            "imageUrl": {
              ".validate": "newData.isString()"
            },
            "addedAt": {
              ".validate": "newData.isString()"
            },
            "updatedAt": {
              ".validate": "newData.isString()"
            }
          }
        }
      }
    }
  }
}
```

## Best Practices

### 1. Error Handling
Always wrap Firebase operations in try-catch blocks:

```dart
try {
  await cartProvider.addToCart(product: product, quantity: 1);
} catch (e) {
  // Show error to user
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

### 2. Loading States
Show loading indicators during Firebase operations:

```dart
if (cartProvider.isLoading) {
  return CircularProgressIndicator();
}
```

### 3. Optimistic Updates
Update local state immediately, then sync with Firebase:

```dart
// Local update happens first (in CartProvider)
_items[index] = _items[index].copyWith(quantity: newQuantity);
notifyListeners();

// Then sync to Firebase
await FirebaseService.updateData(itemPath, {'quantity': newQuantity});
```

### 4. Real-time Sync
Use streams for real-time cart updates across devices:

```dart
StreamBuilder<List<CartItem>>(
  stream: cartProvider.cartStream,
  builder: (context, snapshot) {
    // UI updates automatically when cart changes
  },
)
```

## Future Enhancements

1. **Cart Expiration**
   - Automatically remove items after X days
   - Use `addedAt` timestamp for expiration logic

2. **Cart Merging**
   - Merge guest cart with user cart on login
   - Combine quantities for duplicate products

3. **Save for Later**
   - Move items to a separate "saved" collection
   - Path: `/carts/{userId}/saved/{itemId}`

4. **Cart Analytics**
   - Track abandoned carts
   - Monitor add-to-cart conversion rates
   - Use timestamps for analytics

5. **Multi-device Sync**
   - Already supported via Firebase Realtime Database
   - Cart automatically syncs across all user devices

## Testing

### Manual Testing Steps

1. **Add to Cart**
   - Open product detail screen
   - Select quantity
   - Click "Add to Cart"
   - Verify item appears in cart screen
   - Check Firebase console for new cart item

2. **Update Quantity**
   - Open cart screen
   - Increase/decrease quantity
   - Verify Firebase updates in real-time

3. **Remove Item**
   - Click delete button on cart item
   - Verify item removed from UI and Firebase

4. **Guest User Flow**
   - Use app without logging in
   - Add items to cart
   - Verify cart persists using 'guest_user' ID

5. **Authenticated User Flow**
   - Log in with Firebase Auth
   - Add items to cart
   - Verify cart uses user's UID

## Troubleshooting

### Cart Not Loading
- Check Firebase connection
- Verify user authentication state
- Check console for error messages
- Ensure Firebase rules allow read access

### Items Not Adding
- Verify product model has all required fields
- Check CartProvider error messages
- Ensure Firebase rules allow write access
- Verify network connectivity

### Duplicate Items
- Check `addToCart()` logic for existing item detection
- Verify `productId` matching is working correctly

## Performance Considerations

1. **Pagination:** Not needed for cart (typically < 50 items)
2. **Caching:** CartProvider maintains local state to reduce reads
3. **Batch Operations:** Consider batching multiple updates
4. **Indexes:** Not required for current cart structure

## Conclusion

This cart system provides a robust, scalable solution with:
- ✅ Real-time synchronization
- ✅ User-specific data isolation
- ✅ Proper error handling
- ✅ Offline-first approach (with local state)
- ✅ Easy to extend and maintain
