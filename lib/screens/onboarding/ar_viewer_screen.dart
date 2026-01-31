import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin_updated/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_updated/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_updated/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_updated/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ar_flutter_plugin_updated/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_updated/models/ar_anchor.dart';
import '../../services/filebase_service.dart';

class ARViewerScreen extends StatefulWidget {
  final String productName;
  final String modelUrl;
  final double? modelScale;

  const ARViewerScreen({
    super.key,
    required this.productName,
    required this.modelUrl,
    this.modelScale,
  });

  @override
  State<ARViewerScreen> createState() => _ARViewerScreenState();
}

class _ARViewerScreenState extends State<ARViewerScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARNode? productNode;
  bool _isModelPlaced = false;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  bool _isBusy = false;
  bool _isManualPlacement = false;
  bool _showGuide = false;
  bool _isPreviewMode = false;
  double _rotation = 0.0;
  ARAnchorManager? arAnchorManager;
  String? _localModelPath;

  @override
  void dispose() {
    super.dispose();
    arSessionManager?.dispose();
  }

  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;

    this.arAnchorManager = arAnchorManager;

    this.arSessionManager?.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
      handlePans: true,
      handleRotation: true,
      handleTaps: true,
    );
    this.arObjectManager?.onInitialize();

    this.arSessionManager?.onPlaneOrPointTap = onPlaneOrPointTapped;

    // Start downloading model immediately
    _downloadModel();

    // Listen for node taps/pans if needed for manual control via plugin
    // However, we will use overlay gestures for manual placement if preferred
    // or rely on plugin's auto-handling for now if it supports it.
    // For specific "Swipe to move" requirement, we might need custom handling.

    // Using plugin's pan handling for now as it's more robust than custom overlay
    // but enabling it only when manual mode is ON if possible, or always.
    // The requirement says "controls to move the object are by using swipe in screen",
    // which effectively is what handlePans: true does.
  }

  Future<void> onPlaneOrPointTapped(
    List<ARHitTestResult> hitTestResults,
  ) async {
    if (_isModelPlaced || _isBusy) return;

    if (_localModelPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading model... please wait')),
      );
      return;
    }

    var singleHitTestResult = hitTestResults.firstOrNull;
    if (singleHitTestResult != null) {
      setState(() {
        _isBusy = true;
      });

      var newAnchor = ARPlaneAnchor(
        transformation: singleHitTestResult.worldTransform,
      );
      bool? didAddAnchor = await arAnchorManager!.addAnchor(newAnchor);

      if (didAddAnchor == true) {
        await _addModelAtAnchor(newAnchor);
      } else {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  /// Place model at screen center (button-triggered placement)
  Future<void> _placeModelAtCenter() async {
    if (_isModelPlaced || _isBusy || _localModelPath == null) return;

    setState(() {
      _isBusy = true;
    });

    try {
      print('📍 Placing model directly in AR space...');
      final double scaleInCm = widget.modelScale ?? 50.0;
      final double scaleInMeters = scaleInCm / 100.0;
      final scaleValue = scaleInMeters;
      final fileName = _localModelPath!.split('/').last;

      print('🎯 Placing AR Model:');
      print('   Full Path: $_localModelPath');
      print('   File Name: $fileName');
      print('   Scale (CM): $scaleInCm -> (Meters): $scaleInMeters');

      // Verify file exists
      final file = File(_localModelPath!);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      print('   File Exists: $exists');
      print('   File Size: $size bytes');

      final newNode = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri: fileName,
        scale: vector.Vector3(scaleValue, scaleValue, scaleValue),
        position: vector.Vector3(0.0, -0.5, -1.5), // 1.5m in front, 0.5m down
        rotation: vector.Vector4(1, 0, 0, 0),
      );

      print('   Node Type: ${newNode.type}');
      print('   Node URI: ${newNode.uri}');
      print('🚀 Adding node directly to AR scene...');

      bool? didAddNode = await arObjectManager?.addNode(newNode);

      print('   Result: ${didAddNode == true ? "SUCCESS" : "FAILED"}');

      if (didAddNode ?? false) {
        productNode = newNode;
        setState(() {
          _isModelPlaced = true;
          _isBusy = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.productName} placed!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('❌ Failed to add node');
        setState(() {
          _isBusy = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to place model - check console'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error placing model: $e');
      print('   Stack trace: ${StackTrace.current}');
      setState(() {
        _isBusy = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addModelAtAnchor(ARPlaneAnchor anchor) async {
    try {
      final double scaleInCm = widget.modelScale ?? 50.0;
      final double scaleInMeters = scaleInCm / 100.0;
      final scaleValue = scaleInMeters;
      final fileName = _localModelPath!.split('/').last;

      print('🎯 Adding AR Model:');
      print('   Full Path: $_localModelPath');
      print('   File Name: $fileName');
      print('   Scale (CM): $scaleInCm -> (Meters): $scaleInMeters');

      // Verify file exists
      final file = File(_localModelPath!);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      print('   File Exists: $exists');
      print('   File Size: $size bytes');

      final newNode = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri:
            fileName, // IMPORTANT: Just the filename for fileSystemAppFolderGLB
        scale: vector.Vector3(scaleValue, scaleValue, scaleValue),
        position: vector.Vector3(0.0, 0.0, 0.0),
        rotation: vector.Vector4(1, 0, 0, 0),
      );

      print('   Node Type: ${newNode.type}');
      print('   Node URI: ${newNode.uri}');
      print('🚀 Attempting to add node to AR scene...');

      bool? didAddNode = await arObjectManager?.addNode(
        newNode,
        planeAnchor: anchor,
      );

      print('   Result: ${didAddNode == true ? "SUCCESS" : "FAILED"}');

      if (didAddNode ?? false) {
        productNode = newNode;
        setState(() {
          _isModelPlaced = true;
          _isBusy = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.productName} placed!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('❌ Failed to add node - model not rendering');
        setState(() {
          _isBusy = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to place model - check console'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Exception adding model: $e');
      print('   Stack trace: ${StackTrace.current}');
      setState(() {
        _isBusy = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Download and cache the 3D model from URL
  Future<String?> _downloadModel() async {
    try {
      if (_localModelPath != null) return _localModelPath;

      print('🔍 Model URL received: ${widget.modelUrl}');
      final fileName = widget.modelUrl.split('/').last;

      // Use app support directory for AR plugin compatibility
      final appSupportDir = await getApplicationSupportDirectory();
      final filePath = '${appSupportDir.path}/$fileName';
      final file = File(filePath);

      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      if (await file.exists()) {
        print('📦 Using cached model: $filePath');
        final fileSize = await file.length();
        print('   File size: $fileSize bytes');

        setState(() {
          _isDownloading = false;
          _downloadProgress = 1.0;
          _localModelPath = filePath;
        });
        return filePath; // Return full path
      }

      print('⬇️  Downloading 3D model from: ${widget.modelUrl}');
      print('   Save location: $filePath');

      final filebaseService = FilebaseService();
      final downloadedPath = await filebaseService.downloadModelFile(
        modelUrl: widget.modelUrl,
        localFilePath: filePath,
        onProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() {
              _downloadProgress = received / total;
            });
            print(
              '📊 Download progress: ${(received / total * 100).toInt()}% ($received / $total bytes)',
            );
          }
        },
      );

      setState(() {
        _isDownloading = false;
      });

      if (downloadedPath != null) {
        // Verify the downloaded file
        final downloadedFile = File(downloadedPath);
        if (await downloadedFile.exists()) {
          final fileSize = await downloadedFile.length();
          print('✅ Model downloaded and cached: $downloadedPath');
          print('   Final file size: $fileSize bytes');

          setState(() {
            _localModelPath = downloadedPath;
          });
          return downloadedPath; // Return full path
        } else {
          print('❌ Downloaded file does not exist at path: $downloadedPath');
          return null;
        }
      } else {
        print('❌ Failed to download model - downloadModelFile returned null');
        return null;
      }
    } catch (e) {
      print('❌ Error downloading model: $e');
      print('   Stack trace: ${StackTrace.current}');
      setState(() {
        _isDownloading = false;
      });
      return null;
    }
  }

  /*
  Future<void> _removeModel() async {
    if (productNode != null && arObjectManager != null) {
      await arObjectManager?.removeNode(productNode!);
      setState(() {
        _isModelPlaced = false;
        productNode = null;
      });
    }
  }
  */

  void _toggleManualPlacement(bool value) {
    setState(() {
      _isManualPlacement = value;
      // Show guide only when enabling manual placement
      if (_isManualPlacement) {
        _showGuide = true;
      }
    });
  }

  void _rotateNode(double angle) {
    if (productNode != null && arObjectManager != null) {
      // Create quaternion for rotation around Y axis
      // Basic implementation for Gizmo rotation
      // Note: flutter_ar_plugin usually expects Vector4 quaternion
      // or similar structure depending on version.
      // Here we assume basic rotation logic.
      // Since internal rotation modification might be tricky with just 'node.rotation',
      // we might need to remove and re-add or use transformation methods if available.
      // For now, let's just log implementation intent or try a simple update if supported.

      // NOTE: Real-time rotation via plugin might require specific method calls.
      // This is a placeholder for the actual rotation logic connected to the gizmo.
    }
    setState(() {
      _rotation = angle;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // AppBar Overlay
          if (!_isPreviewMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.productName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Manual Placement Toggle
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _isManualPlacement
                              ? const Color(0xFFFDB022).withOpacity(0.9)
                              : Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Manual',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            Switch(
                              value: _isManualPlacement,
                              onChanged: _toggleManualPlacement,
                              activeColor: Colors.white,
                              activeTrackColor: Colors.orange,
                              inactiveThumbColor: Colors.grey,
                              inactiveTrackColor: Colors.grey[800],
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Guide Overlay
          if (_showGuide && _isManualPlacement)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.swipe, color: Colors.white, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Manual Mode Guide',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '• Swipe on screen to move object\n• Use the wheel at bottom to rotate\n• Placement is locked to planes',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Checkbox(
                          value: false, // TODO: Implement persistence
                          onChanged: (val) {},
                          fillColor: const WidgetStatePropertyAll(Colors.white),
                          checkColor: Colors.black,
                        ),
                        const Text(
                          "Don't show again",
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _showGuide = false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDB022),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              ),
            ),

          // Rotation Gizmo (Only in Manual Mode when model is placed)
          if (_isManualPlacement &&
              _isModelPlaced &&
              !_isPreviewMode &&
              !_showGuide)
            Positioned(
              bottom:
                  MediaQuery.of(context).padding.bottom +
                  100, // Above bottom panel
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onPanUpdate: (details) {
                    _rotateNode(_rotation + details.delta.dx * 0.01);
                  },
                  child: Container(
                    width: 200,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFFFDB022).withOpacity(0.5),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        10,
                        (index) => Container(
                          width: 2,
                          height: index % 2 == 0 ? 20 : 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Debug Text for Rotation
          if (_isManualPlacement && _isModelPlaced && !_isPreviewMode)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 160,
              left: 0,
              right: 0,
              child: Text(
                "Rotate: ${(_rotation * 57.2958).toInt()}°", // Rad to Deg
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                ),
              ),
            ),

          // Preview Toggle (Only when model is placed)
          if (_isModelPlaced && !_showGuide)
            Positioned(
              top: _isPreviewMode
                  ? MediaQuery.of(context).padding.top + 10
                  : MediaQuery.of(context).padding.top + 60,
              right: 16,
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _isPreviewMode = !_isPreviewMode;
                  });
                },
                icon: Icon(
                  _isPreviewMode ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white,
                ),
                tooltip: _isPreviewMode ? "Exit Preview" : "Preview",
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
              ),
            ),

          // Bottom Control Panel
          if (!_isPreviewMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  MediaQuery.of(context).padding.bottom + 20,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isDownloading)
                        Column(
                          children: [
                            LinearProgressIndicator(
                              value: _downloadProgress,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFFDB022),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Downloading model... ${(_downloadProgress * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      else if (!_isModelPlaced) ...[
                        Text(
                          'Aim your camera at a flat surface',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: (_localModelPath != null && !_isBusy)
                                ? _placeModelAtCenter
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFDB022),
                              disabledBackgroundColor: Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.add_location,
                              color: Colors.black,
                            ),
                            label: const Text(
                              'Place Item',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(
                          '${widget.productName} placed successfully!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
