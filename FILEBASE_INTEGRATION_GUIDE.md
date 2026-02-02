# Filebase Integration Module - Complete Documentation

## Overview
The Filebase integration module provides a complete S3-compatible storage solution for the AR 3D Viewer application. This module enables seamless uploading, downloading, updating, and deletion of assets directly to Filebase storage, eliminating the need to store assets in GitHub.

## Features

### ✅ Full CRUD Operations
- **Create**: Upload single/batch files with metadata
- **Read**: Download files, list directory contents, check file existence
- **Update**: Modify file metadata and create new versions
- **Delete**: Remove single/batch files from storage

### 🔐 Security
- AWS Signature Version 4 authentication
- Proper credential management via configuration file
- SHA256 encryption for data integrity

### 📁 File Management
- Batch upload/delete operations
- File existence checking
- File size retrieval
- Directory listing with prefix support
- Public URL generation

### 📊 Storage Analytics
- Bucket statistics (file count, total size)
- Size formatting (bytes, MB, GB)
- File metadata tracking

## Installation

### 1. Dependencies Added to `pubspec.yaml`
```yaml
dependencies:
  aws_s3_new: ^2.2.2      # S3 compatibility
  crypto: ^3.0.3          # SHA256 encryption
  dio: ^5.3.1             # HTTP client
  file_picker: ^6.1.1     # File selection
```

Install dependencies:
```bash
flutter pub get
```

## Configuration

### 1. Update `filebase_config.json`
Located at project root: `filebase_config.json`

**Required fields:**
```json
{
  "filebase": {
    "api_key": "YOUR_FILEBASE_API_KEY",
    "api_secret": "YOUR_FILEBASE_API_SECRET",
    "bucket_name": "your-bucket-name",
    "endpoint": "https://s3.filebase.com",
    "region": "us-east-1"
  },
  "storage": {
    "max_file_size_mb": 100,
    "allowed_file_types": [".jpg", ".png", ".glb", ".gltf", ".obj", ".fbx", ".pdf", ".zip"]
  }
}
```

**Getting Filebase Credentials:**
1. Create account at https://filebase.com
2. Create S3 API credentials in dashboard
3. Copy API Key and Secret
4. Create bucket and note bucket name

### 2. Add config file to Flutter assets
In `pubspec.yaml`:
```yaml
flutter:
  assets:
    - filebase_config.json
    - assets/models/Astronaut.glb
    - assets/images/
```

## Module Structure

### Core Files

#### 1. `lib/services/filebase_service.dart` (523 lines)
**Main service class with all operations**

**Singleton Pattern:**
```dart
final filebaseService = FilebaseService();
```

**Initialization (Required - call once in main.dart):**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FilebaseService.initialize();
  runApp(const MyApp());
}
```

#### 2. `lib/models/filebase_models.dart`
**Data models for type safety:**
- `FilebaseFile`: File metadata model
- `UploadResponse`: Upload operation response
- `DownloadResponse`: Download operation response
- `BucketStats`: Storage statistics
- `FileOperationResult`: Generic operation result

#### 3. `filebase_config.json`
**Configuration and credentials file**

## API Reference

### Upload Operations

#### Upload Single File
```dart
Future<String?> uploadFile({
  required File file,
  required String fileName,
  String? folderPath,
  Map<String, String> metadata = const {},
})
```

**Example:**
```dart
final file = File('/path/to/model.glb');
final result = await FilebaseService().uploadFile(
  file: file,
  fileName: 'model.glb',
  folderPath: 'assets/models',
  metadata: {'description': '3D Model'},
);
if (result != null) {
  print('Uploaded to: $result');
}
```

#### Batch Upload Files
```dart
Future<List<String>> batchUploadFiles({
  required List<File> files,
  required List<String> fileNames,
  String? folderPath,
})
```

**Example:**
```dart
final files = [file1, file2, file3];
final names = ['model1.glb', 'model2.glb', 'image.png'];
final uploaded = await FilebaseService().batchUploadFiles(
  files: files,
  fileNames: names,
  folderPath: 'assets',
);
print('Uploaded ${uploaded.length} files');
```

### Download Operations

#### Download Single File
```dart
Future<bool> downloadFile({
  required String filePathOnServer,
  required String localSavePath,
})
```

**Example:**
```dart
final success = await FilebaseService().downloadFile(
  filePathOnServer: 'assets/models/model.glb',
  localSavePath: '/local/path/model.glb',
);
if (success) {
  print('File downloaded successfully');
}
```

### Read Operations

#### List Files
```dart
Future<List<String>> listFiles(String folderPath)
```

**Example:**
```dart
final files = await FilebaseService().listFiles('assets/models');
for (final file in files) {
  print('File: $file');
}
```

#### Check File Existence
```dart
Future<bool> fileExists(String filePathOnServer)
```

**Example:**
```dart
final exists = await FilebaseService().fileExists('assets/models/model.glb');
print(exists ? 'File exists' : 'File not found');
```

#### Get File Size
```dart
Future<int?> getFileSize(String filePathOnServer)
```

**Example:**
```dart
final sizeBytes = await FilebaseService().getFileSize('assets/models/model.glb');
if (sizeBytes != null) {
  print('Size: ${(sizeBytes / 1024 / 1024).toStringAsFixed(2)} MB');
}
```

### Update Operations

#### Update File Metadata
```dart
Future<bool> updateFileMeta({
  required String filePathOnServer,
  required Map<String, String> metadata,
})
```

**Example:**
```dart
final success = await FilebaseService().updateFileMeta(
  filePathOnServer: 'assets/models/model.glb',
  metadata: {
    'x-amz-meta-description': 'Updated description',
    'x-amz-meta-version': '2.0',
  },
);
```

### Delete Operations

#### Delete Single File
```dart
Future<bool> deleteFile(String filePathOnServer)
```

**Example:**
```dart
final success = await FilebaseService().deleteFile('assets/models/old_model.glb');
if (success) {
  print('File deleted successfully');
}
```

#### Batch Delete Files
```dart
Future<int> batchDeleteFiles(List<String> filePathsOnServer)
```

**Example:**
```dart
final deleted = await FilebaseService().batchDeleteFiles([
  'assets/models/model1.glb',
  'assets/models/model2.glb',
  'assets/images/image1.png',
]);
print('Deleted $deleted files');
```

### Utility Operations

#### Get Bucket Statistics
```dart
Future<Map<String, dynamic>?> getBucketStats()
```

**Example:**
```dart
final stats = await FilebaseService().getBucketStats();
print('Total files: ${stats?['total_files']}');
print('Total size: ${stats?['total_size_mb']} MB');
```

#### Generate Public URL
```dart
String getPublicUrl(String filePathOnServer)
```

**Example:**
```dart
final url = FilebaseService().getPublicUrl('assets/models/model.glb');
print('Access at: $url');
```

## Integration Examples

### Example 1: Upload Asset with Progress
```dart
import 'package:ar_3d_viewer/services/filebase_service.dart';
import 'package:ar_3d_viewer/models/filebase_models.dart';

void uploadAsset() async {
  final file = File('/path/to/asset.glb');
  
  try {
    final result = await FilebaseService().uploadFile(
      file: file,
      fileName: 'asset.glb',
      folderPath: 'assets/models',
      metadata: {
        'x-amz-meta-type': 'model',
        'x-amz-meta-version': '1.0',
      },
    );
    
    if (result != null) {
      print('✓ Successfully uploaded to: $result');
    } else {
      print('✗ Upload failed');
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

### Example 2: Download and Use Asset
```dart
import 'package:ar_3d_viewer/services/filebase_service.dart';
import 'package:path_provider/path_provider.dart';

void downloadAsset() async {
  final appDir = await getApplicationDocumentsDirectory();
  final localPath = '${appDir.path}/model.glb';
  
  final success = await FilebaseService().downloadFile(
    filePathOnServer: 'assets/models/model.glb',
    localSavePath: localPath,
  );
  
  if (success) {
    // Use the downloaded file
    print('File ready at: $localPath');
  }
}
```

### Example 3: Manage Asset Library
```dart
void manageAssets() async {
  final service = FilebaseService();
  
  // List all models
  final models = await service.listFiles('assets/models');
  
  // Get stats
  final stats = await service.getBucketStats();
  
  // Check and download specific model
  if (await service.fileExists('assets/models/hero.glb')) {
    await service.downloadFile(
      filePathOnServer: 'assets/models/hero.glb',
      localSavePath: '/local/path/hero.glb',
    );
  }
  
  // Clean up old files
  final oldFiles = await service.listFiles('assets/archive');
  await service.batchDeleteFiles(oldFiles);
}
```

### Example 4: Update and Version Control
```dart
void versionAsset() async {
  final service = FilebaseService();
  final filePath = 'assets/models/player.glb';
  
  // Update metadata with new version
  await service.updateFileMeta(
    filePathOnServer: filePath,
    metadata: {
      'x-amz-meta-version': '2.0',
      'x-amz-meta-updated-date': DateTime.now().toString(),
      'x-amz-meta-changes': 'Bug fixes and optimizations',
    },
  );
  
  print('Asset versioned successfully');
}
```

## Migration from GitHub

### Step-by-step Migration Guide

1. **Set up Filebase Account**
   - Create account at filebase.com
   - Create bucket (e.g., "ar-assets")
   - Generate S3 API credentials

2. **Update Configuration**
   - Edit `filebase_config.json` with credentials
   - Ensure bucket name matches

3. **Initialize Service**
   - Add to `main.dart`:
   ```dart
   await FilebaseService.initialize();
   ```

4. **Upload Existing Assets**
   ```dart
   final files = [file1, file2, file3];
   await FilebaseService().batchUploadFiles(
     files: files,
     fileNames: ['model1.glb', 'model2.glb', 'image.png'],
     folderPath: 'assets',
   );
   ```

5. **Update Asset References**
   - Change from local paths to Filebase URLs
   - Use `FilebaseService().getPublicUrl()`

6. **Remove from GitHub**
   - Delete local asset files
   - Update `.gitignore` if needed

## Error Handling

### Common Issues & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `Invalid API credentials` | Wrong API key/secret | Verify credentials in filebase_config.json |
| `Access Denied` | Insufficient permissions | Check Filebase bucket policy |
| `File not found (404)` | File doesn't exist or wrong path | Use `fileExists()` to verify path |
| `Network timeout` | Connection issues | Increase timeout in Dio configuration |
| `Signature mismatch` | Clock skew between client/server | Sync system clock |

### Error Handling Example
```dart
try {
  final result = await FilebaseService().uploadFile(
    file: file,
    fileName: 'model.glb',
    folderPath: 'assets/models',
  );
  if (result == null) {
    print('Upload failed - check logs for details');
  }
} on DioException catch (e) {
  print('Network error: ${e.message}');
} catch (e) {
  print('Unexpected error: $e');
}
```

## Performance Tips

1. **Batch Operations**: Use batch upload/delete for multiple files
2. **Check Before Download**: Use `fileExists()` before downloading
3. **Cache Metadata**: Cache file lists to reduce API calls
4. **Async Operations**: Always use await for file operations
5. **Clean Up**: Call `dispose()` when app closes

## Security Best Practices

1. **Protect Credentials**: Never commit API keys to version control
2. **Use Environment Variables**: Consider using environment-specific configs
3. **Validate Files**: Check file types and sizes before upload
4. **Access Control**: Implement proper user permissions
5. **Audit Logs**: Monitor file access and changes

## Troubleshooting

### Cannot initialize service
```
Check: filebase_config.json exists and is in Flutter assets
       API credentials are correct
       Network connectivity is available
```

### File upload fails
```
Check: File exists and is readable
       File size doesn't exceed limit
       File type is in allowed list
       Bucket has write permissions
```

### Download returns 404
```
Check: File path is correct
       File exists using fileExists()
       Bucket name is correct in config
```

## Testing

### Unit Test Example
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ar_3d_viewer/services/filebase_service.dart';

void main() {
  group('FilebaseService Tests', () {
    setUpAll(() async {
      await FilebaseService.initialize();
    });

    test('Initialize service', () async {
      expect(FilebaseService, isNotNull);
    });

    test('Check file existence', () async {
      final exists = await FilebaseService().fileExists('test.txt');
      expect(exists, isBool);
    });
  });
}
```

## Support & Resources

- **Filebase Documentation**: https://docs.filebase.com
- **AWS S3 API Reference**: https://docs.aws.amazon.com/s3/latest/API/
- **Dio Documentation**: https://pub.dev/packages/dio
- **Crypto Package**: https://pub.dev/packages/crypto

## Version History

- **v1.0.0** (2026-01-29): Initial release with full CRUD operations

## License

Part of AR 3D Viewer application - All Rights Reserved
