import 'dart:io';
import '../models/file_upload_model.dart';
import '../../services/supabase_service.dart';
import 'base_repository.dart';

class FileRepository extends BaseRepository {
  static const String _storageBucket =
      'student-uploads'; // Use your existing bucket

  // 🆕 UPDATED: Actual file upload to Supabase Storage
  Future<FileUploadModel> uploadFile({
    required File file,
    required String originalName,
    required String remark,
    required String uploadedBy,
    List<String> tags = const [],
  }) async {
    return executeWithErrorHandling<FileUploadModel>(() async {
      // Get file stats
      final fileStat = await file.stat();
      final fileSize = fileStat.size;
      final mimeType = _getMimeType(originalName);

      print(
          '🚀 Starting actual file upload: $originalName (${fileSize / 1024} KB)');

      // 🆕 STEP 1: Upload actual file to Supabase Storage
      final fileUrl = await _uploadFileToStorage(
        file: file,
        fileName: originalName,
        userId: uploadedBy,
      );

      if (fileUrl == null) {
        throw Exception('Failed to upload file to storage');
      }

      print('✅ File uploaded to storage: $fileUrl');

      // 🆕 STEP 2: Create database entry with file URL and metadata
      final uploadData = {
        'file_name': originalName,
        'original_name': originalName, // Add original_name field
        'remark': remark,
        'student_id': uploadedBy,
        'status': 'pending',
        'file_url': fileUrl, // 🆕 Store actual file URL
        'file_size': fileSize, // 🆕 Store file size
        'mime_type': mimeType, // 🆕 Store MIME type
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await SupabaseService.client
          .from('uploads')
          .insert(uploadData)
          .select()
          .single();

      print('✅ Database entry created with file URL');

      return FileUploadModel.fromJson(response);
    },
        fallbackValue: _createFallbackFileUploadModel(
          originalName: originalName,
          remark: remark,
          uploadedBy: uploadedBy,
        ));
  }

  // 🆕 NEW: Actual file upload to Supabase Storage
  Future<String?> _uploadFileToStorage({
    required File file,
    required String fileName,
    required String userId,
  }) async {
    try {
      // Create unique file path with user ID and timestamp
      final fileExtension = fileName.split('.').last;
      final uniqueFileName =
          '${DateTime.now().millisecondsSinceEpoch}_${userId}_$fileName';
      final filePath = uniqueFileName;

      print('📤 Uploading to storage: $filePath');

      // Upload file to Supabase Storage
      await SupabaseService.client.storage
          .from(_storageBucket)
          .upload(filePath, file);

      // Get public URL for the uploaded file
      final publicUrl = SupabaseService.client.storage
          .from(_storageBucket)
          .getPublicUrl(filePath);

      print('✅ Storage upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Storage upload error: $e');
      return null;
    }
  }

  // 🆕 NEW: Download file method
  Future<String?> getFileDownloadUrl(String filePath) async {
    try {
      return SupabaseService.client.storage
          .from(_storageBucket)
          .getPublicUrl(filePath);
    } catch (e) {
      print('❌ Error getting download URL: $e');
      return null;
    }
  }

  // Helper method for fallback
  FileUploadModel _createFallbackFileUploadModel({
    required String originalName,
    required String remark,
    required String uploadedBy,
  }) {
    return FileUploadModel(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      filename: originalName,
      originalName: originalName,
      remark: remark,
      uploadedBy: uploadedBy,
      fileUrl: '',
      fileSize: 0,
      mimeType: _getMimeType(originalName),
      tags: [],
      status: UploadStatus.pending,
      createdAt: DateTime.now(),
    );
  }

  // Get files with filtering
  Future<List<FileUploadModel>> getFiles({
    UploadStatus? status,
    String? uploadedBy,
  }) async {
    return executeWithErrorHandling<List<FileUploadModel>>(() async {
      var query = SupabaseService.client.from('uploads').select();

      if (status != null) {
        query = query.eq('status', status.name);
      }

      if (uploadedBy != null) {
        query = query.eq('student_id', uploadedBy);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => FileUploadModel.fromJson(json as Map<String, dynamic>))
          .toList();
    }, fallbackValue: []);
  }

  // Search files
  Future<List<FileUploadModel>> searchFiles(String query) async {
    return executeWithErrorHandling<List<FileUploadModel>>(() async {
      final response = await SupabaseService.client
          .from('uploads')
          .select()
          .or('file_name.ilike.%$query%,remark.ilike.%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => FileUploadModel.fromJson(json as Map<String, dynamic>))
          .toList();
    }, fallbackValue: []);
  }

  // Approve file upload
  Future<void> approveFile(String uploadId, String approvedBy) async {
    return executeWithErrorHandling<void>(() async {
      await SupabaseService.client.from('uploads').update({
        'status': 'approved',
        'approved_by': approvedBy,
        'approved_at': DateTime.now().toIso8601String(),
      }).eq('id', uploadId);
    });
  }

  // Reject file upload
  Future<void> rejectFile(String uploadId, String rejectionReason) async {
    return executeWithErrorHandling<void>(() async {
      await SupabaseService.client.from('uploads').update({
        'status': 'rejected',
        'rejection_reason': rejectionReason,
        'rejected_at': DateTime.now().toIso8601String(),
      }).eq('id', uploadId);
    });
  }

  // 🆕 UPDATED: Delete file from both storage and database
  Future<void> deleteFile(String uploadId, String? filePath) async {
    return executeWithErrorHandling<void>(() async {
      // Delete from storage if filePath exists
      if (filePath != null && filePath.isNotEmpty) {
        try {
          await SupabaseService.client.storage
              .from(_storageBucket)
              .remove([filePath]);
          print('✅ File deleted from storage: $filePath');
        } catch (e) {
          print('⚠️ Could not delete from storage: $e');
        }
      }

      // Delete from database
      await SupabaseService.client.from('uploads').delete().eq('id', uploadId);

      print('✅ Database record deleted: $uploadId');
    });
  }

  // Get file statistics
  Future<Map<String, int>> getFileStats() async {
    return executeWithErrorHandling<Map<String, int>>(() async {
      final allFiles = await getFiles();

      int pending = 0;
      int approved = 0;
      int rejected = 0;

      for (final file in allFiles) {
        switch (file.status) {
          case UploadStatus.pending:
            pending++;
            break;
          case UploadStatus.approved:
            approved++;
            break;
          case UploadStatus.rejected:
            rejected++;
            break;
        }
      }

      return {
        'total': allFiles.length,
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
      };
    }, fallbackValue: {
      'total': 0,
      'pending': 0,
      'approved': 0,
      'rejected': 0,
    });
  }

  // Helper method to determine MIME type
  String _getMimeType(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      case 'ppt':
      case 'pptx':
        return 'application/vnd.ms-powerpoint';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}
