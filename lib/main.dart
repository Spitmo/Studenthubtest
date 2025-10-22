import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'services/supabase_service.dart';
import 'src/app_theme.dart';
import 'src/providers/auth_provider.dart';
import 'src/providers/theme_provider.dart';
import 'src/routes.dart';
import 'src/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Supabase
    await SupabaseService.initialize();
    
    // Try to initialize Firebase (optional for basic functionality)
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Explicitly disable Firebase Analytics to prevent the error
      // This stops the "Missing google_app_id" error
      // Analytics is already disabled by not including it in dependencies
      
      // Initialize notifications only if Firebase is available
      await NotificationService.initialize();
    } catch (firebaseError) {
      if (kDebugMode) {
        print('Firebase not configured, notifications disabled: $firebaseError');
      }
    }
    
    runApp(const StudentHubApp());
  } catch (e) {
    if (kDebugMode) {
      print('Error during app initialization: $e');
    }
    // Still run the app but with limited functionality
    runApp(const StudentHubApp());
  }
}

class StudentHubApp extends StatefulWidget {
  const StudentHubApp({super.key});

  @override
  State<StudentHubApp> createState() => _StudentHubAppState();
}

class _StudentHubAppState extends State<StudentHubApp> {
  Future<void>? _initFuture;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, auth, themeProvider, _) {
          // Initialize only once
          _initFuture ??= _initializeProviders(context, auth, themeProvider);
          
          return FutureBuilder<void>(
            future: _initFuture,
            builder: (context, snapshot) {
              // Show loading screen during initialization
              if (snapshot.connectionState == ConnectionState.waiting || 
                  !auth.isInitialized || 
                  !themeProvider.isInitialized) {
                return MaterialApp(
                  title: 'StudentHub',
                  debugShowCheckedModeBanner: false,
                  theme: buildLightTheme(),
                  home: const _LoadingScreen(),
                );
              }

              return MaterialApp(
                title: 'StudentHub',
                debugShowCheckedModeBanner: false,
                theme: buildLightTheme(),
                darkTheme: buildDarkTheme(),
                themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
                home: Routes.getInitialScreen(auth),
                onGenerateRoute: Routes.onGenerateRoute,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _initializeProviders(
    BuildContext context,
    AuthProvider auth,
    ThemeProvider themeProvider,
  ) async {
    try {
      // Initialize theme provider first
      await themeProvider.initialize();
      
      // Then initialize auth provider
      await auth.initialize();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing providers: $e');
      }
    }
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7C83FD),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.school_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'StudentHub',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


