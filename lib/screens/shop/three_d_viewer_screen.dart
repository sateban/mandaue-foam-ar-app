import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  WebViewController? _controller;
  bool _isLoading = true;
  int _selectedLightingIndex = 0;

  final List<Map<String, dynamic>> _lightingOptions = [
    {'name': 'Default', 'rotation': '0deg 0deg 0deg', 'icon': Icons.light_mode},
    {'name': 'Left', 'rotation': '0deg 90deg 0deg', 'icon': Icons.west},
    {
      'name': 'Back',
      'rotation': '0deg 180deg 0deg',
      'icon': Icons.flip_camera_android,
    },
    {'name': 'Right', 'rotation': '0deg 270deg 0deg', 'icon': Icons.east},
    {
      'name': 'Top',
      'rotation': '90deg 0deg 0deg',
      'icon': Icons.vertical_align_top,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final file = File(widget.localPath);
    if (!await file.exists()) {
      debugPrint('File does not exist: ${widget.localPath}');
      return;
    }

    // copy the model to a file named 'model.glb' in the same directory to ensure the name is clean for the referencing
    final parentDir = file.parent;
    final modelPath = '${parentDir.path}/model.glb';
    try {
      await file.copy(modelPath);
    } catch (e) {
      debugPrint('Error copying file: $e');
    }

    final html = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
        <style>
          body { margin: 0; height: 100vh; background-color: #ffffff; display: flex; justify-content: center; align-items: center; }
          model-viewer { width: 100%; height: 100%; }
        </style>
        <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/3.4.0/model-viewer.min.js"></script>
      </head>
      <body>
        <model-viewer 
          src="model.glb" 
          camera-controls 
          environment-image="neutral" 
          shadow-intensity="1"
          exposure="1"
          environment-rotation="0deg 0deg 0deg"
          interaction-prompt="auto"
          ar="false">
        </model-viewer>
      </body>
      </html>
    ''';

    // Write HTML to file in the same directory
    final htmlFile = File('${parentDir.path}/viewer.html');
    await htmlFile.writeAsString(html);

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.file(htmlFile.path));

    if (mounted) {
      setState(() {
        _controller = controller;
      });
    }
  }

  void _updateLighting(int index) {
    setState(() {
      _selectedLightingIndex = index;
    });
    final rotation = _lightingOptions[index]['rotation'];
    _controller?.runJavaScript(
      "const mv = document.querySelector('model-viewer'); if(mv) { mv.environmentRotation = '$rotation'; }",
    );
  }

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
          // WebView for 3D Model
          if (_controller != null) WebViewWidget(controller: _controller!),

          // Loading Indicator
          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // Lighting Controls
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        size: 20,
                        color: Color(0xFF1E3A8A),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Lighting Direction',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _lightingOptions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      final isSelected = _selectedLightingIndex == index;

                      return GestureDetector(
                        onTap: () => _updateLighting(index),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF1E3A8A)
                                    : Colors.grey[100],
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? null
                                    : Border.all(color: Colors.grey[300]!),
                              ),
                              child: Icon(
                                option['icon'],
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[600],
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              option['name'],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFF1E3A8A)
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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
