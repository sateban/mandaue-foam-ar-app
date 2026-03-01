import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

enum LightingMode { front, leftSide, rightSide }

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
  double _brightness = 1.0;

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
          // Fixed World Background (unaffected by brightness)
          Positioned.fill(child: Container(color: Colors.white)),

          // 3D Viewer with Realtime Brightness via ColorFilter
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
              key: ValueKey('${widget.localPath}_${_lightingMode.index}'),
              src: 'file://${widget.localPath}',
              alt: widget.productName,
              autoRotate: true,
              cameraControls: true,
              backgroundColor:
                  Colors.transparent, // Important: keep underlying pixels clear
              // Keep base exposure at 1.0; the ColorFilter handles the intensity
              exposure: 1.0,
              orientation: _lightingMode == LightingMode.front
                  ? "0deg 0deg 0deg"
                  : (_lightingMode == LightingMode.leftSide
                        ? "0deg 90deg 0deg"
                        : "0deg -90deg 0deg"),
              cameraOrbit: _lightingMode == LightingMode.front
                  ? "0deg 75deg auto"
                  : (_lightingMode == LightingMode.leftSide
                        ? "90deg 75deg auto"
                        : "-90deg 75deg auto"),
              shadowIntensity: 1.0,
              shadowSoftness: 1.0, // Maximum softness for ray-traced feel
            ),
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
                            : (_lightingMode == LightingMode.leftSide
                                  ? 'Left Side'
                                  : 'Right Side'),
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
                          mode: LightingMode.leftSide,
                          icon: Icons.wb_twilight_rounded,
                          label: 'Left',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLightingButton(
                          mode: LightingMode.front,
                          icon: Icons.wb_sunny_rounded,
                          label: 'Front',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLightingButton(
                          mode: LightingMode.rightSide,
                          icon: Icons.wb_twilight_rounded,
                          label: 'Right',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.brightness_6,
                        color: Color(0xFF1E3A8A),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Brightness',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E3A8A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(_brightness * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.7),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                      activeTrackColor: const Color(0xFF1E3A8A),
                      inactiveTrackColor: const Color(
                        0xFF1E3A8A,
                      ).withValues(alpha: 0.1),
                      thumbColor: const Color(0xFF1E3A8A),
                    ),
                    child: Slider(
                      value: _brightness,
                      min: 0.1,
                      max: 1.0,
                      onChanged: (value) {
                        setState(() {
                          _brightness = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
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
