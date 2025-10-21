import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
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
        title: Text('StudentHub - ${auth.rollNumber ?? 'Student'}'),
        backgroundColor: scheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => themeProvider.toggleTheme(),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
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
      body: AnimatedSwitcher(
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
}


