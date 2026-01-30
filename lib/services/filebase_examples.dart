import 'dart:io';
import 'filebase_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

/// Example implementations for Filebase integration
/// These are practical examples you can copy and adapt for your app

// ============================================================================
// EXAMPLE 1: Simple File Upload
// ============================================================================

class FileUploadExample {
  /// Upload a single file to Filebase
  static Future<void> uploadSingleFile() async {
    try {
      final file = File('/path/to/local/file.glb');

      final result = await FilebaseService().uploadFile(
        filePath: file.path,
        fileName: 'uploaded_model.glb',
        folderPath: 'assets/models',
        metadata: {
          'x-amz-meta-description': 'User uploaded 3D model',
          'x-amz-meta-uploaded-by': 'user@example.com',
        },
      );

      if (result != null) {
        print('✓ File uploaded to: $result');
      } else {
        print('✗ Upload failed');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  /// Upload file from image picker
  static Future<String?> uploadFromImagePicker() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileName = pickedFile.name;

        return await FilebaseService().uploadFile(
          filePath: file.path,
          fileName: fileName,
          folderPath: 'assets/user-uploads',
        );
      }
    } catch (e) {
      print('Error picking/uploading image: $e');
    }
    return null;
  }
}

// ============================================================================
// EXAMPLE 2: File Download and Management
// ============================================================================

class FileDownloadExample {
  /// Download file with error handling
  static Future<bool> downloadFileWithErrorHandling(
    String filePathOnServer,
  ) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = filePathOnServer.split('/').last;
      final localPath = '${appDir.path}/$fileName';

      print('Downloading: $filePathOnServer');
      print('Saving to: $localPath');

      final success = await FilebaseService().downloadFile(
        objectPath: filePathOnServer,
        localSavePath: localPath,
      );

      if (success) {
        final file = File(localPath);
        final fileSize = await file.length();
        print('✓ Downloaded successfully: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        return true;
      } else {
        print('✗ Download failed');
        return false;
      }
    } catch (e) {
      print('Error downloading file: $e');
      return false;
    }
  }

  /// Download multiple files
  static Future<List<String>> downloadMultipleFiles(
    List<String> filePathsOnServer,
  ) async {
    final downloadedFiles = <String>[];
    final appDir = await getApplicationDocumentsDirectory();

    for (final filePath in filePathsOnServer) {
      final fileName = filePath.split('/').last;
      final localPath = '${appDir.path}/$fileName';

      final success = await FilebaseService().downloadFile(
        objectPath: filePath,
        localSavePath: localPath,
      );

      if (success) {
        downloadedFiles.add(localPath);
      }
    }

    print('Downloaded ${downloadedFiles.length}/${filePathsOnServer.length} files');
    return downloadedFiles;
  }
}

// ============================================================================
// EXAMPLE 3: Asset Library Management
// ============================================================================

class AssetLibraryManager {
  /// Sync assets from Filebase
  /// Download all models in a folder
  static Future<List<String>> syncAssetsFolder(String folderPath) async {
    try {
      final service = FilebaseService();
      
      // List files in folder
      final files = await service.listFiles(folderPath);
      print('Found ${files.length} files in $folderPath');

      // Download each file
      final appDir = await getApplicationDocumentsDirectory();
      final downloadedFiles = <String>[];

      for (final file in files) {
        final fileName = file.split('/').last;
        final localPath = '${appDir.path}/$fileName';

        final success = await service.downloadFile(
          objectPath: file,
          localSavePath: localPath,
        );

        if (success) {
          downloadedFiles.add(localPath);
        }
      }

      return downloadedFiles;
    } catch (e) {
      print('Error syncing assets: $e');
      return [];
    }
  }

  /// Get library statistics
  static Future<void> printLibraryStats() async {
    try {
      final service = FilebaseService();
      final files = await service.listFiles('assets');

      int totalSize = 0;
      for (final f in files) {
        final size = await service.getFileSize(f);
        if (size != null) totalSize += size;
      }

      print('\n📊 Asset Library Statistics:');
      print('├─ Total Files: ${files.length}');
      print('├─ Total Size: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB');
      print('└─ Endpoint: s3.filebase.com\n');
    } catch (e) {
      print('Error getting stats: $e');
    }
  }

  /// List all assets by type
  static Future<Map<String, List<String>>> listAssetsByType() async {
    try {
      final service = FilebaseService();
      final allFiles = await service.listFiles('assets');

      final byType = <String, List<String>>{};

      for (final file in allFiles) {
        final ext = file.split('.').last.toLowerCase();
        if (!byType.containsKey(ext)) {
          byType[ext] = [];
        }
        byType[ext]!.add(file);
      }

      return byType;
    } catch (e) {
      print('Error listing assets: $e');
      return {};
    }
  }
}

// ============================================================================
// EXAMPLE 4: File Validation and Batch Operations
// ============================================================================

class FileValidationExample {
  static const int maxFileSizeMB = 100;
  static const List<String> allowedExtensions = [
    'jpg', 'jpeg', 'png', 'gif',
    'glb', 'gltf', 'obj', 'fbx',
    'pdf', 'zip',
  ];

  /// Validate file before upload
  static Future<bool> validateFile(File file, String fileName) async {
    try {
      // Check extension
      final ext = fileName.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(ext)) {
        print('✗ Invalid file type: .$ext');
        return false;
      }

      // Check file size
      final fileSize = await file.length();
      final fileSizeMB = fileSize / (1024 * 1024);

      if (fileSizeMB > maxFileSizeMB) {
        print('✗ File too large: ${fileSizeMB.toStringAsFixed(2)} MB (max: $maxFileSizeMB MB)');
        return false;
      }

      // Check if file exists on server
      if (await FilebaseService().fileExists('assets/$fileName')) {
        print('⚠ File already exists on server');
        // Optionally replace or skip
      }

      print('✓ File validation passed');
      return true;
    } catch (e) {
      print('Error validating file: $e');
      return false;
    }
  }

  /// Batch upload with validation
  static Future<List<String>> batchUploadWithValidation(
    List<File> files,
    List<String> fileNames,
  ) async {
    final uploadedFiles = <String>[];

    for (int i = 0; i < files.length; i++) {
      final isValid = await validateFile(files[i], fileNames[i]);

      if (isValid) {
        final result = await FilebaseService().uploadFile(
          filePath: files[i].path,
          fileName: fileNames[i],
          folderPath: 'assets/uploads',
        );

        if (result != null) {
          uploadedFiles.add(result);
        }
      }
    }

    return uploadedFiles;
  }

  /// Delete old files
  static Future<int> cleanupOldFiles(String folderPath, int daysOld) async {
    try {
      final service = FilebaseService();
      final files = await service.listFiles(folderPath);
      
      // In production, you'd check file creation time from metadata
      // For now, this is a placeholder
      
      int deletedCount = 0;
      for (final file in files) {
        final success = await service.deleteFile(file);
        if (success) deletedCount++;
      }

      return deletedCount;
    } catch (e) {
      print('Error cleaning up files: $e');
      return 0;
    }
  }
}

// ============================================================================
// EXAMPLE 5: User Asset Management
// ============================================================================

class UserAssetManager {
  final String userId;

  UserAssetManager(this.userId);

  String get userFolder => 'users/$userId/assets';

  /// Upload user asset
  Future<String?> uploadUserAsset(File file, String assetName) async {
    return await FilebaseService().uploadFile(
      filePath: file.path,
      fileName: assetName,
      folderPath: userFolder,
      metadata: {
        'x-amz-meta-owner': userId,
        'x-amz-meta-uploaded-date': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Get user's assets
  Future<List<String>> getUserAssets() async {
    return await FilebaseService().listFiles(userFolder);
  }

  /// Delete user asset
  Future<bool> deleteUserAsset(String assetName) async {
    return await FilebaseService().deleteFile('$userFolder/$assetName');
  }

  /// Get user's total storage used
  Future<String> getUserStorageUsed() async {
    try {
      final service = FilebaseService();
      final assets = await getUserAssets();
      
      int totalSize = 0;
      for (final asset in assets) {
        final size = await service.getFileSize(asset);
        if (size != null) totalSize += size;
      }

      return (totalSize / (1024 * 1024)).toStringAsFixed(2);
    } catch (e) {
      print('Error calculating storage: $e');
      return '0.00';
    }
  }

  /// Share asset (generate public URL)
  Future<String?> shareAsset(String assetName) async {
    return await FilebaseService().generatePresignedUrl('$userFolder/$assetName');
  }
}

// ============================================================================
// EXAMPLE 6: Version Control for Assets
// ============================================================================

class VersionControlManager {
  /// Create new version of asset
  static Future<String?> createVersion(
    File file,
    String baseName,
    String version,
  ) async {
    final fileName = '${baseName}_v${version.replaceAll('.', '_')}.glb';

    return await FilebaseService().uploadFile(
      filePath: file.path,
      fileName: fileName,
      folderPath: 'assets/versions',
      metadata: {
        'x-amz-meta-version': version,
        'x-amz-meta-created': DateTime.now().toIso8601String(),
      },
    );
  }

  /// List all versions of asset
  static Future<List<String>> getVersions(String baseName) async {
    final allFiles = await FilebaseService().listFiles('assets/versions');
    return allFiles.where((f) => f.contains(baseName)).toList();
  }

  /// Get latest version
  static Future<String?> getLatestVersion(String baseName) async {
    final versions = await getVersions(baseName);
    if (versions.isEmpty) return null;
    return versions.last; // Assuming sorted
  }

  /// Update metadata with changelog
  static Future<bool> addChangelog(
    String filePath,
    String changelog,
  ) async {
    return await FilebaseService().updateFileMeta(
      objectPath: filePath,
      metadata: {
        'x-amz-meta-changelog': changelog,
        'x-amz-meta-modified': DateTime.now().toIso8601String(),
      },
    );
  }
}

// ============================================================================
// EXAMPLE 7: Error Recovery
// ============================================================================

class ErrorRecoveryManager {
  /// Retry upload on failure
  static Future<String?> uploadWithRetry(
    File file,
    String fileName, {
    int maxRetries = 3,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Upload attempt $attempt/$maxRetries: $fileName');

        final result = await FilebaseService().uploadFile(
          filePath: file.path,
          fileName: fileName,
          folderPath: 'assets/uploads',
        );

        if (result != null) {
          print('✓ Upload successful on attempt $attempt');
          return result;
        }
      } catch (e) {
        print('✗ Attempt $attempt failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }

    print('✗ Upload failed after $maxRetries attempts');
    return null;
  }

  /// Verify downloaded file
  static Future<bool> verifyDownload(
    String localPath,
    int expectedSize,
  ) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        print('✗ Downloaded file not found');
        return false;
      }

      final actualSize = await file.length();
      if (actualSize != expectedSize) {
        print('✗ File size mismatch. Expected: $expectedSize, Got: $actualSize');
        return false;
      }

      print('✓ File verification passed');
      return true;
    } catch (e) {
      print('Error verifying file: $e');
      return false;
    }
  }
}

// ============================================================================
// USAGE EXAMPLES IN WIDGETS
// ============================================================================

/*
// Usage in a Flutter widget:

class AssetUploadWidget extends StatefulWidget {
  @override
  State<AssetUploadWidget> createState() => _AssetUploadWidgetState();
}

class _AssetUploadWidgetState extends State<AssetUploadWidget> {
  bool isUploading = false;

  void _uploadAsset() async {
    setState(() => isUploading = true);

    final result = await FileUploadExample.uploadFromImagePicker();

    setState(() => isUploading = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded to: $result')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: isUploading ? null : _uploadAsset,
      child: isUploading 
        ? const CircularProgressIndicator() 
        : const Icon(Icons.upload),
    );
  }
}
*/
