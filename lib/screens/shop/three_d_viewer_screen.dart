import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';

class ThreeDViewerScreen extends StatefulWidget {
  final String localPath;
  final Product product;
  final ProductVariation? variation;

  const ThreeDViewerScreen({
    super.key,
    required this.localPath,
    required this.product,
    this.variation,
  });

  @override
  State<ThreeDViewerScreen> createState() => _ThreeDViewerScreenState();
}

class _ThreeDViewerScreenState extends State<ThreeDViewerScreen> {
  final double _brightness = 1.0;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.product.isFavorite;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.product.name,
          style: const TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A8A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Fixed World Background
          Positioned.fill(child: Container(color: Colors.white)),

          // 3D Viewer
          ColorFiltered(
            colorFilter: ColorFilter.matrix([
              _brightness,
              0,
              0,
              0,
              0,
              0,
              _brightness,
              0,
              0,
              0,
              0,
              0,
              _brightness,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: ModelViewer(
              key: ValueKey('${widget.localPath}_view'),
              src: 'file://${widget.localPath}',
              alt: widget.product.name,
              autoRotate: true,
              cameraControls: true,
              backgroundColor: Colors.transparent,
              exposure: 1.0,
              shadowIntensity: 1.0,
              shadowSoftness: 1.0,
            ),
          ),

          // Bottom Action Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        color: Color(0xFF1E3A8A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.variation != null
                              ? '${widget.product.name} (${widget.variation!.color})'
                              : widget.product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Consumer<ProductProvider>(
                    builder: (context, productProvider, child) {
                      return SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final wasFavorite = _isFavorite;
                              
                              // Optimistic update
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
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.all(20),
                                ),
                              );

                              await productProvider.toggleProductFavorite(
                                widget.product.id,
                              );
                            } catch (e) {
                              // Rollback
                              setState(() {
                                _isFavorite = !_isFavorite;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(20),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isFavorite
                                    ? Colors.grey[200]
                                    : const Color(0xFF6200EE),
                            foregroundColor:
                                _isFavorite ? Colors.red : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          icon: Icon(
                            _isFavorite ? Icons.favorite : Icons.favorite_border,
                          ),
                          label: Text(
                            _isFavorite
                                ? 'Remove from Favorites'
                                : 'Add to Favorites',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pinch to zoom • Drag to rotate • Two fingers to pan',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
