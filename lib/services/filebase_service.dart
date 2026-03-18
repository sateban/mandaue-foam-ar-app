import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:minio/minio.dart';
import 'package:minio/io.dart';
import 'package:crypto/crypto.dart';

class FilebaseService {
  static final FilebaseService _instance = FilebaseService._internal();
  late String _apiKey;
  late String _apiSecret;
  late String _bucketName;
  late String _region;
  late Minio _minioClient;

  final Map<String, Uint8List> _imageCache = {};

  final Map<String, Future<Uint8List?>> _pendingDownloads = {};

  factory FilebaseService() {
    return _instance;
  }

  FilebaseService._internal();

  static Future<void> initialize() async {
    final instance = FilebaseService();
    try {
      final configString = await rootBundle.loadString('filebase_config.json');
      final config = jsonDecode(configString);
      final filebaseConfig = config['filebase'] ?? {};

      instance._apiKey = filebaseConfig['api_key'] ?? '';
      instance._apiSecret = filebaseConfig['api_secret'] ?? '';
      instance._bucketName = filebaseConfig['bucket_name'] ?? '';
      instance._region = filebaseConfig['region'] ?? 'us-east-1';

      instance._minioClient = Minio(
        endPoint: 's3.filebase.com',
        accessKey: instance._apiKey,
        secretKey: instance._apiSecret,
        useSSL: true,
        region: instance._region,
      );

      print('✓ Filebase service initialized successfully');
      print(
        '   API Key: ${instance._apiKey.substring(0, 5)}...${instance._apiKey.substring(instance._apiKey.length - 5)}',
      );
      print('   Bucket: ${instance._bucketName}');
      print('   Region: ${instance._region}');
    } catch (e) {
      print('✗ Error initializing Filebase: $e');
      rethrow;
    }
  }

  Future<String?> buildPresignedImageUrl(String objectPath) async {
    try {
      if (objectPath.isEmpty) return null;

      print('DEBUG: Generating presigned URL for: $objectPath');

      final presignedUrl = await _minioClient.presignedGetObject(
        _bucketName,
        objectPath,
        expires: 7 * 24 * 60 * 60,
      );

      print('✓ Presigned URL generated (valid 7 days): $presignedUrl');
      return presignedUrl;
    } catch (e) {
      print('✗ Error generating presigned URL: $e');
      return null;
    }
  }

  Future<String?> ensurePresignedUrl(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;

    try {
      if (imageUrl.contains('X-Amz-Signature')) {
        print('DEBUG: URL already presigned, using as-is');
        return imageUrl;
      }

      print('DEBUG: Converting direct URL to presigned URL');

      final uri = Uri.parse(imageUrl);
      String objectPath = uri.path;

      if (objectPath.startsWith('/')) {
        objectPath = objectPath.substring(1);
      }

      print('DEBUG: Extracted object path: $objectPath');

      return await buildPresignedImageUrl(objectPath);
    } catch (e) {
      print('✗ Error converting URL to presigned: $e');
      return imageUrl;
    }
  }

  String buildFilebaseImageUrl(String relativePath) {
    return 'https://$_bucketName.s3.filebase.com/$relativePath';
  }

  List<Map<String, dynamic>> transformProductsWithFilebaseUrls(
    List<Map<String, dynamic>> products,
  ) {
    return products.map((product) {
      final transformedProduct = Map<String, dynamic>.from(product);

      if (product['imageUrl'] is String && product['imageUrl'].isNotEmpty) {
        final imageUrl = product['imageUrl'] as String;

        if (imageUrl.startsWith('http')) {
          transformedProduct['imageUrl'] = imageUrl;
        } else {
          transformedProduct['imageUrl'] = buildFilebaseImageUrl(imageUrl);
        }
      }

      if (product['modelUrl'] is String && product['modelUrl'].isNotEmpty) {
        final modelUrl = product['modelUrl'] as String;

        if (modelUrl.startsWith('http')) {
          transformedProduct['modelUrl'] = modelUrl;
        } else {
          transformedProduct['modelUrl'] = buildFilebaseImageUrl(modelUrl);
        }
      }

      if (product['variation'] is Map) {
        final variations = Map<String, dynamic>.from(product['variation']);
        final transformedVariations = <String, dynamic>{};

        variations.forEach((color, details) {
          if (details is Map) {
            final transformedDetails = Map<String, dynamic>.from(details);

            if (details['imageUrl'] is String &&
                details['imageUrl'].isNotEmpty) {
              final imageUrl = details['imageUrl'] as String;
              transformedDetails['imageUrl'] = imageUrl.startsWith('http')
                  ? imageUrl
                  : buildFilebaseImageUrl(imageUrl);
            }

            if (details['modelUrl'] is String &&
                details['modelUrl'].isNotEmpty) {
              final modelUrl = details['modelUrl'] as String;
              transformedDetails['modelUrl'] = modelUrl.startsWith('http')
                  ? modelUrl
                  : buildFilebaseImageUrl(modelUrl);
            }

            transformedVariations[color] = transformedDetails;
          }
        });
        transformedProduct['variation'] = transformedVariations;
      }

      return transformedProduct;
    }).toList();
  }

  Uint8List? getCachedImageBytes(String imageUrl) {
    if (imageUrl.isEmpty) return null;

    if (_imageCache.containsKey(imageUrl)) {
      print('✨ Using cached image: ${imageUrl.split('/').last}');
      return _imageCache[imageUrl];
    }

    print(
      '📥 Image not cached, will download if needed: ${imageUrl.split('/').last}',
    );
    return null;
  }

  Future<Uint8List?> getImageBytes(String imageUrl) async {
    try {
      if (imageUrl.isEmpty) return null;

      if (_imageCache.containsKey(imageUrl)) {
        print('✨ Image cached (no re-download): ${imageUrl.split('/').last}');
        return _imageCache[imageUrl];
      }

      if (_pendingDownloads.containsKey(imageUrl)) {
        print(
          '⏳ Waiting for in-progress download: ${imageUrl.split('/').last}',
        );
        return _pendingDownloads[imageUrl];
      }

      print('\n🔍 Fetching Image: $imageUrl');

      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final host = uri.host;

      String objectPath;

      if (host == 's3.filebase.com') {
        if (pathSegments.length < 2) {
          print('❌ Invalid URL format: $imageUrl');
          return null;
        }
        objectPath = pathSegments.sublist(1).join('/');
      } else if (host.endsWith('.s3.filebase.com')) {
        objectPath = pathSegments.join('/');
      } else if (pathSegments.isNotEmpty && pathSegments[0] == _bucketName) {
        objectPath = pathSegments.sublist(1).join('/');
      } else if (pathSegments.isNotEmpty) {
        objectPath = pathSegments.join('/');
      } else {
        print('❌ Invalid URL format: $imageUrl');
        return null;
      }

      print('📋 Bucket: $_bucketName');
      print('📋 Object: $objectPath');

      final downloadFuture = _downloadAndCacheImage(imageUrl, objectPath);

      _pendingDownloads[imageUrl] = downloadFuture;

      final result = await downloadFuture;

      _pendingDownloads.remove(imageUrl);

      if (result != null) {
        _imageCache[imageUrl] = result;
      }

      return result;
    } catch (e) {
      print('❌ Error fetching image: $e');
      return null;
    }
  }

  Future<Uint8List?> _downloadAndCacheImage(
    String imageUrl,
    String objectPath,
  ) async {
    try {
      final stream = await _minioClient.getObject(_bucketName, objectPath);

      print('✅ Object retrieved successfully');
      print('📊 Content Length: ${stream.contentLength}');

      final bytes = await stream.toList();
      final data = bytes.expand((chunk) => chunk).toList();
      final result = Uint8List.fromList(data);

      print('✅ Image cached (${data.length} bytes)');
      return result;
    } catch (e) {
      print('❌ Error downloading image: $e');
      return null;
    }
  }

  Future<void> preCacheImages(List<String> imageUrls) async {
    print('\n📥 Pre-caching ${imageUrls.length} hero banner images...');

    final stopwatch = Stopwatch()..start();

    final futures = <Future<void>>[];

    for (final url in imageUrls) {
      if (url.isNotEmpty && !_imageCache.containsKey(url)) {
        futures.add(
          getImageBytes(url).then((_) {
          }),
        );
      }
    }

    try {
      await Future.wait(
        futures,
        eagerError: false,
      ).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      print('⚠️  Pre-cache timeout - some images may still be loading');
    }

    stopwatch.stop();
    final cached = imageUrls
        .where((url) => url.isNotEmpty && _imageCache.containsKey(url))
        .length;
    print(
      '✨ Pre-cache complete: $cached/${imageUrls.length} images (${stopwatch.elapsedMilliseconds}ms)',
    );
  }

  void clearImageCache() {
    _imageCache.clear();
    print('🗑️  Image cache cleared');
  }

  Map<String, dynamic> getCacheStats() {
    int totalBytes = 0;
    for (final bytes in _imageCache.values) {
      totalBytes += bytes.length;
    }
    return {
      'count': _imageCache.length,
      'totalBytes': totalBytes,
      'totalMB': (totalBytes / (1024 * 1024)).toStringAsFixed(2),
    };
  }

  Future<String?> downloadModelFile({
    required String modelUrl,
    required String localFilePath,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      if (modelUrl.isEmpty) return null;

      print('\n🔍 Downloading 3D Model: $modelUrl');

      final uri = Uri.parse(modelUrl);
      final pathSegments = uri.pathSegments;
      final host = uri.host;

      String objectPath;

      if (host == 's3.filebase.com') {
        if (pathSegments.length < 2) {
          print('❌ Invalid URL format: $modelUrl');
          return null;
        }
        objectPath = pathSegments.sublist(1).join('/');
      } else if (host.endsWith('.s3.filebase.com')) {
        objectPath = pathSegments.join('/');
      } else if (pathSegments.isNotEmpty && pathSegments[0] == _bucketName) {
        objectPath = pathSegments.sublist(1).join('/');
      } else if (pathSegments.isNotEmpty) {
        objectPath = pathSegments.join('/');
      } else {
        print('❌ Invalid URL format: $modelUrl');
        return null;
      }

      print('📋 Bucket: $_bucketName');
      print('📋 Object: $objectPath');
      print('📋 Save to: $localFilePath');

      int totalBytes = -1;
      try {
        final stat = await _minioClient.statObject(_bucketName, objectPath);
        totalBytes = stat.size ?? -1;
      } catch (e) {
        print('⚠️ Could not get object stats: $e');
      }

      final stream = await _minioClient.getObject(_bucketName, objectPath);

      final file = File(localFilePath);
      final sink = file.openWrite();

      int receivedBytes = 0;
      await stream.listen((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null && totalBytes > 0) {
          onProgress(receivedBytes, totalBytes);
        }
      }, cancelOnError: true).asFuture();

      await sink.flush();
      await sink.close();

      print('✅ Model downloaded successfully: $localFilePath');
      return localFilePath;
    } catch (e) {
      print('❌ Error downloading model: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> testCredentials() async {
    try {
      print('\n🔐 === TESTING FILEBASE CREDENTIALS ===');
      print(
        'API Key: ${_apiKey.substring(0, 5)}...${_apiKey.substring(_apiKey.length - 5)}',
      );
      print('Endpoint: s3.filebase.com');
      print('Bucket: $_bucketName');
      print('Region: $_region');

      final exists = await _minioClient.bucketExists(_bucketName);

      if (exists) {
        print('✅ Bucket exists and is accessible');

        print('📤 Listing objects in bucket...');
        var objectCount = 0;
        await _minioClient.listObjects(_bucketName).forEach((chunk) {
          objectCount += chunk.objects.length;
        });

        print('✅ Listed $objectCount objects in bucket');

        return {
          'statusCode': 200,
          'success': true,
          'message': 'Credentials valid - bucket accessible',
          'bucketExists': true,
          'objectCount': objectCount,
        };
      } else {
        print('❌ Bucket does not exist or is not accessible');
        return {
          'statusCode': 404,
          'success': false,
          'message': 'Bucket not found or not accessible',
          'bucketExists': false,
        };
      }
    } catch (e) {
      print('❌ Error: $e');
      return {'statusCode': 403, 'success': false, 'message': e.toString()};
    }
  }

  Future<bool> updateFileMeta({
    required String objectPath,
    required Map<String, String> metadata,
  }) async {
    try {
      print('\n🔁 updateFileMeta called for: $objectPath');
      print('   Metadata: $metadata');
      return false;
    } catch (e) {
      print('❌ Error updating metadata: $e');
      return false;
    }
  }

  Future<String?> uploadFile({
    required String filePath,
    required String fileName,
    String? folderPath,
    Map<String, String> metadata = const {},
  }) async {
    try {
      final objectPath = folderPath != null
          ? '$folderPath/$fileName'
          : fileName;

      print('\n📤 Uploading to Filebase:');
      print('   Bucket: $_bucketName');
      print('   Object: $objectPath');

      final etag = await _minioClient.fPutObject(
        _bucketName,
        objectPath,
        filePath,
        metadata: metadata,
      );

      print('✅ File uploaded successfully');
      print('   ETag: $etag');
      return objectPath;
    } catch (e) {
      print('❌ Upload failed: $e');
      return null;
    }
  }

  Future<bool> downloadFile({
    required String objectPath,
    required String localSavePath,
  }) async {
    try {
      print('\n📥 Downloading from Filebase:');
      print('   Bucket: $_bucketName');
      print('   Object: $objectPath');
      print('   Save to: $localSavePath');

      await _minioClient.fGetObject(_bucketName, objectPath, localSavePath);

      print('✅ File downloaded successfully');
      return true;
    } catch (e) {
      print('❌ Download failed: $e');
      return false;
    }
  }

  Future<bool> deleteFile(String objectPath) async {
    try {
      print('\n🗑️  Deleting from Filebase:');
      print('   Bucket: $_bucketName');
      print('   Object: $objectPath');

      await _minioClient.removeObject(_bucketName, objectPath);

      print('✅ File deleted successfully');
      return true;
    } catch (e) {
      print('❌ Delete failed: $e');
      return false;
    }
  }

  Future<List<String>> listFiles(String folderPath) async {
    try {
      print('\n📋 Listing files in: $folderPath');

      final files = <String>[];
      await _minioClient.listObjects(_bucketName, prefix: folderPath).forEach((
        chunk,
      ) {
        for (var obj in chunk.objects) {
          if (obj.key != null) {
            files.add(obj.key!);
          }
        }
      });

      print('✅ Found ${files.length} files');
      return files;
    } catch (e) {
      print('❌ List failed: $e');
      return [];
    }
  }

  Future<bool> fileExists(String objectPath) async {
    try {
      await _minioClient.statObject(_bucketName, objectPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<int?> getFileSize(String objectPath) async {
    try {
      final stat = await _minioClient.statObject(_bucketName, objectPath);
      return stat.size;
    } catch (e) {
      print('Error getting file size: $e');
      return null;
    }
  }

  Future<String?> generatePresignedUrl(
    String objectPath, {
    int expirationSeconds = 3600,
  }) async {
    try {
      final url = await _minioClient.presignedGetObject(
        _bucketName,
        objectPath,
        expires: expirationSeconds,
      );
      return url;
    } catch (e) {
      print('Error generating presigned URL: $e');
      return null;
    }
  }

  String getUniqueFileName(String url) {
    if (url.isEmpty) return 'unknown_file';
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final fileName = path.split('/').last;

      final bytes = utf8.encode(url);
      final hash = sha256.convert(bytes).toString().substring(0, 8);

      if (fileName.contains('.')) {
        final parts = fileName.split('.');
        final ext = parts.last;
        final name = parts.sublist(0, parts.length - 1).join('.');
        return '${name}_$hash.$ext';
      }
      return '${fileName}_$hash';
    } catch (e) {
      return 'model_${DateTime.now().millisecondsSinceEpoch}.glb';
    }
  }

  String get apiKey => _apiKey;
  String get apiSecret => _apiSecret;
  String get bucketName => _bucketName;
  String get region => _region;
}
