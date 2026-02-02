# Filebase Integration - Quick Reference Card

## Files Created
```
lib/services/filebase_service.dart          - Main service (CRUD operations)
lib/models/filebase_models.dart              - Data models
filebase_config.json                         - Credentials & config
FILEBASE_INTEGRATION_GUIDE.md               - Complete documentation
```

## Quick Setup (3 Steps)

### 1. Configure Credentials
Edit `filebase_config.json`:
```json
{
  "filebase": {
    "api_key": "your-api-key",
    "api_secret": "your-secret",
    "bucket_name": "your-bucket",
    "endpoint": "https://s3.filebase.com",
    "region": "us-east-1"
  }
}
```

### 2. Add to pubspec.yaml Assets
```yaml
flutter:
  assets:
    - filebase_config.json
```

### 3. Initialize in main.dart
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FilebaseService.initialize();
  runApp(const MyApp());
}
```

## Common Operations

### Upload File
```dart
await FilebaseService().uploadFile(
  file: File('/path/to/file'),
  fileName: 'model.glb',
  folderPath: 'assets/models',
);
```

### Download File
```dart
await FilebaseService().downloadFile(
  filePathOnServer: 'assets/models/model.glb',
  localSavePath: '/local/path/model.glb',
);
```

### Delete File
```dart
await FilebaseService().deleteFile('assets/models/model.glb');
```

### List Files
```dart
final files = await FilebaseService().listFiles('assets/models');
```

### Check if File Exists
```dart
if (await FilebaseService().fileExists('assets/models/model.glb')) {
  // File exists
}
```

### Get File Size
```dart
final size = await FilebaseService().getFileSize('assets/models/model.glb');
```

### Update Metadata
```dart
await FilebaseService().updateFileMeta(
  filePathOnServer: 'assets/models/model.glb',
  metadata: {
    'x-amz-meta-version': '2.0',
  },
);
```

### Batch Upload
```dart
await FilebaseService().batchUploadFiles(
  files: [file1, file2, file3],
  fileNames: ['model1.glb', 'model2.glb', 'image.png'],
  folderPath: 'assets',
);
```

### Batch Delete
```dart
await FilebaseService().batchDeleteFiles([
  'assets/models/file1.glb',
  'assets/models/file2.glb',
]);
```

### Get Bucket Stats
```dart
final stats = await FilebaseService().getBucketStats();
print('Total files: ${stats?['total_files']}');
print('Total size: ${stats?['total_size_mb']} MB');
```

### Generate Public URL
```dart
final url = FilebaseService().getPublicUrl('assets/models/model.glb');
```

## Models

### FilebaseFile
```dart
FilebaseFile(
  fileName: 'model.glb',
  filePath: 'assets/models/model.glb',
  contentType: 'model/gltf-binary',
  sizeBytes: 1024000,
  uploadedAt: DateTime.now(),
  metadata: {},
)
```

### BucketStats
```dart
BucketStats(
  bucketName: 'ar-assets',
  totalFiles: 42,
  totalSizeBytes: 104857600,
  endpoint: 'https://s3.filebase.com',
  region: 'us-east-1',
)
```

## Supported File Types
- Images: `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`
- 3D Models: `.glb`, `.gltf`, `.obj`, `.fbx`
- Documents: `.pdf`, `.txt`, `.json`, `.html`
- Archives: `.zip`

## Dependencies Added
```yaml
aws_s3_new: ^2.2.2    # S3 compatibility
crypto: ^3.0.3        # SHA256 encryption
dio: ^5.3.1           # HTTP client
file_picker: ^6.1.1   # File selection
```

## Key Features
✅ Full CRUD operations
✅ Batch upload/delete
✅ File existence checking
✅ File size retrieval
✅ Directory listing
✅ Metadata management
✅ Public URL generation
✅ Bucket statistics
✅ AWS Signature V4 auth
✅ Error handling

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `ApiKey not found` | Check filebase_config.json is in assets |
| `Access Denied` | Verify API credentials are correct |
| `File not found` | Check file path and use `fileExists()` |
| `Upload fails` | Check file size, type, and permissions |
| `Signature error` | Verify API secret is correct |

## Migration Checklist
- [ ] Create Filebase account and bucket
- [ ] Generate API credentials
- [ ] Update filebase_config.json
- [ ] Add to pubspec.yaml assets
- [ ] Initialize service in main.dart
- [ ] Update asset references to use Filebase
- [ ] Upload assets to Filebase
- [ ] Remove from GitHub
- [ ] Test all file operations
- [ ] Update documentation

## Next Steps
1. See `FILEBASE_INTEGRATION_GUIDE.md` for complete documentation
2. Review example integrations in guide
3. Test with sample file upload/download
4. Migrate existing assets from GitHub
5. Update UI to use Filebase URLs

---
Created: 2026-01-29 | AR 3D Viewer Project
