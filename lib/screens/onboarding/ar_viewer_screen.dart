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
import 'package:logger/logger.dart';
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
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTime,
    ),
  );

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
  vector.Vector3? _originalScale; // Store original scale
  bool _isPlacingModel = false; // Loading state for model placement

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
      handlePans: false, // Start with pans disabled
      handleRotation: false, // Start with rotation disabled
      handleTaps: false, // Disable tap-to-place
    );
    this.arObjectManager?.onInitialize();

    // Tap-to-place is disabled - users must use "Place Item" button
    // this.arSessionManager?.onPlaneOrPointTap = onPlaneOrPointTapped;

    // Add pan handlers - they will check manual mode internally
    this.arObjectManager?.onPanStart = onPanStart;
    this.arObjectManager?.onPanChange = onPanChange;
    this.arObjectManager?.onPanEnd = onPanEnd;

    // Start downloading model immediately
    _downloadModel();
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
      _isPlacingModel = true; // Show loading indicator
    });

    try {
      _logger.i('📍 Placing model at screen center...');
      // modelScale from Firebase is in centimeters, convert to meters for AR
      final double scaleInCm = widget.modelScale ?? 50.0;
      final double scaleValue = scaleInCm / 100.0; // Convert CM to meters
      final fileName = _localModelPath!.split('/').last;

      _logger.d('🎯 Placing AR Model:');
      _logger.d('   Full Path: $_localModelPath');
      _logger.d('   File Name: $fileName');
      _logger.d('   Scale (CM): $scaleInCm -> (Meters): $scaleValue');

      // Verify file exists
      final file = File(_localModelPath!);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      _logger.d('   File Exists: $exists');
      _logger.d('   File Size: $size bytes');

      final newNode = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri: fileName,
        scale: vector.Vector3(scaleValue, scaleValue, scaleValue),
        position: vector.Vector3(
          0.0,
          0.0,
          -1.0,
        ), // 1m in front of camera at ground level
        rotation: vector.Vector4(1, 0, 0, 0),
      );

      _logger.d('   Node Type: ${newNode.type}');
      _logger.d('   Node URI: ${newNode.uri}');
      _logger.i('🚀 Adding node to AR scene...');

      bool? didAddNode = await arObjectManager?.addNode(newNode);

      _logger.i('   Result: ${didAddNode == true ? "SUCCESS" : "FAILED"}');

      if (didAddNode ?? false) {
        productNode = newNode;
        _originalScale = vector.Vector3(scaleValue, scaleValue, scaleValue);
        _logger.i('Model placed successfully with scale: $_originalScale');
        setState(() {
          _isModelPlaced = true;
          _isBusy = false;
          _isPlacingModel = false;
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
        _logger.e('❌ Failed to add node');
        setState(() {
          _isBusy = false;
          _isPlacingModel = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to place model'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Error placing model', error: e, stackTrace: stackTrace);
      setState(() {
        _isBusy = false;
        _isPlacingModel = false; // Hide loading indicator
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
      // modelScale from Firebase is in centimeters, convert to meters for AR
      final double scaleInCm = widget.modelScale ?? 50.0;
      final double scaleValue = scaleInCm / 100.0; // Convert CM to meters
      final fileName = _localModelPath!.split('/').last;

      _logger.d('🎯 Adding AR Model:');
      _logger.d('   Full Path: $_localModelPath');
      _logger.d('   File Name: $fileName');
      _logger.d('   Scale (CM): $scaleInCm -> (Meters): $scaleValue');

      // Verify file exists
      final file = File(_localModelPath!);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      _logger.d('   File Exists: $exists');
      _logger.d('   File Size: $size bytes');

      final newNode = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri:
            fileName, // IMPORTANT: Just the filename for fileSystemAppFolderGLB
        scale: vector.Vector3(scaleValue, scaleValue, scaleValue),
        position: vector.Vector3(0.0, 0.0, 0.0),
        rotation: vector.Vector4(1, 0, 0, 0),
      );

      _logger.d('   Node Type: ${newNode.type}');
      _logger.d('   Node URI: ${newNode.uri}');
      _logger.i('🚀 Attempting to add node to AR scene...');

      bool? didAddNode = await arObjectManager?.addNode(
        newNode,
        planeAnchor: anchor,
      );

      _logger.i('   Result: ${didAddNode == true ? "SUCCESS" : "FAILED"}');

      if (didAddNode ?? false) {
        productNode = newNode;
        _originalScale = vector.Vector3(
          scaleValue,
          scaleValue,
          scaleValue,
        ); // Store original scale
        _logger.i('Model placed at anchor with scale: $_originalScale');
        setState(() {
          _isModelPlaced = true;
          _isBusy = false;
          _isPlacingModel = false; // Hide loading indicator
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
        _logger.e('❌ Failed to add node - model not rendering');
        setState(() {
          _isBusy = false;
          _isPlacingModel = false; // Hide loading indicator
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
    } catch (e, stackTrace) {
      _logger.e('❌ Exception adding model', error: e, stackTrace: stackTrace);
      setState(() {
        _isBusy = false;
        _isPlacingModel = false; // Hide loading indicator
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

  /// Pan handlers for dragging the AR object
  void onPanStart(String nodeName) {
    try {
      _logger.i('🖐️ Pan started on node: $nodeName');
      _logger.d(
        'Manual mode: $_isManualPlacement, Model placed: $_isModelPlaced',
      );

      // Store the original scale before panning starts
      if (productNode != null && _originalScale != null) {
        _logger.d('Original scale preserved: $_originalScale');
      }
    } catch (e, stackTrace) {
      _logger.e('Error in onPanStart', error: e, stackTrace: stackTrace);
    }
  }

  void onPanChange(String nodeName) {
    try {
      // Object is being dragged by the AR plugin automatically
      // Scale preservation is handled in onPanEnd
    } catch (e, stackTrace) {
      _logger.e('Error in onPanChange', error: e, stackTrace: stackTrace);
    }
  }

  void onPanEnd(String nodeName, vector.Matrix4 newTransform) {
    try {
      _logger.i('✋ Pan ended on node: $nodeName');

      // Ensure scale is retained after dragging
      if (productNode != null &&
          _originalScale != null &&
          arObjectManager != null) {
        _logger.d('Restoring scale after pan: $_originalScale');

        // Extract position from new transform
        final translation = newTransform.getTranslation();

        // Extract rotation as Quaternion from Matrix4
        final rotationMatrix = newTransform.getRotation();
        final quaternion = vector.Quaternion.fromRotation(rotationMatrix);

        // Create updated node with preserved scale
        final updatedNode = ARNode(
          type: productNode!.type,
          uri: productNode!.uri,
          scale: _originalScale!, // Use original scale
          position: translation,
          rotation: vector.Vector4(
            quaternion.x,
            quaternion.y,
            quaternion.z,
            quaternion.w,
          ),
        );

        // Update the node
        arObjectManager?.removeNode(productNode!);
        arObjectManager?.addNode(updatedNode).then((success) {
          if (success == true) {
            setState(() {
              productNode = updatedNode;
            });
            _logger.d('Successfully updated node with preserved scale');
          } else {
            _logger.w('Failed to update node after pan');
          }
        });
      }
    } catch (e, stackTrace) {
      _logger.e('Error in onPanEnd', error: e, stackTrace: stackTrace);
    }
  }

  void _toggleManualPlacement(bool value) {
    _logger.i('🔄 Toggling manual placement mode: $value');

    setState(() {
      _isManualPlacement = value;
      // Show guide only when enabling manual placement
      if (_isManualPlacement) {
        _showGuide = true;
      }
    });

    // Enable/disable pans and rotation based on manual mode
    // IMPORTANT: This must be called AFTER the model is placed
    if (arSessionManager != null) {
      _logger.d(
        'Reinitializing AR session with handlePans=$value, handleRotation=$value',
      );

      arSessionManager?.onInitialize(
        showFeaturePoints: false,
        showPlanes: true,
        showWorldOrigin: false,
        handlePans: value, // Enable pans only in manual mode
        handleRotation: value, // Enable rotation only in manual mode
        handleTaps: false, // Tap-to-place always disabled
      );

      _logger.i(
        'AR session reinitialized. Pans/Rotation ${value ? "ENABLED" : "DISABLED"}',
      );
    } else {
      _logger.w('Cannot reinitialize - arSessionManager is null');
    }
  }

  void _rotateNode(double angle) {
    if (productNode == null ||
        arObjectManager == null ||
        !_isManualPlacement ||
        !_isModelPlaced) {
      return;
    }

    try {
      _logger.d('🔄 Rotating node to angle: ${(angle * 57.2958).toInt()}°');

      // Update rotation state immediately for smooth UI
      setState(() {
        _rotation = angle;
      });

      // Create quaternion for Y-axis rotation
      final quaternion = vector.Quaternion.axisAngle(
        vector.Vector3(0, 1, 0), // Y-axis (vertical)
        angle,
      );

      // Create updated node with new rotation but same position and scale
      final updatedNode = ARNode(
        type: productNode!.type,
        uri: productNode!.uri,
        scale: _originalScale ?? productNode!.scale,
        position: productNode!.position,
        rotation: vector.Vector4(
          quaternion.x,
          quaternion.y,
          quaternion.z,
          quaternion.w,
        ),
      );

      // IMPORTANT: Wait for removal before adding to prevent duplication
      arObjectManager?.removeNode(productNode!).then((removed) async {
        if (removed == true) {
          final success = await arObjectManager?.addNode(updatedNode);
          if (success == true) {
            setState(() {
              productNode = updatedNode;
            });
            _logger.d('✅ Node rotated successfully');
          } else {
            _logger.w('⚠️ Failed to add rotated node');
          }
        } else {
          _logger.w('⚠️ Failed to remove old node for rotation');
        }
      });
    } catch (e, stackTrace) {
      _logger.e('Error rotating node', error: e, stackTrace: stackTrace);
    }
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
                      else if (_isPlacingModel)
                        const Column(
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFFDB022),
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Placing model...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      else if (!_isModelPlaced) ...[
                        const Text(
                          'Point camera at the floor and tap "Place Item"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 14),
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
