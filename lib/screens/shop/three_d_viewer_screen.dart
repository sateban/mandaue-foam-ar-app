import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

enum LightingMode { front, leftSide }

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
  LightingMode _lightingMode = LightingMode.front;

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
          // 3D Viewer using model_viewer_plus for advanced lighting control
          ModelViewer(
            key: ValueKey('${widget.localPath}_${_lightingMode.index}'),
            src: 'file://${widget.localPath}',
            alt: widget.productName,
            autoRotate: false,
            cameraControls: true,
            backgroundColor: Colors.white,
            // Lighting simulation trick:
            // Front: Default orientation and camera
            // Left Side: Rotate model 90deg and compensate camera to look at front again.
            // Since the environment lighting is fixed in the world, the light now hits the side.
            orientation: _lightingMode == LightingMode.front
                ? "0deg 0deg 0deg"
                : "0deg 90deg 0deg",
            cameraOrbit: _lightingMode == LightingMode.front
                ? "0deg 75deg auto"
                : "-90deg 75deg auto",
            exposure: _lightingMode == LightingMode.front ? 1.0 : 0.8,
            shadowIntensity: 1.0,
            shadowSoftness: 0.5,
          ),

          // Tools Panel
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
                        Icons.light_mode,
                        color: Color(0xFF1E3A8A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Lighting Options',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _lightingMode == LightingMode.front
                            ? 'Frontal'
                            : 'Side Light',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLightingButton(
                          mode: LightingMode.front,
                          icon: Icons.wb_sunny_outlined,
                          label: 'Front',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildLightingButton(
                          mode: LightingMode.leftSide,
                          icon: Icons.wb_twilight_outlined,
                          label: 'Left Side',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pinch to zoom • Drag to rotate • Two fingers to pan',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightingButton({
    required LightingMode mode,
    required IconData icon,
    required String label,
  }) {
    bool isSelected = _lightingMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _lightingMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E3A8A), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
