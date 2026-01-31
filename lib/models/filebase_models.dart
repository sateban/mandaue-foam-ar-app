/// Model for Filebase file metadata
class FilebaseFile {
  final String fileName;
  final String filePath;
  final String contentType;
  final int sizeBytes;
  final DateTime uploadedAt;
  final Map<String, String> metadata;
  final String? eTag;
  final String? versionId;

  FilebaseFile({
    required this.fileName,
    required this.filePath,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedAt,
    this.metadata = const {},
    this.eTag,
    this.versionId,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'filePath': filePath,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      'uploadedAt': uploadedAt.toIso8601String(),
      'metadata': metadata,
      'eTag': eTag,
      'versionId': versionId,
    };
  }

  /// Create from JSON
  factory FilebaseFile.fromJson(Map<String, dynamic> json) {
    return FilebaseFile(
      fileName: json['fileName'] as String,
      filePath: json['filePath'] as String,
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      uploadedAt: json['uploadedAt'] is String
          ? DateTime.parse(json['uploadedAt'] as String)
          : DateTime.now(),
      metadata: Map<String, String>.from(json['metadata'] ?? {}),
      eTag: json['eTag'] as String?,
      versionId: json['versionId'] as String?,
    );
  }

  /// Get file size in MB
  String get sizeMB => (sizeBytes / (1024 * 1024)).toStringAsFixed(2);

  /// Get file extension
  String get extension {
    final parts = fileName.split('.');
    return parts.isNotEmpty ? '.${parts.last}' : '';
  }

  @override
  String toString() =>
      'FilebaseFile($fileName, $sizeBytes bytes, uploaded: $uploadedAt)';
}

/// Model for upload response
class UploadResponse {
  final bool success;
  final String? filePath;
  final String? errorMessage;
  final Map<String, dynamic>? responseData;

  UploadResponse({
    required this.success,
    this.filePath,
    this.errorMessage,
    this.responseData,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'filePath': filePath,
      'errorMessage': errorMessage,
      'responseData': responseData,
    };
  }

  /// Create from JSON
  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      success: json['success'] as bool,
      filePath: json['filePath'] as String?,
      errorMessage: json['errorMessage'] as String?,
      responseData: json['responseData'] as Map<String, dynamic>?,
    );
  }
}

/// Model for download response
class DownloadResponse {
  final bool success;
  final String? localPath;
  final int? sizeBytes;
  final String? errorMessage;

  DownloadResponse({
    required this.success,
    this.localPath,
    this.sizeBytes,
    this.errorMessage,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'localPath': localPath,
      'sizeBytes': sizeBytes,
      'errorMessage': errorMessage,
    };
  }

  /// Create from JSON
  factory DownloadResponse.fromJson(Map<String, dynamic> json) {
    return DownloadResponse(
      success: json['success'] as bool,
      localPath: json['localPath'] as String?,
      sizeBytes: json['sizeBytes'] as int?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

/// Model for bucket statistics
class BucketStats {
  final String bucketName;
  final int totalFiles;
  final int totalSizeBytes;
  final String endpoint;
  final String region;

  BucketStats({
    required this.bucketName,
    required this.totalFiles,
    required this.totalSizeBytes,
    required this.endpoint,
    required this.region,
  });

  /// Get total size in MB
  String get totalSizeMB =>
      (totalSizeBytes / (1024 * 1024)).toStringAsFixed(2);

  /// Get total size in GB
  String get totalSizeGB =>
      (totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2);

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'bucketName': bucketName,
      'totalFiles': totalFiles,
      'totalSizeBytes': totalSizeBytes,
      'totalSizeMB': totalSizeMB,
      'totalSizeGB': totalSizeGB,
      'endpoint': endpoint,
      'region': region,
    };
  }

  /// Create from JSON
  factory BucketStats.fromJson(Map<String, dynamic> json) {
    return BucketStats(
      bucketName: json['bucket_name'] ?? json['bucketName'] as String,
      totalFiles: json['total_files'] ?? json['totalFiles'] as int? ?? 0,
      totalSizeBytes:
          json['total_size_bytes'] ?? json['totalSizeBytes'] as int? ?? 0,
      endpoint: json['endpoint'] as String? ?? '',
      region: json['region'] as String? ?? '',
    );
  }

  @override
  String toString() =>
      'BucketStats($bucketName: $totalFiles files, ${totalSizeMB}MB)';
}

/// Model for file operation result
class FileOperationResult {
  final bool success;
  final String? filePath;
  final String? message;
  final int? statusCode;
  final DateTime timestamp;

  FileOperationResult({
    required this.success,
    this.filePath,
    this.message,
    this.statusCode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'filePath': filePath,
      'message': message,
      'statusCode': statusCode,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create from JSON
  factory FileOperationResult.fromJson(Map<String, dynamic> json) {
    return FileOperationResult(
      success: json['success'] as bool,
      filePath: json['filePath'] as String?,
      message: json['message'] as String?,
      statusCode: json['statusCode'] as int?,
      timestamp: json['timestamp'] is String
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }
}
