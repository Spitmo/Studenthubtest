import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/supabase_service.dart';
import 'tabs/notes_tab.dart';
import 'tabs/events_tab.dart';
import 'tabs/discussion_tab.dart';
import 'tabs/profile_tab.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _index = 0;
  final _tabs = const [
    NotesTab(),
    EventsTab(),
    DiscussionTab(),
    ProfileTab(),
  ];

  // Supabase connection status
  bool _isConnectedToSupabase = false;
  bool _isLoadingConnection = true;
  Map<String, int> _analytics = {};

  @override
  void initState() {
    super.initState();
    _checkSupabaseConnection();
  }

  Future<void> _checkSupabaseConnection() async {
    try {
      // Test Supabase connection
      final isConnected = await SupabaseService.testConnection();
      final auth = context.read<AuthProvider>();

      Map<String, int> analytics = {};
      if (isConnected && auth.rollNumber != null) {
        // Get student-specific analytics
        analytics = await SupabaseService.getStudentAnalytics(auth.rollNumber!);
      }

      setState(() {
        _isConnectedToSupabase = isConnected;
        _analytics = analytics;
        _isLoadingConnection = false;
      });
    } catch (e) {
      setState(() {
        _isConnectedToSupabase = false;
        _isLoadingConnection = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;

    final items = <Widget>[
      const Icon(Icons.note_alt_outlined, color: Colors.white),
      const Icon(Icons.event_outlined, color: Colors.white),
      const Icon(Icons.forum_outlined, color: Colors.white),
      const Icon(Icons.person_outline, color: Colors.white),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('StudentHub'),
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          // Supabase connection status indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: _isLoadingConnection
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isConnectedToSupabase
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    color: _isConnectedToSupabase ? Colors.green : Colors.red,
                    size: 20,
                  ),
          ),
          IconButton(
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
          ),
          IconButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: _buildNavigationDrawer(context, auth, scheme),
      body: SafeArea(
        // ADD SAFE AREA FOR BETTER UI
        child: Column(
          children: [
            // Welcome Section - dynamic height to avoid overflow
            _buildWelcomeSection(context, auth, scheme),
            // Main Content - FIXED EXPANDED
            Expanded(
              child: Container(
                width: double.infinity, // FIXED WIDTH
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _tabs[_index],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: _index,
        items: items,
        color: scheme.primary,
        backgroundColor: scheme.surface,
        buttonBackgroundColor: scheme.primary,
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 300),
        onTap: (i) => setState(() => _index = i),
        height: 60,
      ),
    );
  }

  Widget _buildNavigationDrawer(
      BuildContext context, AuthProvider auth, ColorScheme scheme) {
    return Drawer(
      child: SafeArea(
        // ADD SAFE AREA
        child: Column(
          children: [
            // Drawer Header - FIXED HEIGHT
            Container(
              height: 200, // FIXED HEIGHT
              child: DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.primary.withOpacity(0.8)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Roll: ${auth.rollNumber ?? 'N/A'}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Student',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Navigation Items - EXPANDED TO FILL SPACE
            Expanded(
              child: SingleChildScrollView(
                // ADD SCROLL FOR SAFETY
                child: Column(
                  children: [
                    _buildDrawerItem(
                      context,
                      icon: Icons.dashboard_rounded,
                      title: 'Dashboard',
                      onTap: () {
                        setState(() => _index = 0);
                        Navigator.pop(context);
                      },
                      isSelected: _index == 0,
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.note_alt_rounded,
                      title: 'Notes & Uploads',
                      onTap: () {
                        setState(() => _index = 0);
                        Navigator.pop(context);
                      },
                      isSelected: _index == 0,
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.event_rounded,
                      title: 'Events',
                      onTap: () {
                        setState(() => _index = 1);
                        Navigator.pop(context);
                      },
                      isSelected: _index == 1,
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.forum_rounded,
                      title: 'Discussion',
                      onTap: () {
                        setState(() => _index = 2);
                        Navigator.pop(context);
                      },
                      isSelected: _index == 2,
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.person_rounded,
                      title: 'Profile',
                      onTap: () {
                        setState(() => _index = 3);
                        Navigator.pop(context);
                      },
                      isSelected: _index == 3,
                    ),
                    const Divider(),
                    _buildDrawerItem(
                      context,
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      onTap: () {
                        Navigator.pop(context);
                        context.read<AuthProvider>().logout();
                      },
                      isSelected: false,
                      textColor: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
            // Supabase Connection Status - FIXED AT BOTTOM
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _isConnectedToSupabase
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        color:
                            _isConnectedToSupabase ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isConnectedToSupabase
                            ? 'Connected to Supabase'
                            : 'Supabase Offline',
                        style: TextStyle(
                          color: _isConnectedToSupabase
                              ? Colors.green
                              : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (_analytics.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Your Uploads: ${_analytics['totalUploads'] ?? 0}',
                      style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isSelected,
    Color? textColor,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? scheme.primary.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected
              ? scheme.primary
              : textColor ?? scheme.onSurface.withOpacity(0.7),
        ),
        title: Text(
          title,
          style: TextStyle(
            color:
                textColor ?? (isSelected ? scheme.primary : scheme.onSurface),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(
      BuildContext context, AuthProvider auth, ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20, // REDUCED FONT SIZE
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Roll: ${auth.rollNumber ?? 'N/A'}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14, // REDUCED FONT SIZE
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Student',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12, // REDUCED FONT SIZE
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 20, // FURTHER REDUCED SIZE
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Icon(
                  Icons.person_rounded,
                  size: 24, // FURTHER REDUCED SIZE
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // EVEN MORE REDUCED SPACING
          // Quick Stats
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  context,
                  'Uploads',
                  '${_analytics['totalUploads'] ?? 0}',
                  Icons.upload_file_rounded,
                ),
              ),
              const SizedBox(width: 8), // REDUCED SPACING
              Expanded(
                child: _buildQuickStat(
                  context,
                  'Approved',
                  '${_analytics['approvedUploads'] ?? 0}',
                  Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 8), // REDUCED SPACING
              Expanded(
                child: _buildQuickStat(
                  context,
                  'Pending',
                  '${_analytics['pendingUploads'] ?? 0}',
                  Icons.schedule_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(
      BuildContext context, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(6), // FURTHER REDUCED PADDING
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 14, // FURTHER REDUCED SIZE
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12, // FURTHER REDUCED FONT SIZE
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 9, // FURTHER REDUCED FONT SIZE
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
