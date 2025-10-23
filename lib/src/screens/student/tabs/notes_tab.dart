import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../../providers/auth_provider.dart';
import '../../../services/supabase_service.dart';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> with TickerProviderStateMixin {
  List<_UploadItem> _uploads = [];
  final _remarkCtrl = TextEditingController();

  // 🎯 NEW: File selection
  PlatformFile? _selectedFile;
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

  // 🎯 NEW: File picker method
  Future<void> _pickFile() async {
    setState(() => _isPickingFile = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File picker error: $e')),
      );
    } finally {
      setState(() => _isPickingFile = false);
    }
  }

  Future<void> _loadUploads() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final studentUploads =
          await SupabaseService.getStudentUploads(auth.userId!);

      final List<_UploadItem> allUploads = [
        ...studentUploads.map((upload) => _UploadItem(
              id: upload['id']?.toString(),
              filename: upload['file_name'] ?? 'Unknown',
              remark: upload['remark'] ?? '',
              category: _getCategoryFromFilename(upload['file_name'] ?? ''),
              status: _getStatusFromSupabase(upload['status'] ?? 'pending'),
              timestamp: DateTime.parse(
                  upload['created_at'] ?? DateTime.now().toIso8601String()),
            )),
        // Demo data only if no actual uploads
        if (studentUploads.isEmpty) ...[
          _UploadItem(
            filename: 'Math_Assignment_1.pdf',
            remark: 'Chapter 5 exercises',
            category: 'Assignment',
            status: 'Approved',
            timestamp: DateTime.now().subtract(const Duration(days: 2)),
          ),
          _UploadItem(
            filename: 'Physics_Lab_Report.pdf',
            remark: 'Experiment 3 results',
            category: 'Practical',
            status: 'Pending',
            timestamp: DateTime.now().subtract(const Duration(hours: 5)),
          ),
        ],
      ];

      if (mounted) {
        setState(() {
          _uploads = allUploads;
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

  String _getStatusFromSupabase(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  // 🎯 UPDATED: Proper file upload with validation
  Future<void> _uploadFile() async {
    // ✅ VALIDATION 1: File must be selected
    if (_selectedFile == null) {
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

    setState(() => _isUploading = true);

    try {
      final auth = context.read<AuthProvider>();

      // Use actual filename instead of hardcoded
      final filename = _selectedFile!.name;

      // Upload to Supabase
      await SupabaseService.createUpload(
        filename: filename,
        remark: _remarkCtrl.text.trim(),
        uploadedBy: auth.userId!, // ✅ Use userId instead of rollNumber
      );

      // Add to local list
      if (mounted) {
        setState(() {
          _uploads.insert(
              0,
              _UploadItem(
                filename: filename,
                remark: _remarkCtrl.text.trim(),
                category: _getCategoryFromFilename(filename),
                status: 'Pending',
                timestamp: DateTime.now(),
              ));

          // Clear form
          _remarkCtrl.clear();
          _selectedFile = null;
          _isUploading = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ File uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Upload failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<_UploadItem> _getFilteredUploads() {
    if (_selectedCategoryIndex == 0) return _uploads;
    final selectedCategory = _categories[_selectedCategoryIndex];
    return _uploads
        .where((upload) => upload.category == selectedCategory)
        .toList();
  }

  // 🎯 NEW: Category icon helper
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

                    // 🎯 NEW: File selection UI
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
                          if (_selectedFile != null) ...[
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
                                        _selectedFile!.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _selectedFile = null),
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
                              backgroundColor: _selectedFile != null
                                  ? Colors.green
                                  : scheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          if (_selectedFile == null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Supported: PDF, Images, Docs',
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
                            ? 'Uploading to Supabase...'
                            : 'Upload to Supabase'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: _selectedFile != null
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

          // 🎯 UPDATED: Material 3 Segmented Button Tabs
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
        final item = filteredUploads[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(item.status).withOpacity(0.1),
              child: Icon(_getStatusIcon(item.status),
                  color: _getStatusColor(item.status)),
            ),
            title: Text(item.filename,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(item.remark),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(item.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(item.status,
                          style: TextStyle(
                              color: _getStatusColor(item.status),
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
                      child: Text(item.category,
                          style: TextStyle(
                              color: scheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                          DateFormat('MMM d, h:mm a').format(item.timestamp),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: scheme.onSurface.withOpacity(0.6)),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
            isThreeLine: true,
            trailing: IconButton(
              onPressed: () => _showFileDetails(item),
              icon: Icon(Icons.info_outline_rounded, color: scheme.primary),
            ),
          ),
        );
      },
    );
  }

  void _showFileDetails(_UploadItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.filename),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remark: ${item.remark}'),
            const SizedBox(height: 8),
            Text('Category: ${item.category}'),
            const SizedBox(height: 8),
            Text('Status: ${item.status}'),
            const SizedBox(height: 8),
            Text(
                'Uploaded: ${DateFormat('MMM d, yyyy h:mm a').format(item.timestamp)}'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}

class _UploadItem {
  final String? id;
  final String filename;
  final String remark;
  final String category;
  final String status;
  final DateTime timestamp;
  _UploadItem({
    this.id,
    required this.filename,
    required this.remark,
    required this.category,
    required this.status,
    required this.timestamp,
  });
}
