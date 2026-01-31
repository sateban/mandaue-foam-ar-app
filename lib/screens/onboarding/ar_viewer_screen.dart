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
  bool _showCoachingOverlay = true; // Initial coaching overlay
  bool _isPreviewMode = false;
  double _rotation = 0.0;
  ARAnchorManager? arAnchorManager;
  String? _localModelPath;
  vector.Vector3? _currentNodePosition; // Track current position for drag
  vector.Vector3? _originalScale; // Store original scale
  bool _isPlacingModel = false; // Loading state for model placement
  bool _isDisposing = false;
  bool _isExiting = false; // Set true after cleanup to allow pop

  /// Explicitly hide native hand/plane overlays. Must be called before dispose
  /// and when leaving the screen to prevent the overlay from persisting.
  void _hideNativeOverlays() {
    if (_isDisposing) return;
    try {
      arSessionManager?.onInitialize(
        showAnimatedGuide: false,
        showFeaturePoints: false,
        showPlanes: false,
        showWorldOrigin: false,
        handlePans: false, 
        handleRotation: false,
        handleTaps: false,
      );
    } catch (e) {
      _logger.w('Error hiding native overlays: $e');
    }
  }

  @override
  void deactivate() {
    try {
      _hideNativeOverlays();
      _showGuide = false;
      _showCoachingOverlay = false;
    } catch (e) {
      _logger.w('Error in deactivate: $e');
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _isDisposing = true;
    try {
      _hideNativeOverlays();
    } catch (e) {
      _logger.w('Error hiding overlays in dispose: $e');
    }
    try {
      final session = arSessionManager;
      arSessionManager = null;
      arObjectManager = null;
      arAnchorManager = null;
      if (session != null) {
        session.dispose().catchError((e) {
          _logger.w('Error during AR dispose: $e');
        });
      }
    } catch (e) {
      _logger.w('Error during AR dispose: $e');
    }
    super.dispose();
  }

  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    try {
      this.arSessionManager = arSessionManager;
      this.arObjectManager = arObjectManager;
      this.arAnchorManager = arAnchorManager;

      this.arSessionManager?.onInitialize(
        showAnimatedGuide: false,
        showFeaturePoints: false,
        showPlanes: true, // Show plane detection overlay (dotted grid)
        showWorldOrigin: false,
        handlePans: true, // Enable pan/drag from anywhere
        handleRotation: false,
        handleTaps: true,
      );
      this.arObjectManager?.onInitialize();

      // Set up gesture handlers
      this.arObjectManager?.onPanStart = onPanStart;
      this.arObjectManager?.onPanChange = onPanChange;
      this.arObjectManager?.onPanEnd = onPanEnd;

      _downloadModel();
    } catch (e, st) {
      _logger.w('Error in onARViewCreated: $e', error: e, stackTrace: st);
    }
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
        position: vector.Vector3(0.0, -1.0, -2.0), // 2m in front, 1m down
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
          // Hide coaching overlay
          _showCoachingOverlay = false;
          // Re-enable manual mode to allow swiping
          _isManualPlacement = true;
          _showGuide = true;
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
        // Keep AR session stable for model display with pans enabled
        if (arSessionManager != null) {
          _logger.d('Enabling manual pan controls after model placement');
          arSessionManager?.onInitialize(
            showAnimatedGuide: false,
            showFeaturePoints: false,
            showPlanes: true, // Keep showing planes for context
            showWorldOrigin: false,
            handlePans: true, // Enable pan/drag
            handleRotation: false,
            handleTaps: true,
          );
          _logger.i('AR session configured for manual dragging');
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
          // Hide coaching overlay
          _showCoachingOverlay = false;
          // Re-enable manual mode to allow swiping
          _isManualPlacement = true;
          _showGuide = true;
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
        // Keep AR session stable for model display with pans enabled
        if (arSessionManager != null) {
          _logger.d('Enabling manual pan controls after model placement at anchor');
          arSessionManager?.onInitialize(
            showAnimatedGuide: false,
            showFeaturePoints: false,
            showPlanes: true, // Keep showing planes for context
            showWorldOrigin: false,
            handlePans: true, // Enable pan/drag
            handleRotation: false,
            handleTaps: true,
          );
          _logger.i('AR session configured for manual dragging');
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

      // Store current position when pan starts
      if (productNode != null) {
        _currentNodePosition = productNode!.position;
        _logger.d('Pan start - Current position: $_currentNodePosition');
      }
    } catch (e, stackTrace) {
      _logger.e('Error in onPanStart', error: e, stackTrace: stackTrace);
    }
  }

  void onPanChange(String nodeName) {
    try {
      // The AR plugin handles the visual dragging in real-time
      // No need to update here - the native layer moves the node
    } catch (e, stackTrace) {
      _logger.e('Error in onPanChange', error: e, stackTrace: stackTrace);
    }
  }

  void onPanEnd(String nodeName, vector.Matrix4 newTransform) {
    try {
      _logger.i('✋ Pan ended on node: $nodeName');
      _logger.d('New transform received: $newTransform');

      // Extract the new position from the transform
      final newPosition = newTransform.getTranslation();
      _logger.d('New position extracted: $newPosition');

      // Update our state to track the new position
      if (mounted && newPosition != null) {
        setState(() {
          _currentNodePosition = newPosition;
          // Update productNode position to sync with native AR position
          if (productNode != null) {
            _logger.d('Updating model position from ${"productNode!.position"} to $newPosition');
            productNode = ARNode(
              type: productNode!.type,
              uri: productNode!.uri,
              scale: _originalScale ?? productNode!.scale,
              position: newPosition,
              rotation: vector.Vector4(1, 0, 0, 0),
            );
            _logger.d('✅ Model position synced after pan');
          }
        });
      }
    } catch (e, stackTrace) {
      _logger.e('Error in onPanEnd', error: e, stackTrace: stackTrace);
    }
  }

  // DISABLED: Manual placement toggle - kept for rollback
  // void _toggleManualPlacement(bool value) {
  //   _logger.i('🔄 Toggling manual placement mode: $value');
  //
  //   setState(() {
  //     _isManualPlacement = value;
  //     // Show guide only when enabling manual placement
  //     if (_isManualPlacement) {
  //       _showGuide = true;
  //     }
  //   });
  //
  //   // Enable/disable pans and rotation based on manual mode
  //   // IMPORTANT: This must be called AFTER the model is placed
  //   if (arSessionManager != null) {
  //     _logger.d(
  //       'Reinitializing AR session with handlePans=$value, handleRotation=$value',
  //     );
  //
  //     arSessionManager?.onInitialize(
  //       showAnimatedGuide: false,
  //       showFeaturePoints: false,
  //       showPlanes: false,
  //       showWorldOrigin: false,
  //       handlePans: value,
  //       handleRotation: value,
  //       handleTaps: true,
  //     );
  //
  //     _logger.i(
  //       'AR session reinitialized. Pans/Rotation ${value ? "ENABLED" : "DISABLED"}',
  //     );
  //
  //     // CRITICAL FIX: Refresh the node when toggling manual mode.
  //     // The native plugin often fails to apply 'draggable' status to existing nodes
  //     // if the session settings change. Re-adding the node forces it to respect the new settings.
  //     if (_isModelPlaced && productNode != null) {
  //       _refreshNode();
  //     }
  //   } else {
  //     _logger.w('Cannot reinitialize - arSessionManager is null');
  //   }
  // }

  /// Graceful exit: tear down AR session then pop. Always pops even if dispose fails.
  Future<void> _exitARView() async {
    if (_isExiting) return;
    _logger.i('🔙 Exiting AR view...');
    _isDisposing = true;

    try {
      // 1) Hide native overlays
      try {
        _hideNativeOverlays();
      } catch (e) {
        _logger.w('Error hiding overlays: $e');
      }

      // 2) Dispose AR session (with timeout so we never hang)
      final session = arSessionManager;
      arSessionManager = null;
      arObjectManager = null;
      arAnchorManager = null;
      if (session != null) {
        try {
          await session.dispose().timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              _logger.w('AR session dispose timed out');
            },
          );
        } catch (e) {
          _logger.w('Error disposing AR session: $e');
        }
      }

      // 3) Brief delay for native cleanup
      try {
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (_) {}
    } catch (e, st) {
      _logger.w('Exit error: $e', error: e, stackTrace: st);
    } finally {
      // Always pop so user can exit even if dispose failed
      if (!mounted) return;
      try {
        setState(() => _isExiting = true);
      } catch (_) {}
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (mounted) Navigator.of(context).pop();
        } catch (e) {
          _logger.w('Error popping: $e');
        }
      });
    }
  }

  /// Refreshes the node by removing and re-adding it.
  /// This fixes issues where the node gets stuck or gestures stop working.
  // DISABLED: Refresh node method - kept for rollback if manual mode is re-enabled
  // void _refreshNode() async {
  //   if (productNode == null || arObjectManager == null) return;
  //
  //   _logger.i('🔄 Refreshing node to apply new interaction settings...');
  //
  //   final oldNode = productNode!;
  //
  //   // Calculate rotation matching current angle
  //   final tempQuat = vector.Quaternion.axisAngle(
  //     vector.Vector3(0, 1, 0),
  //     _rotation,
  //   );
  //
  //   // Create an identical copy
  //   final newNode = ARNode(
  //     type: oldNode.type,
  //     uri: oldNode.uri, // Use the same URI
  //     scale: _originalScale ?? oldNode.scale, // Use original scale if available
  //     position: oldNode.position,
  //     rotation: vector.Vector4(tempQuat.x, tempQuat.y, tempQuat.z, tempQuat.w),
  //   );
  //
  //   // Remove old
  //   await arObjectManager?.removeNode(oldNode);
  //
  //   // Add new (native side will pick up current Drag/Pan settings)
  //   bool? success = await arObjectManager?.addNode(newNode);
  //
  //   if (success == true) {
  //     setState(() {
  //       productNode = newNode;
  //     });
  //     _logger.i('✅ Node refreshed successfully');
  //   } else {
  //     _logger.e('❌ Failed to refresh node');
  //   }
  // }

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

  /// Helper widget to build a coaching step with number badge and instruction
  Widget _buildCoachingStep(String number, String instruction) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFDB022), width: 2),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFFFDB022),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              instruction,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isExiting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        try {
          _exitARView();
        } catch (e, st) {
          _logger.w('Error on back: $e', error: e, stackTrace: st);
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            ARView(
              key: ValueKey(identityHashCode(this)),
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
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: _exitARView,
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
                        // Manual Placement Toggle - HIDDEN: Manual mode now requires explicit toggle
                        // Container(
                        //   padding: const EdgeInsets.symmetric(
                        //     horizontal: 8,
                        //     vertical: 4,
                        //   ),
                        //   decoration: BoxDecoration(
                        //     color: _isManualPlacement
                        //         ? const Color(0xFFFDB022).withValues(alpha: 0.9)
                        //         : Colors.black54,
                        //     borderRadius: BorderRadius.circular(20),
                        //   ),
                        //   child: Row(
                        //     mainAxisSize: MainAxisSize.min,
                        //     children: [
                        //       const Text(
                        //         'Manual',
                        //         style: TextStyle(
                        //           color: Colors.white,
                        //           fontSize: 12,
                        //         ),
                        //       ),
                        //       Switch(
                        //         value: _isManualPlacement,
                        //         onChanged: _toggleManualPlacement,
                        //         activeThumbColor: Colors.white,
                        //         activeTrackColor: Colors.orange,
                        //         inactiveThumbColor: Colors.grey,
                        //         inactiveTrackColor: Colors.grey[800],
                        //         materialTapTargetSize:
                        //             MaterialTapTargetSize.shrinkWrap,
                        //       ),
                        //     ],
                        //   ),
                        // ),
                      ],
                    ),
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
                            style: TextStyle(
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

            // Coaching Overlay - shown initially before model placement
            if (_showCoachingOverlay && !_isModelPlaced)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videocam, color: Colors.white, size: 64),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome to AR View',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Get ready to visualize this product in your space',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Instruction Steps
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildCoachingStep(
                              '1',
                              'Point your camera at the floor or a flat surface',
                            ),
                            const SizedBox(height: 12),
                            _buildCoachingStep(
                              '2',
                              'Tap "Place Item" to place the product',
                            ),
                            const SizedBox(height: 12),
                            _buildCoachingStep(
                              '3',
                              'Swipe to move • Rotate wheel to spin',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _showCoachingOverlay = false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFDB022),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text(
                          'Got It',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Guide Overlay (must be last in Stack for it to appear on top)
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
                            fillColor: const WidgetStatePropertyAll(
                              Colors.white,
                            ),
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
          ],
        ),
      ),
    );
  }
}
