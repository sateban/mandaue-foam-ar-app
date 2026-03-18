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

  String get sizeMB => (sizeBytes / (1024 * 1024)).toStringAsFixed(2);

  String get extension {
    final parts = fileName.split('.');
    return parts.isNotEmpty ? '.${parts.last}' : '';
  }

  @override
  String toString() =>
      'FilebaseFile($fileName, $sizeBytes bytes, uploaded: $uploadedAt)';
}

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

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'filePath': filePath,
      'errorMessage': errorMessage,
      'responseData': responseData,
    };
  }

  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      success: json['success'] as bool,
      filePath: json['filePath'] as String?,
      errorMessage: json['errorMessage'] as String?,
      responseData: json['responseData'] as Map<String, dynamic>?,
    );
  }
}

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

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'localPath': localPath,
      'sizeBytes': sizeBytes,
      'errorMessage': errorMessage,
    };
  }

  factory DownloadResponse.fromJson(Map<String, dynamic> json) {
    return DownloadResponse(
      success: json['success'] as bool,
      localPath: json['localPath'] as String?,
      sizeBytes: json['sizeBytes'] as int?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

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

  String get totalSizeMB =>
      (totalSizeBytes / (1024 * 1024)).toStringAsFixed(2);

  String get totalSizeGB =>
      (totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2);

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

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'filePath': filePath,
      'message': message,
      'statusCode': statusCode,
      'timestamp': timestamp.toIso8601String(),
    };
  }

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
