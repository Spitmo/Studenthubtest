import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../services/supabase_service.dart';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  List<_UploadItem> _uploads = [];
  final _remarkCtrl = TextEditingController();

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

  // File selection state
  String? _selectedFileName;
  bool _hasFileSelected = false;

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

  Future<void> _loadUploads() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load from Supabase
      final supabaseUploads = await SupabaseService.getPendingUploads();

      // Convert to local format and add some demo data
      final List<_UploadItem> allUploads = [
        ...supabaseUploads.map((upload) => _UploadItem(
              id: upload['id']?.toString(),
              filename: upload['filename'] ?? 'Unknown',
              remark: upload['remark'] ?? '',
              category: _getCategoryFromFilename(upload['filename'] ?? ''),
              status: _getStatusFromSupabase(upload['status'] ?? 'pending'),
              timestamp: DateTime.parse(
                  upload['created_at'] ?? DateTime.now().toIso8601String()),
            )),
        // Add some demo data if no Supabase data
        if (supabaseUploads.isEmpty) ...[
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
          _UploadItem(
            filename: 'Chemistry_Notes.pdf',
            remark: 'Organic chemistry notes',
            category: 'Regular',
            status: 'Approved',
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
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
          _error = 'Unable to load uploads. Please check your connection.';
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

  // Simulate file selection
  Future<void> _selectFile() async {
    // In a real app, you would use file_picker package
    // For now, we'll simulate file selection
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select File Type'),
        content: const Text('Choose the type of file you want to upload:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'assignment'),
            child: const Text('Assignment'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'notes'),
            child: const Text('Notes'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'lab_report'),
            child: const Text('Lab Report'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _hasFileSelected = true;
        _selectedFileName =
            '${result}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File selected: $_selectedFileName'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _uploadFile() async {
    // Validation 1: Check if remark is empty
    if (_remarkCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a remark for your upload'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validation 2: Check if file is selected
    if (!_hasFileSelected || _selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }

    try {
      final auth = context.read<AuthProvider>();

      // Upload to Supabase
      await SupabaseService.createUpload(
        filename: _selectedFileName!,
        remark: _remarkCtrl.text.trim(),
        uploadedBy: auth.userId ?? 'unknown_user',
      );

      // Add to local list
      if (mounted) {
        setState(() {
          _uploads.insert(
              0,
              _UploadItem(
                filename: _selectedFileName!,
                remark: _remarkCtrl.text.trim(),
                category: _getCategoryFromFilename(_selectedFileName!),
                status: 'Pending',
                timestamp: DateTime.now(),
              ));
          // Reset form
          _remarkCtrl.clear();
          _hasFileSelected = false;
          _selectedFileName = null;
          _isUploading = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File uploaded successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Upload failed. Please check your connection and try again.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  List<_UploadItem> _getFilteredUploads() {
    if (_selectedCategoryIndex == 0) return _uploads; // All
    final selectedCategory = _categories[_selectedCategoryIndex];
    return _uploads
        .where((upload) => upload.category == selectedCategory)
        .toList();
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
                        Icon(
                          Icons.cloud_upload_rounded,
                          color: scheme.primary,
                          size: 24,
                        ),
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

                    // File Selection Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              _hasFileSelected ? Colors.green : scheme.outline,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _hasFileSelected
                                ? Icons.check_circle
                                : Icons.attach_file,
                            color: _hasFileSelected
                                ? Colors.green
                                : scheme.primary,
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _hasFileSelected
                                ? 'File Selected'
                                : 'No File Selected',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _hasFileSelected
                                  ? Colors.green
                                  : scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _hasFileSelected
                                ? _selectedFileName!
                                : 'Tap below to select a file',
                            style: TextStyle(
                              color: _hasFileSelected
                                  ? scheme.onSurface
                                  : scheme.onSurface.withOpacity(0.6),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _isUploading ? null : _selectFile,
                            icon: Icon(_hasFileSelected
                                ? Icons.change_circle
                                : Icons.add),
                            label: Text(_hasFileSelected
                                ? 'Change File'
                                : 'Select File'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _hasFileSelected
                                  ? Colors.orange
                                  : scheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Remark Input
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

                    // Upload Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploading ? null : _uploadFile,
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.upload_file_rounded),
                            label: Text(
                                _isUploading ? 'Uploading...' : 'Upload File'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: _hasFileSelected &&
                                        _remarkCtrl.text.trim().isNotEmpty
                                    ? scheme.primary
                                    : scheme.outline.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_hasFileSelected &&
                                    _remarkCtrl.text.trim().isNotEmpty &&
                                    !_isUploading)
                                ? _uploadFile
                                : null,
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.cloud_upload_rounded),
                            label: Text(_isUploading
                                ? 'Uploading...'
                                : 'Upload to Cloud'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: (_hasFileSelected &&
                                      _remarkCtrl.text.trim().isNotEmpty)
                                  ? scheme.primary
                                  : scheme.onSurface.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Category Filter Chips
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter by Category',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final category = entry.value;
                    final isSelected = _selectedCategoryIndex == index;

                    return FilterChip(
                      label: Text(
                        category,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : scheme.onSurface,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (mounted) {
                          setState(() {
                            _selectedCategoryIndex = index;
                          });
                        }
                      },
                      backgroundColor: scheme.surface,
                      selectedColor: scheme.primary,
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? scheme.primary
                            : scheme.outline.withOpacity(0.3),
                        width: 1,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content Area
          SizedBox(
            height: 400, // Fixed height to prevent overflow
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 64,
                              color: scheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading uploads',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: scheme.error,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadUploads,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
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
            Icon(
              Icons.folder_open_rounded,
              size: 64,
              color: scheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${_categories[_selectedCategoryIndex].toLowerCase()} uploads yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your first file to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(0.6),
                  ),
            ),
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
              child: Icon(
                _getStatusIcon(item.status),
                color: _getStatusColor(item.status),
              ),
            ),
            title: Text(
              item.filename,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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
                      child: Text(
                        item.status,
                        style: TextStyle(
                          color: _getStatusColor(item.status),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.category,
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        DateFormat('MMM d, h:mm a').format(item.timestamp),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface.withOpacity(0.6),
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            isThreeLine: true,
            trailing: IconButton(
              onPressed: () {
                _showFileDetails(item);
              },
              icon: Icon(
                Icons.info_outline_rounded,
                color: scheme.primary,
              ),
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
            child: const Text('Close'),
          ),
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
