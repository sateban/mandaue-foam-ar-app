import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:minio/minio.dart';
import 'package:minio/io.dart';

/// Filebase Service for S3-compatible storage using official MinIO package
/// Handles all CRUD operations for file management
class FilebaseService {
  static final FilebaseService _instance = FilebaseService._internal();
  late String _apiKey;
  late String _apiSecret;
  late String _bucketName;
  late String _region;
  late Minio _minioClient;

  /// Image cache to avoid re-downloading: URL -> Uint8List
  final Map<String, Uint8List> _imageCache = {};

  /// Pending download futures to avoid duplicate requests
  final Map<String, Future<Uint8List?>> _pendingDownloads = {};

  factory FilebaseService() {
    return _instance;
  }

  FilebaseService._internal();

  /// Initialize Filebase service with configuration
  /// Uses official MinIO client for proper S3 compatibility
  static Future<void> initialize() async {
    final instance = FilebaseService();
    try {
      // Load configuration from filebase_config.json
      final configString = await rootBundle.loadString('filebase_config.json');
      final config = jsonDecode(configString);
      final filebaseConfig = config['filebase'] ?? {};

      instance._apiKey = filebaseConfig['api_key'] ?? '';
      instance._apiSecret = filebaseConfig['api_secret'] ?? '';
      instance._bucketName = filebaseConfig['bucket_name'] ?? '';
      instance._region = filebaseConfig['region'] ?? 'us-east-1';

      // Initialize MinIO client with Filebase S3 endpoint
      // Note: Filebase uses s3.filebase.com as the endpoint, not bucket-specific
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

  /// Build Filebase image URL from relative path
  /// Uses presigned URLs (temporary signed access) for secure file access
  /// Presigned URLs are valid for 7 days and don't require bucket to be public
  Future<String?> buildPresignedImageUrl(String objectPath) async {
    try {
      if (objectPath.isEmpty) return null;

      print('DEBUG: Generating presigned URL for: $objectPath');

      // Generate presigned GET URL valid for 7 days (604800 seconds)
      final presignedUrl = await _minioClient.presignedGetObject(
        _bucketName,
        objectPath,
        expires: 7 * 24 * 60 * 60, // 7 days in seconds
      );

      print('✓ Presigned URL generated (valid 7 days): $presignedUrl');
      return presignedUrl;
    } catch (e) {
      print('✗ Error generating presigned URL: $e');
      return null;
    }
  }

  /// Convert direct URL to presigned URL if needed
  /// If URL already has presigned parameters, return as-is
  /// If URL is a direct link, regenerate with presigned signature
  Future<String?> ensurePresignedUrl(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;

    try {
      // Check if already presigned (contains signature parameter)
      if (imageUrl.contains('X-Amz-Signature')) {
        print('DEBUG: URL already presigned, using as-is');
        return imageUrl;
      }

      print('DEBUG: Converting direct URL to presigned URL');

      // Extract object path from URL
      // URLs look like: https://bucket.s3.filebase.com/path/to/object
      final uri = Uri.parse(imageUrl);
      String objectPath = uri.path;

      // Remove leading slash if present
      if (objectPath.startsWith('/')) {
        objectPath = objectPath.substring(1);
      }

      print('DEBUG: Extracted object path: $objectPath');

      // Generate presigned URL
      return await buildPresignedImageUrl(objectPath);
    } catch (e) {
      print('✗ Error converting URL to presigned: $e');
      return imageUrl; // Return original URL if conversion fails
    }
  }

  /// Build direct public URL (only works if bucket is public)
  /// For private buckets, use buildPresignedImageUrl instead
  String buildFilebaseImageUrl(String relativePath) {
    return 'https://$_bucketName.s3.filebase.com/$relativePath';
  }

  /// Transform Firebase product data with Filebase image URLs
  /// Converts relative image paths to full Filebase URLs
  List<Map<String, dynamic>> transformProductsWithFilebaseUrls(
    List<Map<String, dynamic>> products,
  ) {
    return products.map((product) {
      final transformedProduct = Map<String, dynamic>.from(product);

      // Transform imageUrl
      if (product['imageUrl'] is String && product['imageUrl'].isNotEmpty) {
        final imageUrl = product['imageUrl'] as String;

        // If already a full URL, use as-is
        if (imageUrl.startsWith('http')) {
          transformedProduct['imageUrl'] = imageUrl;
        } else {
          // Convert relative path to full Filebase URL
          transformedProduct['imageUrl'] = buildFilebaseImageUrl(imageUrl);
        }
      }

      // Transform modelUrl (for 3D models in AR)
      if (product['modelUrl'] is String && product['modelUrl'].isNotEmpty) {
        final modelUrl = product['modelUrl'] as String;

        // If already a full URL, use as-is
        if (modelUrl.startsWith('http')) {
          transformedProduct['modelUrl'] = modelUrl;
        } else {
          // Convert relative path to full Filebase URL
          transformedProduct['modelUrl'] = buildFilebaseImageUrl(modelUrl);
        }
      }

      // Transform variations
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

  /// Get image bytes from Filebase with proper authentication
  /// Uses MinIO client for secure S3-compatible access
  /// Implements caching and deduplication to minimize data usage
  /// Get cached image bytes without downloading
  /// Returns null if image is not in cache
  /// Use this to check if image is already cached before displaying
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

      // Check cache first - avoid re-downloading
      if (_imageCache.containsKey(imageUrl)) {
        print('✨ Image cached (no re-download): ${imageUrl.split('/').last}');
        return _imageCache[imageUrl];
      }

      // Check if download is already in progress - share the future
      if (_pendingDownloads.containsKey(imageUrl)) {
        print(
          '⏳ Waiting for in-progress download: ${imageUrl.split('/').last}',
        );
        return _pendingDownloads[imageUrl];
      }

      print('\n🔍 Fetching Image: $imageUrl');

      // Extract object name from URL and support both URL formats:
      // 1) https://s3.filebase.com/<bucket>/<path/to/object>
      // 2) https://<bucket>.s3.filebase.com/<path/to/object>
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final host = uri.host;

      String objectPath;

      if (host == 's3.filebase.com') {
        // style 1: bucket is first path segment
        if (pathSegments.length < 2) {
          print('❌ Invalid URL format: $imageUrl');
          return null;
        }
        objectPath = pathSegments.sublist(1).join('/');
      } else if (host.endsWith('.s3.filebase.com')) {
        // style 2: bucket is subdomain
        objectPath = pathSegments.join('/');
      } else if (pathSegments.isNotEmpty && pathSegments[0] == _bucketName) {
        // fallback: path begins with bucket name
        objectPath = pathSegments.sublist(1).join('/');
      } else if (pathSegments.isNotEmpty) {
        // last-resort fallback: use full path
        objectPath = pathSegments.join('/');
      } else {
        print('❌ Invalid URL format: $imageUrl');
        return null;
      }

      print('📋 Bucket: $_bucketName');
      print('📋 Object: $objectPath');

      // Create download future
      final downloadFuture = _downloadAndCacheImage(imageUrl, objectPath);

      // Track this download to prevent duplicate requests
      _pendingDownloads[imageUrl] = downloadFuture;

      // Wait for download and cache result
      final result = await downloadFuture;

      // Remove from pending once complete
      _pendingDownloads.remove(imageUrl);

      // Cache the result if successful
      if (result != null) {
        _imageCache[imageUrl] = result;
      }

      return result;
    } catch (e) {
      print('❌ Error fetching image: $e');
      return null;
    }
  }

  /// Helper method to download and cache image bytes
  Future<Uint8List?> _downloadAndCacheImage(
    String imageUrl,
    String objectPath,
  ) async {
    try {
      // Use MinIO to get the object
      final stream = await _minioClient.getObject(_bucketName, objectPath);

      print('✅ Object retrieved successfully');
      print('📊 Content Length: ${stream.contentLength}');

      // Convert stream to bytes
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

  /// Pre-cache multiple images to avoid delays during slideshow
  /// Useful for hero banners and frequently used images
  Future<void> preCacheImages(List<String> imageUrls) async {
    print('\n📥 Pre-caching ${imageUrls.length} hero banner images...');

    final stopwatch = Stopwatch()..start();

    // Download all images in parallel for speed
    final futures = <Future<void>>[];

    for (final url in imageUrls) {
      if (url.isNotEmpty && !_imageCache.containsKey(url)) {
        futures.add(
          getImageBytes(url).then((_) {
            // Result already cached in getImageBytes
          }),
        );
      }
    }

    // Wait for all downloads (with timeout to prevent hanging)
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

  /// Clear image cache to free memory
  void clearImageCache() {
    _imageCache.clear();
    print('🗑️  Image cache cleared');
  }

  /// Get cache statistics
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

  /// Download 3D model file from Filebase with proper authentication
  /// Returns the local file path where the model was saved
  Future<String?> downloadModelFile({
    required String modelUrl,
    required String localFilePath,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      if (modelUrl.isEmpty) return null;

      print('\n🔍 Downloading 3D Model: $modelUrl');

      // Extract object path from URL (same logic as getImageBytes)
      final uri = Uri.parse(modelUrl);
      final pathSegments = uri.pathSegments;
      final host = uri.host;

      String objectPath;

      if (host == 's3.filebase.com') {
        // style 1: bucket is first path segment
        if (pathSegments.length < 2) {
          print('❌ Invalid URL format: $modelUrl');
          return null;
        }
        objectPath = pathSegments.sublist(1).join('/');
      } else if (host.endsWith('.s3.filebase.com')) {
        // style 2: bucket is subdomain
        objectPath = pathSegments.join('/');
      } else if (pathSegments.isNotEmpty && pathSegments[0] == _bucketName) {
        // fallback: path begins with bucket name
        objectPath = pathSegments.sublist(1).join('/');
      } else if (pathSegments.isNotEmpty) {
        // last-resort fallback: use full path
        objectPath = pathSegments.join('/');
      } else {
        print('❌ Invalid URL format: $modelUrl');
        return null;
      }

      print('📋 Bucket: $_bucketName');
      print('📋 Object: $objectPath');
      print('📋 Save to: $localFilePath');

      // Get object metadata for size
      int totalBytes = -1;
      try {
        final stat = await _minioClient.statObject(_bucketName, objectPath);
        totalBytes = stat.size ?? -1;
      } catch (e) {
        print('⚠️ Could not get object stats: $e');
      }

      // Use MinIO getObject (stream) instead of fGetObject to track progress
      final stream = await _minioClient.getObject(_bucketName, objectPath);

      final file = File(localFilePath);
      final sink = file.openWrite();

      // Handle the stream and track progress
      int receivedBytes = 0;
      await stream.listen((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null && totalBytes > 0) {
          onProgress(receivedBytes, totalBytes);
        }
      }, cancelOnError: true).asFuture();

      // Ensure sink is fully flushed and closed
      await sink.flush();
      await sink.close();

      print('✅ Model downloaded successfully: $localFilePath');
      return localFilePath;
    } catch (e) {
      print('❌ Error downloading model: $e');
      return null;
    }
  }

  /// Test if credentials are valid by checking bucket access
  Future<Map<String, dynamic>> testCredentials() async {
    try {
      print('\n🔐 === TESTING FILEBASE CREDENTIALS ===');
      print(
        'API Key: ${_apiKey.substring(0, 5)}...${_apiKey.substring(_apiKey.length - 5)}',
      );
      print('Endpoint: s3.filebase.com');
      print('Bucket: $_bucketName');
      print('Region: $_region');

      // Check if bucket exists
      print('\n📤 Checking bucket access...');
      final exists = await _minioClient.bucketExists(_bucketName);

      if (exists) {
        print('✅ Bucket exists and is accessible');

        // Try to list objects to verify full access
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

  /// Update metadata for an existing object (best-effort/stub)
  /// Note: Some S3-compatible servers require copying the object to itself
  /// with metadata replacement. This implementation currently logs intent
  /// and returns false by default. Replace with a proper copy-with-metadata
  /// implementation when needed.
  Future<bool> updateFileMeta({
    required String objectPath,
    required Map<String, String> metadata,
  }) async {
    try {
      print('\n🔁 updateFileMeta called for: $objectPath');
      print('   Metadata: $metadata');
      // TODO: Implement actual metadata update using copyObject or equivalent
      // Returning false to indicate metadata was not changed by the stub.
      return false;
    } catch (e) {
      print('❌ Error updating metadata: $e');
      return false;
    }
  }

  /// Upload file to Filebase
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

  /// Download file from Filebase
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

  /// Delete file from Filebase
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

  /// List files in bucket
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

  /// Check if file exists
  Future<bool> fileExists(String objectPath) async {
    try {
      await _minioClient.statObject(_bucketName, objectPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get file size
  Future<int?> getFileSize(String objectPath) async {
    try {
      final stat = await _minioClient.statObject(_bucketName, objectPath);
      return stat.size;
    } catch (e) {
      print('Error getting file size: $e');
      return null;
    }
  }

  /// Generate presigned URL for temporary access (1 hour by default)
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

  /// Get a unique filename from a URL or object path to prevent collisions
  String getUniqueFileName(String url) {
    if (url.isEmpty) return 'unknown_file';
    try {
      final uri = Uri.parse(url);
      // Remove query parameters which might contain tokens
      final path = uri.path;
      // Replace slashes with underscores to create a flat unique filename
      // and remove leading slash
      return path.replaceFirst('/', '').replaceAll('/', '_');
    } catch (e) {
      // Fallback: simple split if URL is not a valid URI
      return url.split('/').last;
    }
  }

  // Getters
  String get apiKey => _apiKey;
  String get apiSecret => _apiSecret;
  String get bucketName => _bucketName;
  String get region => _region;
}
