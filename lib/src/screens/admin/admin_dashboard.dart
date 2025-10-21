import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  
  final List<_PendingUpload> _pending = [
    _PendingUpload('note_1.pdf', 'Please review chapter 1', DateTime.now().subtract(const Duration(hours: 2))),
    _PendingUpload('note_2.pdf', 'Lab notes', DateTime.now().subtract(const Duration(days: 1))),
    _PendingUpload('assignment_3.pdf', 'Math homework', DateTime.now().subtract(const Duration(hours: 5))),
  ];
  
  final List<_AdminEvent> _events = [
    _AdminEvent('Orientation Day', DateTime.now().add(const Duration(days: 2)), 'Welcome new students'),
    _AdminEvent('Hackathon 2024', DateTime.now().add(const Duration(days: 10)), '24-hour coding challenge'),
    _AdminEvent('Guest Lecture', DateTime.now().add(const Duration(days: 20)), 'AI in Education by Dr. Smith'),
    _AdminEvent('Career Fair', DateTime.now().add(const Duration(days: 30)), 'Meet with top companies'),
    _AdminEvent('Cultural Festival', DateTime.now().add(const Duration(days: 45)), 'Celebrate diversity'),
    _AdminEvent('Sports Day', DateTime.now().add(const Duration(days: 60)), 'Annual sports competition'),
    _AdminEvent('Graduation Ceremony', DateTime.now().add(const Duration(days: 90)), 'Class of 2024 graduation'),
  ];
  
  final _eventTitle = TextEditingController();
  final _eventDesc = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  final _eventFormKey = GlobalKey<FormState>();

  // Demo users for role management
  final List<_UserItem> _users = [
    const _UserItem('Alice Johnson', 'student'),
    const _UserItem('Bob Lee', 'student'),
    const _UserItem('Carol Diaz', 'moderator'),
    const _UserItem('Daniel Kim', 'admin'),
    const _UserItem('Evan Park', 'student'),
    const _UserItem('Fiona Chen', 'student'),
    const _UserItem('George Wilson', 'moderator'),
  ];
  final TextEditingController _userSearch = TextEditingController();

  @override
  void dispose() {
    _eventTitle.dispose();
    _eventDesc.dispose();
    _userSearch.dispose();
    super.dispose();
  }

  void _approve(int i) => setState(() => _pending.removeAt(i));
  void _reject(int i) => setState(() => _pending.removeAt(i));

  void _addEvent() {
    if (!_eventFormKey.currentState!.validate()) return;
    setState(() {
      _events.add(_AdminEvent(_eventTitle.text.trim(), _selectedDate, _eventDesc.text.trim()));
      _eventTitle.clear();
      _eventDesc.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE, d MMM');
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final secondary = scheme.secondary;
    
    final List<Widget> pages = [
      _buildAnalyticsPage(context, primary, secondary),
      _buildEventsPage(context, df),
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
                    themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    key: ValueKey(themeProvider.isDarkMode),
                  ),
                ),
                tooltip: 'Toggle theme',
              );
            },
          ),
          IconButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: _buildNavigationDrawer(context),
      body: pages[_selectedIndex],
      floatingActionButton: _selectedIndex == 1 ? FloatingActionButton.extended(
        onPressed: _showAddEventDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Event'),
        backgroundColor: primary,
      ) : null,
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0: return 'Analytics Dashboard';
      case 1: return 'Events Management';
      case 2: return 'User Management';
      case 3: return 'Uploads Management';
      default: return 'Admin Dashboard';
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
                  'Roll: ${auth.rollNumber ?? 'N/A'}',
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

  Widget _buildDrawerItem(BuildContext context, {
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

  Widget _buildAnalyticsPage(BuildContext context, Color primary, Color secondary) {
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
              final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _buildAnalyticsCard(
                    context,
                    title: 'Total Students',
                    value: '124',
                    icon: Icons.people_alt_rounded,
                    color: primary,
                  ),
                  _buildAnalyticsCard(
                    context,
                    title: 'Pending Uploads',
                    value: '3',
                    icon: Icons.cloud_upload_rounded,
                    color: secondary,
                  ),
                  _buildAnalyticsCard(
                    context,
                    title: 'Total Events',
                    value: '7',
                    icon: Icons.event_rounded,
                    color: const Color(0xFFF6C6EA),
                  ),
                  _buildAnalyticsCard(
                    context,
                    title: 'Admin Activities',
                    value: '47',
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
                  _buildActivityItem('New student registration', '2 hours ago', Icons.person_add_rounded),
                  const Divider(),
                  _buildActivityItem('Event created: Hackathon 2024', '5 hours ago', Icons.event_rounded),
                  const Divider(),
                  _buildActivityItem('File upload approved', '1 day ago', Icons.check_circle_rounded),
                  const Divider(),
                  _buildActivityItem('User role updated', '2 days ago', Icons.admin_panel_settings_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(BuildContext context, {
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.green,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '4.2%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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

  Widget _buildEventsPage(BuildContext context, DateFormat df) {
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
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
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
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
              itemBuilder: (context, i) {
                final event = _events[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Text(
                        '${event.date.day}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(event.title),
                    subtitle: Text(event.description),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          df.format(event.date),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          DateFormat('MMM yyyy').format(event.date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                  child: Column(
                    children: [
                      TextField(
                        controller: _userSearch,
                        decoration: const InputDecoration(
                          labelText: 'Search users',
                          prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                  const SizedBox(height: 16),
                      _UserList(
                        users: _users,
                        filter: _userSearch.text,
                        onRoleChanged: (index, role) => setState(() => _users[index] = _users[index].copyWith(role: role)),
                      ),
                    ],
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
              child: _pending.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_upload_rounded,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                const SizedBox(height: 16),
                          Text(
                            'No pending uploads',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'All uploads have been processed',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        for (int i = 0; i < _pending.length; i++)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                child: const Icon(Icons.insert_drive_file_rounded),
                              ),
                              title: Text(_pending[i].filename),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_pending[i].remark),
                                  const SizedBox(height: 4),
                                  Text(
                                    _ageString(_pending[i].ts),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Approve',
                                    onPressed: () => _approve(i),
                                    icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                                  ),
                                  IconButton(
                                    tooltip: 'Reject',
                                    onPressed: () => _reject(i),
                                    icon: const Icon(Icons.cancel_rounded, color: Colors.red),
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

  void _showAddEventDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title required' : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    initialDate: _selectedDate,
                  );
                  if (d != null) setState(() => _selectedDate = d);
                },
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text(DateFormat('EEE, d MMM yyyy').format(_selectedDate)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _eventDesc,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
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
            onPressed: () {
              if (_eventFormKey.currentState!.validate()) {
                _addEvent();
                Navigator.pop(context);
              }
            },
            child: const Text('Add Event'),
          ),
        ],
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final List<_UserItem> users;
  final String filter;
  final void Function(int index, String role) onRoleChanged;
  const _UserList({required this.users, required this.filter, required this.onRoleChanged});

  @override
  Widget build(BuildContext context) {
    final visible = users.asMap().entries.where((e) {
      final name = e.value.name.toLowerCase();
      final term = filter.toLowerCase();
      return term.isEmpty || name.contains(term);
    }).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final mapEntry = visible[idx];
        final i = mapEntry.key;
        final user = mapEntry.value;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Text(
                user.name.substring(0, 1),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(user.name),
            subtitle: Text('Role: ${user.role.toUpperCase()}'),
            trailing: DropdownButton<String>(
              value: user.role,
              items: const [
                DropdownMenuItem(value: 'student', child: Text('Student')),
                DropdownMenuItem(value: 'moderator', child: Text('Moderator')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (v) {
                if (v != null) onRoleChanged(i, v);
              },
            ),
          ),
        );
      },
    );
  }
}

class _PendingUpload {
  final String filename;
  final String remark;
  final DateTime ts;
  _PendingUpload(this.filename, this.remark, this.ts);
}

class _AdminEvent {
  final String title;
  final DateTime date;
  final String description;
  _AdminEvent(this.title, this.date, this.description);
}

class _UserItem {
  final String name;
  final String role;
  const _UserItem(this.name, this.role);
  _UserItem copyWith({String? name, String? role}) => _UserItem(name ?? this.name, role ?? this.role);
}

String _ageString(DateTime ts) {
  final d = DateTime.now().difference(ts);
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}