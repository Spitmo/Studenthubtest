import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/supabase_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  // 🎯 UPDATED: Real data from Supabase
  List<Map<String, dynamic>> _pendingUploads = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _users = [];

  // 🎯 NEW: Event creation with time
  final _eventTitle = TextEditingController();
  final _eventDesc = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  final _eventFormKey = GlobalKey<FormState>();

  // Loading states
  bool _isLoading = true;
  bool _isCreatingEvent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _eventTitle.dispose();
    _eventDesc.dispose();
    super.dispose();
  }

  // 🎯 NEW: Load real data from Supabase
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final [pendingUploads, events, users] = await Future.wait([
        SupabaseService.getPendingUploads(),
        SupabaseService.getEvents(),
        SupabaseService.getAllUsers(),
      ]);

      if (mounted) {
        setState(() {
          _pendingUploads = pendingUploads;
          _events = events;
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  // 🎯 UPDATED: Real event creation
  Future<void> _createEvent() async {
    if (!_eventFormKey.currentState!.validate()) return;

    setState(() => _isCreatingEvent = true);

    try {
      final auth = context.read<AuthProvider>();

      // Combine date and time
      final eventDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Create event in Supabase
      await SupabaseService.createEvent(
        title: _eventTitle.text.trim(),
        date: eventDateTime,
        description: _eventDesc.text.trim(),
        createdBy: auth.userId!,
      );

      // Reload events to get the new one
      await _loadData();

      if (mounted) {
        // Clear form
        _eventTitle.clear();
        _eventDesc.clear();
        _isCreatingEvent = false;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Event created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isCreatingEvent = false);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Event creation failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🎯 UPDATED: Real upload management
  Future<void> _approveUpload(int index) async {
    final upload = _pendingUploads[index];

    try {
      await SupabaseService.approveUpload(upload['id']);

      if (mounted) {
        setState(() {
          _pendingUploads.removeAt(index);
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Upload approved!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Approval failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectUpload(int index) async {
    final upload = _pendingUploads[index];

    try {
      await SupabaseService.rejectUpload(upload['id']);

      if (mounted) {
        setState(() {
          _pendingUploads.removeAt(index);
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Upload rejected!'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Rejection failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final secondary = scheme.secondary;

    final List<Widget> pages = [
      _buildAnalyticsPage(context, primary, secondary),
      _buildEventsPage(context),
      _buildUsersPage(context),
      _buildUploadsPage(context),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_getPageTitle()),
        backgroundColor: scheme.surface,
        elevation: 0,
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                onPressed: () => themeProvider.toggleTheme(),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    themeProvider.isDarkMode
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    key: ValueKey(themeProvider.isDarkMode),
                  ),
                ),
                tooltip: 'Toggle theme',
              );
            },
          ),
          IconButton(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: _buildNavigationDrawer(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 64, color: scheme.error),
                      const SizedBox(height: 16),
                      Text('Error loading data',
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
                          onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                )
              : pages[_selectedIndex],
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _showAddEventDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Event'),
              backgroundColor: primary,
            )
          : null,
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Analytics Dashboard';
      case 1:
        return 'Events Management';
      case 2:
        return 'User Management';
      case 3:
        return 'Uploads Management';
      default:
        return 'Admin Dashboard';
    }
  }

  Widget _buildNavigationDrawer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: scheme.surface,
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 30,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Admin Panel',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.surface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Name: ${auth.userName ?? 'N/A'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.surface.withOpacity(0.8),
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.analytics_rounded,
                  title: 'Analytics Dashboard',
                  index: 0,
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.event_rounded,
                  title: 'Events Management',
                  index: 1,
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.people_rounded,
                  title: 'User Management',
                  index: 2,
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.cloud_upload_rounded,
                  title: 'Uploads Management',
                  index: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? scheme.primary : scheme.onSurface.withOpacity(0.6),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? scheme.primary : scheme.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: scheme.primary.withOpacity(0.1),
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildAnalyticsPage(
      BuildContext context, Color primary, Color secondary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Analytics Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isWide = width >= 600;
              final crossAxisCount = isWide ? 4 : 2;
              final childAspectRatio = isWide ? 1.3 : 0.85;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
                children: [
                  _buildAnalyticsCard(
                    context,
                    title: 'Total Students',
                    value: _users
                        .where((user) => user['role'] == 'student')
                        .length
                        .toString(),
                    icon: Icons.people_alt_rounded,
                    color: primary,
                  ),
                  _buildAnalyticsCard(
                    context,
                    title: 'Pending Uploads',
                    value: _pendingUploads.length.toString(),
                    icon: Icons.cloud_upload_rounded,
                    color: secondary,
                  ),
                  _buildAnalyticsCard(
                    context,
                    title: 'Total Events',
                    value: _events.length.toString(),
                    icon: Icons.event_rounded,
                    color: const Color(0xFFF6C6EA),
                  ),
                  _buildAnalyticsCard(
                    context,
                    title: 'Total Users',
                    value: _users.length.toString(),
                    icon: Icons.admin_panel_settings_rounded,
                    color: primary.withOpacity(0.8),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildActivityItem('${_events.length} events scheduled',
                      'Live data', Icons.event_rounded),
                  const Divider(),
                  _buildActivityItem(
                      '${_pendingUploads.length} uploads pending',
                      'Live data',
                      Icons.cloud_upload_rounded),
                  const Divider(),
                  _buildActivityItem('${_users.length} total users',
                      'Live data', Icons.people_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    fontSize: 12,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(time),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildEventsPage(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Events Management',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddEventDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Event'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_events.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No events yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first event to get started',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
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
              itemCount: _events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final event = _events[index];
                final eventDate = DateTime.parse(event['event_date']);

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      child: Text(
                        '${eventDate.day}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(event['title'] ?? 'Untitled Event'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event['description'] ?? 'No description'),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('EEE, d MMM yyyy').format(eventDate)} at ${DateFormat('h:mm a').format(eventDate)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildUsersPage(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Management',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _users.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Users will appear here once registered',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1),
                              child: Text(
                                (user['name'] ?? 'U').substring(0, 1),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(user['name'] ?? 'Unknown User'),
                            subtitle: Text(
                                'Role: ${(user['role'] ?? 'student').toUpperCase()}'),
                            trailing: Text(
                              'Access: ${user['access_code'] ?? 'N/A'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadsPage(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Uploads Management',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _pendingUploads.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_upload_rounded,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No pending uploads',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'All uploads have been processed',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        for (int i = 0; i < _pendingUploads.length; i++)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.1),
                                child:
                                    const Icon(Icons.insert_drive_file_rounded),
                              ),
                              title: Text(_pendingUploads[i]['file_name'] ??
                                  'Unknown File'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_pendingUploads[i]['remark'] ??
                                      'No remark'),
                                  const SizedBox(height: 4),
                                  Text(
                                    _ageString(DateTime.parse(
                                        _pendingUploads[i]['created_at'])),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.6),
                                        ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Approve',
                                    onPressed: () => _approveUpload(i),
                                    icon: const Icon(Icons.check_circle_rounded,
                                        color: Colors.green),
                                  ),
                                  IconButton(
                                    tooltip: 'Reject',
                                    onPressed: () => _rejectUpload(i),
                                    icon: const Icon(Icons.cancel_rounded,
                                        color: Colors.red),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 UPDATED: Event dialog with time picker
  void _showAddEventDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add New Event'),
            content: Form(
              key: _eventFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _eventTitle,
                    decoration: const InputDecoration(
                      labelText: 'Event Title',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                              initialDate: _selectedDate,
                            );
                            if (date != null) {
                              setDialogState(() => _selectedDate = date);
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded),
                          label: Text(DateFormat('EEE, d MMM yyyy')
                              .format(_selectedDate)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _selectedTime,
                            );
                            if (time != null) {
                              setDialogState(() => _selectedTime = time);
                            }
                          },
                          icon: const Icon(Icons.access_time_rounded),
                          label: Text(_selectedTime.format(context)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _eventDesc,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      prefixIcon: Icon(Icons.description_rounded),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isCreatingEvent
                    ? null
                    : () {
                        if (_eventFormKey.currentState!.validate()) {
                          _createEvent();
                          Navigator.pop(context);
                        }
                      },
                child: _isCreatingEvent
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Event'),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _ageString(DateTime ts) {
  final d = DateTime.now().difference(ts);
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
