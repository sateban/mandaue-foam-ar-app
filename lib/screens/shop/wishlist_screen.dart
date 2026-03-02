import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../utils/slide_route.dart';
import '../../widgets/authenticated_image.dart';
import 'product_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Product> _favoriteProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Keep wishlist in sync with global favorites
    context.read<ProductProvider>().addListener(_onProductProviderUpdate);
    _loadWishlist();
  }

  @override
  void dispose() {
    try {
      context.read<ProductProvider>().removeListener(_onProductProviderUpdate);
    } catch (_) {}
    super.dispose();
  }

  void _onProductProviderUpdate() {
    if (!mounted) return;
    final provider = context.read<ProductProvider>();
    final products = provider.products
        .where((p) => p['isFavorite'] == true)
        .map<Product>((map) => Product.fromMap(map))
        .toList();

    setState(() {
      _favoriteProducts = products;
    });
  }

  Future<void> _loadWishlist() async {
    try {
      final provider = context.read<ProductProvider>();
      await provider.loadUserFavorites();

      final products = provider.products
          .where((p) => p['isFavorite'] == true)
          .map<Product>((map) => Product.fromMap(map))
          .toList();

      if (!mounted) return;
      setState(() {
        _favoriteProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _favoriteProducts = [];
        _isLoading = false;
      });
      // Best-effort toast, keep UX graceful
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading wishlist: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A8A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Wishlist',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFFFDB022)),
        ),
      );
    }

    if (_favoriteProducts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            'No items in your wishlist yet.\nTap the heart icon on a product to add it here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1E3A8A),
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: _favoriteProducts.length,
      itemBuilder: (context, index) {
        final product = _favoriteProducts[index];
        return _buildWishlistItem(product);
      },
    );
  }

  Widget _buildWishlistItem(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AuthenticatedImage(imageUrl: product.imageUrl),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(
                  context,
                ).push(slideRoute(ProductDetailScreen(product: product)));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
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
                        '₱${product.price.toStringAsFixed(2).replaceAllMapped(
                              RegExp(r'(\\d)(?=(\\d{3})+\\.)'),
                              (Match m) => '${m[1]},',
                            )}',
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
                            '${product.rating}',
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
          ),
          GestureDetector(
            onTap: () {
              try {
                final productProvider = context.read<ProductProvider>();
                final wasFavorite = product.isFavorite;

                // Optimistic update - update UI immediately
                setState(() {
                  product.isFavorite = !wasFavorite;
                  if (!product.isFavorite) {
                    _favoriteProducts =
                        _favoriteProducts.where((p) => p.id != product.id).toList();
                  }
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        product.isFavorite
                            ? 'Added to favorites'
                            : 'Removed from favorites',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }

                // Update Firebase in background without awaiting
                productProvider.toggleProductFavorite(product.id).catchError((e) {
                  // Rollback on error
                  if (!mounted) return;
                  setState(() {
                    product.isFavorite = wasFavorite;
                    _loadWishlist();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to update favorites'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                });
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please sign in to manage favorites'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: Icon(
              product.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: product.isFavorite ? Colors.red : Colors.grey,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

