import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  final List<_UploadItem> _uploads = [
    _UploadItem(
      filename: 'Math_Assignment_1.pdf',
      remark: 'Chapter 5 exercises',
      status: 'Approved',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
    _UploadItem(
      filename: 'Physics_Lab_Report.pdf',
      remark: 'Experiment 3 results',
      status: 'Pending',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];
  final _remarkCtrl = TextEditingController();

  @override
  void dispose() {
    _remarkCtrl.dispose();
    super.dispose();
  }

  void _simulateFilePick() {
    if (_remarkCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a remark for your upload')),
      );
      return;
    }
    
    setState(() {
      _uploads.insert(0, _UploadItem(
        filename: 'note_${_uploads.length + 1}.pdf',
        remark: _remarkCtrl.text.trim(),
        status: 'Pending',
        timestamp: DateTime.now(),
      ));
      _remarkCtrl.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File uploaded successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes Upload',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload your study materials and track their status',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          
          // Upload Section
          Card(
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _simulateFilePick,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Upload File'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _simulateFilePick,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Simulate Upload'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Upload History
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: scheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Upload History',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_uploads.length} files',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_uploads.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 64,
                      color: scheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
                    Text(
                      'No uploads yet',
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
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
                    itemCount: _uploads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final item = _uploads[i];
                      return Card(
                  elevation: 1,
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                            Text(
                              DateFormat('MMM d, h:mm a').format(item.timestamp),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${item.filename} details')),
                        );
                      },
                      icon: Icon(
                        Icons.info_outline_rounded,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                );
              },
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
  final String filename;
  final String remark;
  final String status;
  final DateTime timestamp;
  _UploadItem({
    required this.filename,
    required this.remark,
    required this.status,
    required this.timestamp,
  });
}


