import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../services/filebase_service.dart';
import '../../services/firebase_service.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../onboarding/ar_viewer_screen.dart';
import 'three_d_viewer_screen.dart';
import '../../widgets/authenticated_image.dart';
import '../../utils/color_utils.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isFavorite = false;
  int _quantity = 1;
  bool _isDownloadingModel = false;
  double _downloadProgress = 0.0;
  ProductVariation? _selectedVariation;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.product.isFavorite;
    final variations = widget.product.getAllVariations();
    if (variations.isNotEmpty) {
      _selectedVariation = variations.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A8A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: Colors.red,
            ),
            onPressed: () {
              try {
                final productProvider = context.read<ProductProvider>();
                final wasFavorite = _isFavorite;

                // Optimistic update - update UI immediately
                setState(() {
                  _isFavorite = !_isFavorite;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isFavorite
                          ? 'Added to favorites'
                          : 'Removed from favorites',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );

                // Update Firebase in background without awaiting
                productProvider
                    .toggleProductFavorite(widget.product.id)
                    .catchError((e) {
                      // Rollback on error
                      setState(() {
                        _isFavorite = wasFavorite;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to update favorites'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      print('Error toggling favorite: $e');
                    });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please sign in to add favorites'),
                    duration: Duration(seconds: 2),
                  ),
                );
                print('Error toggling favorite: $e');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image Section
            Container(
              width: double.infinity,
              height: 320,
              color: const Color(0xFFF5F5F5),
              child: Stack(
                children: [
                  Center(
                    child: AuthenticatedImage(
                      imageUrl:
                          _selectedVariation?.imageUrl ??
                          widget.product.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                  // Discount Badge
                  if (widget.product.discount != null)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.product.discount!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Product Details
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category and Stock Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDB022).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.product.category,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFDB022),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'In Stock',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Product Name
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Rating Section
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (index) => Icon(
                          index < widget.product.rating.toInt()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: const Color(0xFFFDB022),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.product.rating}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${widget.product.reviews} reviews)',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Price Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Price',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '₱${widget.product.price.toStringAsFixed(2).replaceAllMapped(
                                RegExp(r'(\d)(?=(\d{3})+\.)'),
                                (Match m) => '${m[1]},',
                              )}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6200EE),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Color Selection
                  _buildColorSelection(),

                  const SizedBox(height: 24),
                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description ?? 'No description available',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Product Specifications
                  const Text(
                    'Specifications',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSpecificationRow('Material', widget.product.material),
                  const SizedBox(height: 10),
                  _buildSpecificationRow(
                    'Color',
                    _selectedVariation?.color ?? widget.product.color,
                  ),
                  const SizedBox(height: 10),
                  _buildSpecificationRow('Category', widget.product.category),
                  const SizedBox(height: 24),
                  // Quantity Selector
                  const Text(
                    'Quantity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _quantity > 1
                              ? () {
                                  setState(() {
                                    _quantity--;
                                  });
                                }
                              : null,
                          child: Icon(
                            Icons.remove,
                            color: _quantity > 1
                                ? const Color(0xFF6200EE)
                                : const Color(0xFFCCCCCC),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '$_quantity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _quantity++;
                            });
                          },
                          child: const Icon(
                            Icons.add,
                            color: Color(0xFF6200EE),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // AR and 3D Buttons
                  if (_hasAnyModel())
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _isDownloadingModel
                                  ? null
                                  : () => _handleModelView(isAR: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFDB022),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: _isDownloadingModel
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.black,
                                            ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.view_in_ar,
                                      color: Colors.black,
                                    ),
                              label: Text(
                                _isDownloadingModel
                                    ? '${(_downloadProgress * 100).toInt()}%'
                                    : 'View in AR',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed: _isDownloadingModel
                                  ? null
                                  : () => _handleModelView(isAR: false),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF1E3A8A),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.rotate_right,
                                color: Color(0xFF1E3A8A),
                              ),
                              label: Text(
                                _isDownloadingModel
                                    ? '${(_downloadProgress * 100).toInt()}%'
                                    : 'View 3D',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(Icons.view_in_ar, color: Colors.grey[500]),
                        label: Text(
                          'No AR Model Available',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  // Add to Cart Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Consumer<CartProvider>(
                      builder: (context, cartProvider, child) {
                        return ElevatedButton(
                          onPressed: () async {
                            try {
                              await cartProvider.addToCart(
                                product: widget.product,
                                quantity: _quantity,
                                colorOverride: _selectedVariation?.color,
                                imageUrlOverride: _selectedVariation?.imageUrl,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '$_quantity ${widget.product.name} added to cart',
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 2),
                                    action: SnackBarAction(
                                      label: 'View Cart',
                                      textColor: Colors.white,
                                      onPressed: () =>
                                          Navigator.pushNamed(context, '/cart'),
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error adding to cart: $e'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6200EE),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Add to Cart',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSelection() {
    final variations = widget.product.getAllVariations();
    if (variations.length <= 1) return const SizedBox.shrink();

    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Colors',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                scrollDirection: Axis.horizontal,
                itemCount: variations.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final variation = variations[index];
                  final isSelected =
                      _selectedVariation?.color == variation.color;
                  final colorValue = ColorUtils.getColorFromName(
                    variation.color,
                  );
                  final contrastColor = ColorUtils.getContrastColor(colorValue);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedVariation = variation;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? colorValue : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? colorValue
                              : colorValue.withAlpha(120),
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: colorValue.withAlpha(76),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          variation.color,
                          style: TextStyle(
                            color: isSelected
                                ? contrastColor
                                : const Color(0xFF1E3A8A),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpecificationRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasAnyModel() {
    // Check base product
    if (widget.product.modelUrl != null &&
        widget.product.modelUrl!.isNotEmpty) {
      return true;
    }
    // Check all variations
    final variations = widget.product.getAllVariations();
    for (final v in variations) {
      if (v.modelUrl != null && v.modelUrl!.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> _handleModelView({bool isAR = true}) async {
    // Correctly prioritize variation model, then fallback to base product model
    String? modelUrl = _selectedVariation?.modelUrl;

    // If variation model is null or empty, use the base product model
    if (modelUrl == null || modelUrl.isEmpty) {
      modelUrl = widget.product.modelUrl;
    }

    if (modelUrl == null || modelUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No 3D model available for this selection'),
          ),
        );
      }
      return;
    }

    setState(() {
      _isDownloadingModel = true;
      _downloadProgress = 0.0;
    });

    try {
      final filebaseService = FilebaseService();
      final fileName = filebaseService.getUniqueFileName(modelUrl);
      final appDocDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDocDir.path}/$fileName';
      final file = File(filePath);

      String? localPath;

      if (await file.exists()) {
        setState(() {
          _downloadProgress = 1.0;
        });
        localPath = filePath;
      } else {
        localPath = await FilebaseService().downloadModelFile(
          modelUrl: modelUrl,
          localFilePath: filePath,
          onProgress: (received, total) {
            if (mounted && total > 0) {
              setState(() {
                _downloadProgress = received / total;
              });
            }
          },
        );
      }

      setState(() {
        _isDownloadingModel = false;
      });

      if (localPath != null && mounted) {
        if (isAR) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ARViewerScreen(
                productName: widget.product.name,
                modelUrl: modelUrl!,
                modelScale: widget.product.modelScale,
                localModelPath: localPath!,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ThreeDViewerScreen(
                localPath: localPath!,
                product: widget.product,
                variation: _selectedVariation,
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isDownloadingModel = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading model: $e')));
      }
    }
  }
}
