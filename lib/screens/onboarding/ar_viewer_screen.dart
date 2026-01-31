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
import '../../services/filebase_service.dart';

class ARViewerScreen extends StatefulWidget {
  final String productName;
  final String modelUrl;

  const ARViewerScreen({
    super.key,
    required this.productName,
    required this.modelUrl,
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

    this.arSessionManager?.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: "Images/triangle.png",
      showWorldOrigin: false,
    );
    this.arObjectManager?.onInitialize();
  }

  Future<void> _addModel() async {
    if (arObjectManager == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AR is still initializing...')),
      );
      return;
    }

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loading 3D model...'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Download and cache the model
      final localPath = await _downloadModel();
      if (localPath == null) {
        print("localPath: ${localPath}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load 3D model'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final newNode = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri: localPath,
        scale: vector.Vector3(0.2, 0.2, 0.2),
        position: vector.Vector3(0.0, 0.0, -0.5),
      );

      bool? didAddModel = await arObjectManager?.addNode(newNode);
      if (didAddModel ?? false) {
        productNode = newNode;
        setState(() {
          _isModelPlaced = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.productName} placed in AR!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to place model in AR'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error adding model: $e');
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
      print('🔍 Model URL received: ${widget.modelUrl}');
      print('🔍 Model URL type: ${widget.modelUrl.runtimeType}');

      final fileName = widget.modelUrl.split('/').last;
      final docDir = await getApplicationDocumentsDirectory();
      final filePath = '${docDir.path}/$fileName';
      final file = File(filePath);

      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      // Return cached file if it exists
      if (await file.exists()) {
        print('📦 Using cached model: $filePath');
        setState(() {
          _isDownloading = false;
          _downloadProgress = 1.0;
        });
        return fileName;
      }

      // Download the model using FilebaseService for proper S3 authentication
      print('⬇️  Downloading 3D model from: ${widget.modelUrl}');
      final filebaseService = FilebaseService();
      final downloadedPath = await filebaseService.downloadModelFile(
        modelUrl: widget.modelUrl,
        localFilePath: filePath,
        onProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      setState(() {
        _isDownloading = false;
      });

      if (downloadedPath != null) {
        print('✅ Model downloaded and cached: $downloadedPath');
        return fileName;
      } else {
        print('❌ Failed to download model');
        return null;
      }
    } catch (e) {
      print('❌ Error downloading model: $e');
      setState(() {
        _isDownloading = false;
      });
      return null;
    }
  }

  Future<void> _removeModel() async {
    if (productNode != null && arObjectManager != null) {
      await arObjectManager?.removeNode(productNode!);
      setState(() {
        _isModelPlaced = false;
        productNode = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${widget.productName} - AR View'),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
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
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.productName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isDownloading
                          ? 'Please wait while we download the 3D model.'
                          : _isModelPlaced
                          ? 'Model placed! Move around to view from different angles.'
                          : 'Point your camera at a flat surface to place the item.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (!_isModelPlaced)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _addModel,
                                icon: const Icon(Icons.add),
                                label: const Text('Place Item'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFDB022),
                                  foregroundColor: Colors.black,
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _removeModel,
                                icon: const Icon(Icons.delete),
                                label: const Text('Remove Item'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
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
