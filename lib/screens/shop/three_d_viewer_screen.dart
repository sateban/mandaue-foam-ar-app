import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

class ThreeDViewerScreen extends StatefulWidget {
  final String localPath;
  final String productName;

  const ThreeDViewerScreen({
    super.key,
    required this.localPath,
    required this.productName,
  });

  @override
  State<ThreeDViewerScreen> createState() => _ThreeDViewerScreenState();
}

class _ThreeDViewerScreenState extends State<ThreeDViewerScreen> {
  final Flutter3DController _controller = Flutter3DController();
  bool _isLoading = true;

  // Since Flutter3DViewer is native, it handles memory better for 70MB+ models.
  // We'll adapt the UI to what the native viewer supports.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.productName,
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
          // Native 3D Viewer - Much more memory efficient for large models
          Flutter3DViewer(
            src: 'file://${widget.localPath}',
            controller: _controller,
            onProgress: (double progressValue) {
              debugPrint('Model Loading Progress: $progressValue');
            },
            onLoad: (String modelName) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onError: (String error) {
              debugPrint('Model Loading Error: $error');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error loading 3D model: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),

          if (_isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1E3A8A)),
                  SizedBox(height: 16),
                  Text(
                    'Optimizing 3D Model...',
                    style: TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Tools Panel (Simplified for native viewer capabilities)
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
                  const Row(
                    children: [
                      Icon(Icons.touch_app, color: Color(0xFF1E3A8A), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Viewer Controls',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pinch to zoom • Drag to rotate • Two fingers to pan',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _controller.resetAnimation(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset Model View'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E3A8A),
                        side: const BorderSide(color: Color(0xFF1E3A8A)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
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
