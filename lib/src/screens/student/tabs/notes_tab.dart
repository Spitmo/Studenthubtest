import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../../providers/auth_provider.dart';
import '../../../repositories/file_repository.dart'; // 🆕 ADD FILE REPOSITORY
import '../../../models/file_upload_model.dart'; // 🆕 ADD FILE UPLOAD MODEL

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> with TickerProviderStateMixin {
  List<FileUploadModel> _uploads = []; // 🆕 USE ACTUAL MODEL
  final _remarkCtrl = TextEditingController();

  // 🆕 UPDATED: Store both PlatformFile and actual File
  PlatformFile? _selectedPlatformFile;
  File? _selectedFile;
  bool _isPickingFile = false;

  // Categories
  final List<String> _categories = [
    'All',
    'Regular',
    'Assignment',
    'Practical'
  ];
  int _selectedCategoryIndex = 0;

  // Loading states
  bool _isLoading = true;
  bool _isUploading = false;
  String? _error;

  // 🆕 ADD FILE REPOSITORY
  final FileRepository _fileRepository = FileRepository();

  @override
  void initState() {
    super.initState();
    _loadUploads();
  }

  @override
  void dispose() {
    _remarkCtrl.dispose();
    super.dispose();
  }

  // 🆕 UPDATED: File picker that gets actual File object
  Future<void> _pickFile() async {
    setState(() => _isPickingFile = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final platformFile = result.files.first;
        final file = File(platformFile.path!); // 🆕 GET ACTUAL FILE

        setState(() {
          _selectedPlatformFile = platformFile;
          _selectedFile = file;
        });

        print(
            '📁 File selected: ${platformFile.name} (${(platformFile.size / 1024).toStringAsFixed(1)} KB)');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File picker error: $e')),
      );
    } finally {
      setState(() => _isPickingFile = false);
    }
  }

  // 🆕 UPDATED: Load uploads using FileRepository
  Future<void> _loadUploads() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final studentUploads =
          await _fileRepository.getFiles(uploadedBy: auth.userId!);

      if (mounted) {
        setState(() {
          _uploads = studentUploads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load uploads: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  String _getCategoryFromFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.contains('assignment') || lower.contains('assign')) {
      return 'Assignment';
    }
    if (lower.contains('lab') ||
        lower.contains('practical') ||
        lower.contains('exp')) {
      return 'Practical';
    }
    return 'Regular';
  }

  // 🆕 UPDATED: Actual file upload to Supabase Storage
  Future<void> _uploadFile() async {
    // ✅ VALIDATION 1: File must be selected
    if (_selectedFile == null || _selectedPlatformFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Please select a file first')),
      );
      return;
    }

    // ✅ VALIDATION 2: Remark must not be empty
    if (_remarkCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Please add a remark for your upload')),
      );
      return;
    }

    // ✅ VALIDATION 3: File size check (max 10MB)
    final fileSizeMB = _selectedPlatformFile!.size / (1024 * 1024);
    if (fileSizeMB > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ File size must be less than 10MB')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final auth = context.read<AuthProvider>();
      final filename = _selectedPlatformFile!.name;

      print('🚀 Starting ACTUAL file upload: $filename');

      // 🆕 ACTUAL FILE UPLOAD TO SUPABASE STORAGE
      final uploadedFile = await _fileRepository.uploadFile(
        file: _selectedFile!,
        originalName: filename,
        remark: _remarkCtrl.text.trim(),
        uploadedBy: auth.userId!,
      );

      print('✅ ACTUAL file upload successful: ${uploadedFile.fileUrl}');

      // Add to local list
      if (mounted) {
        setState(() {
          _uploads.insert(0, uploadedFile);

          // Clear form
          _remarkCtrl.clear();
          _selectedPlatformFile = null;
          _selectedFile = null;
          _isUploading = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ File uploaded to Supabase Storage!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('❌ ACTUAL upload error: $e');

      if (mounted) {
        setState(() => _isUploading = false);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Upload failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // 🆕 NEW: Download file function
  Future<void> _downloadFile(FileUploadModel file) async {
    if (file.fileUrl == null || file.fileUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ No file available for download')),
      );
      return;
    }

    try {
      // Show download dialog with file URL
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Download File'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File: ${file.filename}'),
              if (file.fileSize != null) ...[
                const SizedBox(height: 8),
                Text('Size: ${(file.fileSize! / 1024).toStringAsFixed(1)} KB'),
              ],
              const SizedBox(height: 16),
              const Text('File is ready for download from:'),
              const SizedBox(height: 8),
              SelectableText(
                file.fileUrl!,
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Download failed: ${e.toString()}')),
      );
    }
  }

  List<FileUploadModel> _getFilteredUploads() {
    if (_selectedCategoryIndex == 0) return _uploads;
    final selectedCategory = _categories[_selectedCategoryIndex];
    return _uploads
        .where((upload) =>
            _getCategoryFromFilename(upload.filename) == selectedCategory)
        .toList();
  }

  // Category icon helper
  Icon _getCategoryIcon(String category) {
    switch (category) {
      case 'Regular':
        return const Icon(Icons.note_rounded, size: 18);
      case 'Assignment':
        return const Icon(Icons.assignment_rounded, size: 18);
      case 'Practical':
        return const Icon(Icons.science_rounded, size: 18);
      default:
        return const Icon(Icons.folder_rounded, size: 18);
    }
  }

  // 🆕 UPDATED: Get status color from UploadStatus enum
  Color _getStatusColor(UploadStatus status) {
    switch (status) {
      case UploadStatus.approved:
        return Colors.green;
      case UploadStatus.pending:
        return Colors.orange;
      case UploadStatus.rejected:
        return Colors.red;
    }
  }

  // 🆕 UPDATED: Get status icon from UploadStatus enum
  IconData _getStatusIcon(UploadStatus status) {
    switch (status) {
      case UploadStatus.approved:
        return Icons.check_circle_rounded;
      case UploadStatus.pending:
        return Icons.schedule_rounded;
      case UploadStatus.rejected:
        return Icons.cancel_rounded;
    }
  }

  // 🆕 UPDATED: Get status text from UploadStatus enum
  String _getStatusText(UploadStatus status) {
    switch (status) {
      case UploadStatus.approved:
        return 'Approved';
      case UploadStatus.pending:
        return 'Pending';
      case UploadStatus.rejected:
        return 'Rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Upload Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_upload_rounded,
                            color: scheme.primary, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Upload New File',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // File selection UI
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: scheme.outline.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          if (_selectedPlatformFile != null) ...[
                            Row(
                              children: [
                                Icon(Icons.insert_drive_file_rounded,
                                    color: scheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedPlatformFile!.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${(_selectedPlatformFile!.size / 1024).toStringAsFixed(1)} KB',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedPlatformFile = null;
                                      _selectedFile = null;
                                    });
                                  },
                                  icon: Icon(Icons.close, color: scheme.error),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          ElevatedButton.icon(
                            onPressed: _isPickingFile ? null : _pickFile,
                            icon: _isPickingFile
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.attach_file_rounded),
                            label: Text(_isPickingFile
                                ? 'Selecting...'
                                : 'Select File'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedPlatformFile != null
                                  ? Colors.green
                                  : scheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          if (_selectedPlatformFile == null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Supported: PDF, Images, Docs (Max 10MB)',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurface.withOpacity(0.6),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _remarkCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Add a remark (required)',
                        hintText: 'e.g., Chapter 5 exercises, Lab report...',
                        prefixIcon: Icon(Icons.note_rounded),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _uploadFile,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.cloud_upload_rounded),
                        label: Text(_isUploading
                            ? 'Uploading to Supabase Storage...'
                            : 'Upload to Supabase Storage'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: _selectedPlatformFile != null
                              ? scheme.primary
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Material 3 Segmented Button Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: _categories.map((category) {
                  return ButtonSegment<String>(
                    value: category,
                    label: Text(category),
                    icon: _getCategoryIcon(category),
                  );
                }).toList(),
                selected: {_categories[_selectedCategoryIndex]},
                onSelectionChanged: (Set<String> newSelection) {
                  if (mounted) {
                    setState(() {
                      _selectedCategoryIndex =
                          _categories.indexOf(newSelection.first);
                    });
                  }
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: scheme.surface,
                  foregroundColor: scheme.onSurface,
                  selectedBackgroundColor: scheme.primary,
                  selectedForegroundColor: scheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Content Area
          SizedBox(
            height: 400,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 64, color: scheme.error),
                          const SizedBox(height: 16),
                          Text('Error loading uploads',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(_error!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: scheme.error),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                              onPressed: _loadUploads,
                              child: const Text('Retry')),
                        ],
                      ))
                    : _buildUploadsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadsList() {
    final filteredUploads = _getFilteredUploads();
    final scheme = Theme.of(context).colorScheme;

    if (filteredUploads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded,
                size: 64, color: scheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
                'No ${_categories[_selectedCategoryIndex].toLowerCase()} uploads yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Upload your first file to get started',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurface.withOpacity(0.6))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredUploads.length,
      itemBuilder: (context, index) {
        final file = filteredUploads[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(file.status).withOpacity(0.1),
              child: Icon(_getStatusIcon(file.status),
                  color: _getStatusColor(file.status)),
            ),
            title: Text(file.filename,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(file.remark),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(file.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_getStatusText(file.status),
                          style: TextStyle(
                              color: _getStatusColor(file.status),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: scheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(_getCategoryFromFilename(file.filename),
                          style: TextStyle(
                              color: scheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    if (file.fileSize != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(
                            '${(file.fileSize! / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                          DateFormat('MMM d, h:mm a').format(file.createdAt),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: scheme.onSurface.withOpacity(0.6)),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                // 🆕 Show file URL if available
                if (file.fileUrl != null && file.fileUrl!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Storage: Supabase',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🆕 Download button for uploaded files
                if (file.fileUrl != null && file.fileUrl!.isNotEmpty)
                  IconButton(
                    onPressed: () => _downloadFile(file),
                    icon: Icon(Icons.download_rounded, color: scheme.primary),
                    tooltip: 'Download file',
                  ),
                IconButton(
                  onPressed: () => _showFileDetails(file),
                  icon: Icon(Icons.info_outline_rounded, color: scheme.primary),
                  tooltip: 'File details',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFileDetails(FileUploadModel file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(file.filename),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remark: ${file.remark}'),
            const SizedBox(height: 8),
            Text('Category: ${_getCategoryFromFilename(file.filename)}'),
            const SizedBox(height: 8),
            Text('Status: ${_getStatusText(file.status)}'),
            if (file.fileSize != null) ...[
              const SizedBox(height: 8),
              Text('Size: ${(file.fileSize! / 1024).toStringAsFixed(1)} KB'),
            ],
            if (file.mimeType != null) ...[
              const SizedBox(height: 8),
              Text('Type: ${file.mimeType}'),
            ],
            const SizedBox(height: 8),
            Text(
                'Uploaded: ${DateFormat('MMM d, yyyy h:mm a').format(file.createdAt)}'),
            // 🆕 Show file URL if available
            if (file.fileUrl != null && file.fileUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Storage: Supabase Storage'),
              const SizedBox(height: 4),
              SelectableText(
                'URL: ${file.fileUrl}',
                style: const TextStyle(fontSize: 10, color: Colors.blue),
              ),
            ],
          ],
        ),
        actions: [
          if (file.fileUrl != null && file.fileUrl!.isNotEmpty)
            TextButton(
              onPressed: () => _downloadFile(file),
              child: const Text('Download'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
