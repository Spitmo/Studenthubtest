import 'package:equatable/equatable.dart';

enum UploadStatus { pending, approved, rejected }

class FileUploadModel extends Equatable {
  final String id;
  final String filename;
  final String originalName;
  final String remark;
  final String uploadedBy;
  final UploadStatus status;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? approvedBy;
  final String? rejectionReason;
  final String? fileUrl;
  final String? thumbnailUrl;
  final int? fileSize;
  final String? mimeType;
  final List<String> tags;

  const FileUploadModel({
    required this.id,
    required this.filename,
    required this.originalName,
    required this.remark,
    required this.uploadedBy,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    this.rejectedAt,
    this.approvedBy,
    this.rejectionReason,
    this.fileUrl,
    this.thumbnailUrl,
    this.fileSize,
    this.mimeType,
    this.tags = const [],
  });

  factory FileUploadModel.fromJson(Map<String, dynamic> json) {
    return FileUploadModel(
      id: json['id'] as String,
      filename: json['filename'] as String,
      originalName: json['original_name'] as String? ?? json['filename'] as String,
      remark: json['remark'] as String,
      uploadedBy: json['uploaded_by'] as String,
      status: _parseStatus(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      approvedAt: json['approved_at'] != null 
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      rejectedAt: json['rejected_at'] != null 
          ? DateTime.parse(json['rejected_at'] as String)
          : null,
      approvedBy: json['approved_by'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      fileUrl: json['file_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      fileSize: json['file_size'] as int?,
      mimeType: json['mime_type'] as String?,
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'original_name': originalName,
      'remark': remark,
      'uploaded_by': uploadedBy,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
      'approved_by': approvedBy,
      'rejection_reason': rejectionReason,
      'file_url': fileUrl,
      'thumbnail_url': thumbnailUrl,
      'file_size': fileSize,
      'mime_type': mimeType,
      'tags': tags,
    };
  }

  static UploadStatus _parseStatus(String statusString) {
    switch (statusString.toLowerCase()) {
      case 'approved':
        return UploadStatus.approved;
      case 'rejected':
        return UploadStatus.rejected;
      case 'pending':
      default:
        return UploadStatus.pending;
    }
  }

  FileUploadModel copyWith({
    String? id,
    String? filename,
    String? originalName,
    String? remark,
    String? uploadedBy,
    UploadStatus? status,
    DateTime? createdAt,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    String? approvedBy,
    String? rejectionReason,
    String? fileUrl,
    String? thumbnailUrl,
    int? fileSize,
    String? mimeType,
    List<String>? tags,
  }) {
    return FileUploadModel(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      originalName: originalName ?? this.originalName,
      remark: remark ?? this.remark,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      fileUrl: fileUrl ?? this.fileUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      tags: tags ?? this.tags,
    );
  }

  @override
  List<Object?> get props => [
        id,
        filename,
        originalName,
        remark,
        uploadedBy,
        status,
        createdAt,
        approvedAt,
        rejectedAt,
        approvedBy,
        rejectionReason,
        fileUrl,
        thumbnailUrl,
        fileSize,
        mimeType,
        tags,
      ];
}