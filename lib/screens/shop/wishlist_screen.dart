import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../utils/slide_route.dart';
import '../../widgets/authenticated_image.dart';
import 'product_detail_screen.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A8A)),
        //   onPressed: () => Navigator.pop(context),
        // ),
        title: const Text(
          'Favorites',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFFDB022)),
              ),
            );
          }

          // Read live favorite products from provider — no local copy
          final favoriteProducts = provider.favoriteProducts
              .map<Product>((map) => Product.fromMap(map))
              .toList();

          if (favoriteProducts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'No items in your favorites yet.\nTap the heart icon on a product to add it here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            itemCount: favoriteProducts.length,
            itemBuilder: (context, index) {
              final product = favoriteProducts[index];
              return _buildWishlistItem(context, provider, product);
            },
          );
        },
      ),
    );
  }

  Widget _buildWishlistItem(
    BuildContext context,
    ProductProvider provider,
    Product product,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(
                  context,
                ).push(slideRoute(ProductDetailScreen(product: product)));
              },
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
                              '₱${product.price.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (Match m) => '${m[1]},')}',
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
                ],
              ),
            ),
          ),
          // Heart button — reads live isFavorite from provider
          GestureDetector(
            onTap: () {
              provider.toggleProductFavorite(product.id).catchError((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to update favorites'),
                    duration: Duration(seconds: 2),
                  ),
                );
              });
            },
            child: Icon(
              // provider.isFavorite always returns the live truth
              provider.isFavorite(product.id)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: provider.isFavorite(product.id) ? Colors.red : Colors.grey,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
