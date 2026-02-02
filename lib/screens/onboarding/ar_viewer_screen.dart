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
import 'package:ar_flutter_plugin_updated/datatypes/hittest_result_types.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
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

  // --- Swipe/Anywhere-move support ---
  bool _isSwipingAnywhere = false;
  Offset? _lastPanScreenPosition;
  Offset? _dragStartScreen;
  vector.Vector3? _dragStartNodePosition;
  ARPlaneAnchor? _currentAnchor;
  DateTime? _lastMoveAt;
  final Duration _moveThrottle = const Duration(
    milliseconds: 100,
  ); // throttle rapid hit tests
  bool _isUpdatingNodePosition = false; // prevent overlapping updates
  bool _canPlaceAtCenter = false;
  Timer? _centerHitTestTimer;
  vector.Matrix4? _centerHitTransform;
  bool _isCapturing = false; // Snapshot loading state
  // ------------------------------------

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

  /// Removes any existing node and its associated anchor from the scene.
  Future<void> _clearExistingModel() async {
    _logger.d('🧹 Clearing existing model and anchors...');
    if (productNode != null) {
      try {
        await arObjectManager?.removeNode(productNode!);
      } catch (e) {
        _logger.w('Error removing node: $e');
      }
      productNode = null;
    }
    if (_currentAnchor != null) {
      try {
        await arAnchorManager?.removeAnchor(_currentAnchor!);
      } catch (e) {
        _logger.w('Error removing anchor: $e');
      }
      _currentAnchor = null;
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
    _centerHitTestTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialPermissions() async {
    _logger.d('Checking storage permissions...');
    if (Platform.isAndroid) {
      // For Android 13+ we need photos permission or just media
      final status = await Permission.storage.request();
      if (status.isPermanentlyDenied) {
        openAppSettings();
      }
    }
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

      // We rely on the GestureDetector in the build method for tap handling
      // because it allows us to handle coordinate scaling (DPI) correctly.
      // this.arSessionManager?.onPlaneOrPointTap = onPlaneOrPointTapped;

      this.arSessionManager?.onInitialize(
        showAnimatedGuide: false,
        showFeaturePoints: false,
        showPlanes: true, // Show plane detection overlay (dotted grid)
        showWorldOrigin: false,
        handlePans:
            false, // Panning handled by overlay to support swipe-anywhere
        handleRotation: false,
        handleTaps: true,
      );
      this.arObjectManager?.onInitialize();

      // Set up gesture handlers
      this.arObjectManager?.onPanStart = onPanStart;
      this.arObjectManager?.onPanChange = onPanChange;
      this.arObjectManager?.onPanEnd = onPanEnd;

      _downloadModel();
      _startCenterHitTestTimer();
      _checkInitialPermissions();
    } catch (e, st) {
      _logger.w('Error in onARViewCreated: $e', error: e, stackTrace: st);
    }
  }

  void _startCenterHitTestTimer() {
    _centerHitTestTimer?.cancel();
    _centerHitTestTimer = Timer.periodic(const Duration(milliseconds: 250), (
      timer,
    ) async {
      if (!mounted || _isModelPlaced || _isBusy || arSessionManager == null)
        return;

      final size = MediaQuery.of(context).size;
      final center = Offset(size.width / 2, size.height / 2);

      final results = await _performHitTestAt(center);
      if (results != null && results.isNotEmpty) {
        if (mounted) {
          setState(() {
            _canPlaceAtCenter = true;
            _centerHitTransform = results.first.worldTransform;
          });
        }
      } else {
        if (mounted && _canPlaceAtCenter) {
          setState(() {
            _canPlaceAtCenter = false;
            _centerHitTransform = null;
          });
        }
      }
    });
  }

  /// Utility to perform hit test at a specific screen point
  Future<List<ARHitTestResult>?> _performHitTestAt(Offset screenPoint) async {
    if (arSessionManager == null) return null;

    try {
      final size = MediaQuery.of(context).size;
      double px = screenPoint.dx.clamp(0.0, size.width);
      double py = screenPoint.dy.clamp(0.0, size.height);

      // On Android, the native hitTest often expects physical pixels.
      // Flutter's screenPoint and size are in logical pixels.
      if (Platform.isAndroid) {
        final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        px *= devicePixelRatio;
        py *= devicePixelRatio;
      }

      // Use the newly implemented native hit test method
      final results = await arSessionManager!.hitTest(px, py);

      if (results.isNotEmpty) {
        // FILTER: Only allow Plane hits and ignore results that are too far away (> 5m)
        // to prevent the model from "going out" or disappearing into the distance.
        final List<ARHitTestResult> planeHits = results.where((hit) {
          return hit.type == ARHitTestResultType.plane && hit.distance < 5.0;
        }).toList();

        if (planeHits.isEmpty) {
          _logger.d(
            'No suitable nearby plane hits found at logical ${screenPoint.dx},${screenPoint.dy}',
          );
          return null;
        }

        _logger.d(
          'Hit test succeeded at logical ${screenPoint.dx},${screenPoint.dy} -> px,py: $px,$py. Found ${planeHits.length} suitable plane hits.',
        );
        return planeHits;
      }
      return null;
    } catch (e, st) {
      _logger.w('Hit test failed: $e', error: e, stackTrace: st);
      return null;
    }
  }

  /// Handle a tap on the screen: place model (if not placed) or move model
  /// to the tapped plane if it already exists.
  Future<void> _handleTapToPlace(Offset screenPoint) async {
    if (_isBusy || _localModelPath == null) return;
    setState(() => _isBusy = true);

    try {
      final results = await _performHitTestAt(screenPoint);
      if (results == null || results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No plane detected at tapped location.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await _clearExistingModel(); // Clear existing model before placing a new one

      final dynamic hit = results.first;
      final newAnchor = ARPlaneAnchor(transformation: hit.worldTransform);
      bool? added = await arAnchorManager?.addAnchor(newAnchor);
      if (added == true) {
        _currentAnchor = newAnchor;
        await _addModelAtAnchor(newAnchor);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add anchor'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, st) {
      _logger.e('Tap-to-place error: $e', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isBusy = false);
    }
  }

  /// Try to move the currently placed node by performing a hit test at the
  /// provided screen point and re-anchoring the node at the hit location.
  Future<void> _tryMoveNodeToScreenPoint(Offset screenPoint) async {
    if (productNode == null ||
        arAnchorManager == null ||
        arObjectManager == null)
      return;

    // Throttle to avoid spamming native
    final now = DateTime.now();
    if (_lastMoveAt != null && now.difference(_lastMoveAt!) < _moveThrottle)
      return;
    _lastMoveAt = now;

    if (_isUpdatingNodePosition) return;
    _isUpdatingNodePosition = true;
    setState(() => _isBusy = true);

    try {
      final results = await _performHitTestAt(screenPoint);
      if (results == null || results.isEmpty) {
        // Fallback: if hit test yields nothing, translate node locally based on
        // screen delta (pan) to provide a reasonable swipe-to-move UX.
        if (_dragStartScreen != null && _dragStartNodePosition != null) {
          _logger.d('Using fallback screen-delta translation (no hit results)');
          final dx = screenPoint.dx - _dragStartScreen!.dx;
          final dy = screenPoint.dy - _dragStartScreen!.dy;

          // Estimate distance factor from anchor translation if available
          double distanceFactor = 1.0;
          try {
            final t = _currentAnchor?.transformation;
            if (t != null) {
              final vector.Vector3 trans = t.getTranslation();
              distanceFactor = trans.length;
            }
          } catch (_) {}

          // Sensitivity tuned experimentally: pixels -> meters
          final double sensitivity =
              0.0015 * (distanceFactor > 0 ? distanceFactor : 1.0);

          final vector.Vector3 newPos = vector.Vector3(
            (_dragStartNodePosition!.x) + (-dx * sensitivity),
            _dragStartNodePosition!.y,
            (_dragStartNodePosition!.z) + (dy * sensitivity),
          );

          final oldNode = productNode!;
          final dynamic oldRotation = oldNode.rotation;
          final vector.Vector4 rotationVector = (oldRotation is vector.Vector4)
              ? oldRotation
              : vector.Vector4(1, 0, 0, 0);

          final newNode = ARNode(
            type: oldNode.type,
            uri: oldNode.uri,
            scale: _originalScale ?? oldNode.scale,
            position: newPos,
            rotation: rotationVector,
          );

          bool? removed = await arObjectManager?.removeNode(oldNode);
          bool? didAdd = false;
          if (removed == true) {
            didAdd = await arObjectManager?.addNode(
              newNode,
              planeAnchor: _currentAnchor,
            );
          } else {
            didAdd = await arObjectManager?.addNode(
              newNode,
              planeAnchor: _currentAnchor,
            );
          }

          if (didAdd == true) {
            productNode = newNode;
            setState(() {
              _isModelPlaced = true;
            });
          } else {
            _logger.w('Fallback move failed - could not add new node');
          }
        }
        _isUpdatingNodePosition = false;
        return;
      }

      final dynamic hit = results.first;

      // 1. CAPTURE properties before clearing
      final oldNodeUri = productNode!.uri;
      final oldNodeType = productNode!.type;
      final oldNodeTransform = productNode!.transform.clone();

      // 2. Clear existing model
      await _clearExistingModel();

      final newAnchor = ARPlaneAnchor(transformation: hit.worldTransform);
      final added = await arAnchorManager?.addAnchor(newAnchor);

      if (added != true) {
        _logger.w('Failed to add anchor for move');
        setState(() {
          _isModelPlaced = false; // Reset state so user can re-place
        });
        _isUpdatingNodePosition = false;
        return;
      }

      // PRESERVE: Use the captured transform (rotation/scale) but zero out translation
      // so it's correctly positioned at the new anchor (0,0,0).
      final moveTransform = oldNodeTransform;
      moveTransform.setTranslation(vector.Vector3.zero());

      final newNode = ARNode(
        type: oldNodeType,
        uri: oldNodeUri,
        transformation: moveTransform,
        position: vector.Vector3(0.0, 0.0, 0.0),
      );

      bool? didAdd = await arObjectManager?.addNode(
        newNode,
        planeAnchor: newAnchor,
      );

      if (didAdd == true) {
        productNode = newNode;
        _currentAnchor = newAnchor;
        setState(() {
          _isModelPlaced = true;
          _showCoachingOverlay = false;
        });
        _logger.d('✅ Node moved and re-anchored successfully');
      } else {
        _logger.w('Failed to add moved node to new anchor');
        setState(() {
          _isModelPlaced = false; // Reset state so user can re-place
        });
      }
    } catch (e, st) {
      _logger.e('Move node error: $e', error: e, stackTrace: st);
      setState(() {
        _isModelPlaced = false; // Fallback reset on error
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingNodePosition = false;
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

      // Perform a fresh hit test at the exact center of the screen right now
      // for maximum precision, rather than relying on the timer-updated transform.
      final size = MediaQuery.of(context).size;
      final center = Offset(size.width / 2, size.height / 2);
      final results = await _performHitTestAt(center);

      vector.Matrix4? targetTransform = _centerHitTransform;
      if (results != null && results.isNotEmpty) {
        targetTransform = results.first.worldTransform;
      }

      // modelScale from Firebase is in centimeters, convert to meters for AR
      final double scaleInCm = widget.modelScale ?? 50.0;
      final double scaleValue = scaleInCm / 100.0; // Convert CM to meters
      final fileName = _localModelPath!.split('/').last;

      _logger.d('🎯 Placing AR Model:');
      _logger.d('   Scale (CM): $scaleInCm -> (Meters): $scaleValue');

      final vector.Vector4 rotationVector = vector.Vector4(1, 0, 0, 0);

      ARNode nodeToPlace = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri: fileName,
        scale: vector.Vector3(scaleValue, scaleValue, scaleValue),
        position: vector.Vector3(
          0.0,
          -1.0,
          -2.0,
        ), // Fallback: 2m in front, 1m down
        rotation: rotationVector,
      );

      _logger.i('🚀 Adding node to AR scene...');

      bool? didAddNode;
      if (targetTransform != null) {
        _logger.i('📍 Using detected plane at center for placement');

        // Ensure scene is clear before adding
        await _clearExistingModel();

        var newAnchor = ARPlaneAnchor(transformation: targetTransform);
        bool? didAddAnchor = await arAnchorManager!.addAnchor(newAnchor);
        if (didAddAnchor == true) {
          _currentAnchor = newAnchor;
          nodeToPlace = ARNode(
            type: nodeToPlace.type,
            uri: nodeToPlace.uri,
            scale: nodeToPlace.scale,
            position: vector.Vector3(0, 0, 0), // At the anchor
            rotation: rotationVector,
          );
          didAddNode = await arObjectManager?.addNode(
            nodeToPlace,
            planeAnchor: newAnchor,
          );
        } else {
          _logger.w(
            'Failed to add anchor for center placement, falling back to world coordinates',
          );
          didAddNode = await arObjectManager?.addNode(nodeToPlace);
        }
      } else {
        _logger.w(
          'No plane detected at center, using fixed world coordinates (floating risk)',
        );
        didAddNode = await arObjectManager?.addNode(nodeToPlace);
      }

      _logger.i('   Result: ${didAddNode == true ? "SUCCESS" : "FAILED"}');

      if (didAddNode ?? false) {
        productNode = nodeToPlace;
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
        // Keep AR session stable for model display; overlay handles panning
        if (arSessionManager != null) {
          _logger.d(
            'Configuring AR session after model placement (overlay-driven pans)',
          );
          arSessionManager?.onInitialize(
            showAnimatedGuide: false,
            showFeaturePoints: false,
            showPlanes: true, // Keep showing planes for context
            showWorldOrigin: false,
            handlePans: false, // Panning handled by overlay
            handleRotation: false,
            handleTaps: true,
          );
          _logger.i('AR session configured for overlay-driven panning');
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
        // Keep AR session stable for model display; overlay handles panning
        if (arSessionManager != null) {
          _logger.d(
            'Configuring AR session after node placed (overlay-driven pans)',
          );
          arSessionManager?.onInitialize(
            showAnimatedGuide: false,
            showFeaturePoints: false,
            showPlanes: true, // Keep showing planes for context
            showWorldOrigin: false,
            handlePans: false, // Panning handled by overlay
            handleRotation: false,
            handleTaps: true,
          );
          _logger.i('AR session configured for overlay-driven panning');
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
      if (mounted) {
        setState(() {
          _currentNodePosition = newPosition;
          // Update productNode position to sync with native AR position
          if (productNode != null) {
            _logger.d(
              'Updating model position from ${productNode!.position} to $newPosition',
            );

            // PRESERVE: Update the position property directly. This triggers the
            // transformationChanged listener in ARObjectManager, which is much
            // more efficient than replacing the entire ARNode object.
            productNode!.position = newPosition;

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

  /// Graceful exit: fire tear-down then pop immediately.
  Future<void> _exitARView() async {
    if (_isExiting) return;
    _isExiting = true;
    _logger.i('🔙 Exiting AR view...');
    _isDisposing = true;

    try {
      // 1) Hide native overlays immediately
      _hideNativeOverlays();

      // 2) Fire-and-forget AR session dispose
      // We don't await this to ensure the UI pops instantly.
      final session = arSessionManager;
      arSessionManager = null;
      arObjectManager = null;
      arAnchorManager = null;
      if (session != null) {
        session.dispose().catchError((e) {
          _logger.w('Background AR dispose error: $e');
        });
      }
    } catch (e) {
      _logger.w('Exit cleanup error: $e');
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
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

      // Update the node's rotation directly on its transform matrix.
      // This is butter-smooth because it triggers the transformationChanged listener
      // in the ARObjectManager without removing/re-adding the node.
      // Using Z-axis rotation as requested.
      productNode!.rotation = vector.Matrix3.rotationY(angle);

      _logger.d('✅ Node rotation updated smoothly');
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

  Widget _buildReticle() {
    return Center(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _canPlaceAtCenter ? 1.0 : 0.5,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _canPlaceAtCenter
                  ? const Color(0xFFFDB022)
                  : Colors.white38,
              width: 2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: _canPlaceAtCenter
                      ? const Color(0xFFFDB022)
                      : Colors.white38,
                  shape: BoxShape.circle,
                ),
              ),
              if (!_canPlaceAtCenter)
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 1,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white24),
                  ),
                ),
            ],
          ),
        ),
      ),
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
            // AR view is underneath an invisible gesture layer that
            // handles swipe-to-move and tap-to-place/move when the plugin
            // does not expose a direct performHitTest method.
            ARView(
              key: ValueKey(identityHashCode(this)),
              onARViewCreated: onARViewCreated,
              planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
            ),

            // Subtle Loading Indicator for Move/Relocate actions
            if (_isBusy && _isModelPlaced && !_isPlacingModel)
              Positioned(
                top: MediaQuery.of(context).padding.top + 70,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFFDB022),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Updating...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Center Reticle
            if (!_isModelPlaced &&
                !_isPlacingModel &&
                !_isBusy &&
                !_showCoachingOverlay)
              _buildReticle(),

            // Full-screen gesture overlay (transparent). Captures pan and tap
            // and translates them into AR hit tests at runtime (dynamic call)
            // to support moving the object by swiping anywhere on screen.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) async {
                  // Convert tap into tap-to-place (if model not placed) or
                  // tap-to-move (if model already placed)
                  final tapPos = details.localPosition;
                  try {
                    if (!_isModelPlaced) {
                      await _handleTapToPlace(tapPos);
                    } else {
                      await _tryMoveNodeToScreenPoint(tapPos);
                    }
                  } catch (e, st) {
                    _logger.w(
                      'Gesture overlay tap error: $e',
                      error: e,
                      stackTrace: st,
                    );
                  }
                },
                onPanStart: (details) {
                  if (!_isModelPlaced || !_isManualPlacement) return;
                  _isSwipingAnywhere = true;
                  _lastPanScreenPosition = details.localPosition;
                  _dragStartScreen = details.localPosition;
                  _dragStartNodePosition = productNode?.position;
                },
                onPanUpdate: (details) async {
                  if (!_isSwipingAnywhere || productNode == null) return;
                  _lastPanScreenPosition = details.localPosition;
                  // First try precise hit-test re-anchoring; if no hit, fall back
                  // to a screen-delta based local translation that feels natural.
                  await _tryMoveNodeToScreenPoint(details.localPosition);
                },
                onPanEnd: (details) {
                  _isSwipingAnywhere = false;
                  _dragStartScreen = null;
                  _dragStartNodePosition = null;
                },
                child: const SizedBox.expand(),
              ),
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
                        if (_isModelPlaced) ...[
                          if (_isCapturing)
                            const SizedBox(
                              width: 40,
                              height: 40,
                              child: Padding(
                                padding: EdgeInsets.all(10.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFFDB022),
                                ),
                              ),
                            )
                          else
                            IconButton(
                              icon: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                              ),
                              onPressed: _takeSnapshot,
                              tooltip: 'Save Photo',
                            ),
                          IconButton(
                            icon: Icon(
                              _isPreviewMode
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPreviewMode = !_isPreviewMode;
                              });
                            },
                          ),
                        ],
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
                    200, // Moved up to clear bottom panel
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Rotate: ${(_rotation * 57.2958).toInt()}°",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          _rotateNode(_rotation + details.delta.dx * 0.01);
                        },
                        child: Container(
                          width: 240,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFFFDB022).withOpacity(0.5),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              12,
                              (index) => Container(
                                width: 2,
                                height: index % 3 == 0 ? 25 : 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Preview Toggle - Floating for Preview Mode only
            if (_isModelPlaced && !_showGuide && _isPreviewMode)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 16,
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _isPreviewMode = !_isPreviewMode;
                    });
                  },
                  icon: const Icon(Icons.visibility_off, color: Colors.white),
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
                            'Point camera at the floor and wait for the reticle to appear.',
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
                              onPressed:
                                  (_localModelPath != null &&
                                      !_isBusy &&
                                      _canPlaceAtCenter)
                                  ? _placeModelAtCenter
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _canPlaceAtCenter
                                    ? const Color(0xFFFDB022)
                                    : Colors.grey[700],
                                disabledBackgroundColor: Colors.grey[800],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: _canPlaceAtCenter
                                  ? const Icon(
                                      Icons.add_location,
                                      color: Colors.black,
                                    )
                                  : const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white54,
                                      ),
                                    ),
                              label: Text(
                                _canPlaceAtCenter
                                    ? 'Place Item'
                                    : 'Scanning for Floor...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _canPlaceAtCenter
                                      ? Colors.black
                                      : Colors.white54,
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
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                _logger.i(
                                  '🔄 User requested manual reset/relocation',
                                );
                                if (productNode != null) {
                                  await arObjectManager?.removeNode(
                                    productNode!,
                                  );
                                }
                                if (_currentAnchor != null) {
                                  await arAnchorManager?.removeAnchor(
                                    _currentAnchor!,
                                  );
                                }
                                setState(() {
                                  productNode = null;
                                  _currentAnchor = null;
                                  _isModelPlaced = false;
                                  _isManualPlacement = false;
                                });
                                _logger.d('✅ AR state reset successfully');
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Remove & Relocate'),
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
                        'Mandaue Foam AR View',
                        textAlign: TextAlign.center,
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
                              'Scan: Slowly move your phone to detect the floor or surface.',
                            ),
                            const SizedBox(height: 12),
                            _buildCoachingStep(
                              '2',
                              'Focus: Align the center reticle where you want the item to be.',
                            ),
                            const SizedBox(height: 12),
                            _buildCoachingStep(
                              '3',
                              'Place: Tap "Place Item" to drop the 3D model into your room.',
                            ),
                            const SizedBox(height: 12),
                            _buildCoachingStep(
                              '4',
                              'Adjust: Swipe to reposition or use the wheel to rotate the item.',
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

  Future<void> _takeSnapshot() async {
    if (arSessionManager == null || _isCapturing) return;

    // 1. Check Permissions
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission required to save photos'),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isCapturing = true);

    try {
      _logger.i('📸 Taking AR snapshot...');

      // Note: ar_session_manager.dart's snapshot() returns Future<ImageProvider>
      // and it uses MemoryImage(result!) where result is Uint8List.
      final imageProvider = await arSessionManager!.snapshot();
      if (imageProvider is! MemoryImage) {
        throw Exception('Snapshot failed - unexpected image type');
      }
      final Uint8List imageBytes = imageProvider.bytes;

      _logger.d('Snapshot captured: ${imageBytes.length} bytes');

      // 2. Process Image (Watermark)
      _logger.d('Applying watermark...');
      final img.Image? baseImage = img.decodeImage(imageBytes);
      if (baseImage == null) throw Exception('Failed to decode captured image');

      // Load Logo Watermark
      img.Image? logoImg;
      try {
        final logoData = await rootBundle.load('assets/images/logo.png');
        logoImg = img.decodeImage(logoData.buffer.asUint8List());
      } catch (e) {
        _logger.w('Logo asset not found for watermark: $e');
      }

      if (logoImg != null) {
        // Resize logo to be ~15% of the image width
        final watermarkWidth = (baseImage.width * 0.15).toInt();
        final resizedLogo = img.copyResize(logoImg, width: watermarkWidth);

        // Position at bottom-right with 40px margin
        final x = baseImage.width - resizedLogo.width - 40;
        final y = baseImage.height - resizedLogo.height - 40;

        img.compositeImage(baseImage, resizedLogo, dstX: x, dstY: y);
      }

      // 3. Save to /Pictures/MandaueFoam
      String savePath = '';
      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Pictures/MandaueFoam');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        savePath = '${directory.path}/MandaueFoam_AR_$timestamp.jpg';
      } else {
        // iOS/Other fallback
        final directory = await getApplicationDocumentsDirectory();
        savePath =
            '${directory.path}/AR_${DateTime.now().millisecondsSinceEpoch}.jpg';
      }

      final File file = File(savePath);
      await file.writeAsBytes(img.encodeJpg(baseImage, quality: 95));

      _logger.i('✅ Image saved to: $savePath');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Photo saved to $savePath')),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, st) {
      _logger.e('Failed to take snapshot: $e', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }
}
