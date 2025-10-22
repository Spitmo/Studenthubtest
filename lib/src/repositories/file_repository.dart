import 'dart:io';
import '../models/file_upload_model.dart';
import '../../services/supabase_service.dart';
import 'base_repository.dart';

class FileRepository extends BaseRepository {
  static const String _storageBucket = 'student-files';

  // Upload file with metadata
  Future<FileUploadModel> uploadFile({
    required File file,
    required String originalName,
    required String remark,
    required String uploadedBy,
    List<String> tags = const [],
  }) async {
    return executeWithErrorHandling<FileUploadModel>(() async {
      // First upload file to Supabase Storage
      final fileUrl = await SupabaseService.uploadFile(
        file, 
        originalName, 
        _storageBucket,
      );

      // Get file stats
      final fileStat = await file.stat();
      final fileSize = fileStat.size;
      final mimeType = _getMimeType(originalName);

      // Create file upload record with metadata
      return await SupabaseService.createFileUploadWithModel(
        filename: originalName,
        originalName: originalName,
        remark: remark,
        uploadedBy: uploadedBy,
        fileUrl: fileUrl,
        fileSize: fileSize,
        mimeType: mimeType,
        tags: tags,
      );
    });
  }

  // Get files with filtering
  Future<List<FileUploadModel>> getFiles({
    UploadStatus? status,
    String? uploadedBy,
  }) async {
    return executeWithErrorHandling<List<FileUploadModel>>(() async {
      return await SupabaseService.getFileUploads(status: status);
    }, fallbackValue: []);
  }

  // Search files
  Future<List<FileUploadModel>> searchFiles(String query) async {
    return executeWithErrorHandling<List<FileUploadModel>>(() async {
      return await SupabaseService.searchFiles(query);
    }, fallbackValue: []);
  }

  // Approve file upload
  Future<void> approveFile(String uploadId, String approvedBy) async {
    return executeWithErrorHandling<void>(() async {
      await SupabaseService.approveUpload(uploadId);
    });
  }

  // Reject file upload
  Future<void> rejectFile(String uploadId, String rejectionReason) async {
    return executeWithErrorHandling<void>(() async {
      await SupabaseService.rejectUpload(uploadId);
    });
  }

  // Delete file and its record
  Future<void> deleteFile(String uploadId, String? filePath) async {
    return executeWithErrorHandling<void>(() async {
      // Delete from storage if path exists
      if (filePath != null) {
        final path = filePath.split('/').last;
        await SupabaseService.deleteFile(path, _storageBucket);
      }
      
      // Delete record from database
      await SupabaseService.client
          .from('file_uploads')
          .delete()
          .eq('id', uploadId);
    });
  }

  // Get file statistics
  Future<Map<String, int>> getFileStats() async {
    return executeWithErrorHandling<Map<String, int>>(() async {
      final allFiles = await SupabaseService.getFileUploads();
      
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