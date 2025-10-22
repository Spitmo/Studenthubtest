import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../exceptions/app_exceptions.dart';
import '../../services/supabase_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;
  bool _isSubscribedToNotifications = false;

  // Getters
  UserModel? get currentUser => _currentUser;
  String? get rollNumber => _currentUser?.rollNumber;
  UserRole get role => _currentUser?.role ?? UserRole.student;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;

  // For backward compatibility with existing code
  String? get userId => _currentUser?.id;
  String? get userName => _currentUser?.name;
  String? get userEmail => _currentUser?.email;

  // Initialize and check for existing session
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _setLoading(true);
    try {
      final session = await SupabaseService.getUserSession();
      final userId = session['user_id'];
      final userRole = session['user_role'];
      final rollNumber = session['roll_number'];
      final userName = session['user_name'];
      final userEmail = session['user_email'];

      if (userId != null && userRole != null && rollNumber != null) {
        // Restore session from local storage
        try {
          final role = UserRole.values.firstWhere(
            (r) => r.name == userRole,
            orElse: () => UserRole.student,
          );
          
          _currentUser = UserModel(
            id: userId,
            name: userName ?? (role == UserRole.admin ? 'Admin User' : 'Student User'),
            rollNumber: rollNumber,
            email: userEmail ?? '$rollNumber@studenthub.com',
            role: role,
            isApproved: true,
            createdAt: DateTime.now(),
          );
          
          await _subscribeToNotifications();
        } catch (e) {
          // Clear invalid session
          await SupabaseService.clearUserSession();
          if (kDebugMode) {
            print('Failed to restore session: $e');
          }
        }
      }
      _isInitialized = true;
    } catch (e) {
      _errorMessage = 'Failed to initialize auth: $e';
      _isInitialized = true;
    } finally {
      _setLoading(false);
    }
  }

  // Login with credentials (keeping existing system)
  Future<void> login({required String name, required String accessCode}) async {
    _setLoading(true);
    _clearError();

    try {
      // Validate inputs
      if (name.trim().isEmpty) {
        throw ValidationException.emptyField('Name');
      }
      if (accessCode.trim().isEmpty) {
        throw ValidationException.emptyField('Access Code');
      }

      // Determine role based on access code
      UserRole role;
      if (accessCode == 'student123') {
        role = UserRole.student;
      } else if (accessCode == 'admin123') {
        role = UserRole.admin;
      } else {
        throw AuthException.invalidCredentials();
      }

      // Create a mock user for the hardcoded system
      _currentUser = UserModel(
        id: 'mock_${name.replaceAll(' ', '_').toLowerCase()}_${role.name}',
        name: name.trim(),
        rollNumber: name.trim(), // Use name as identifier
        email: '${name.trim().replaceAll(' ', '.').toLowerCase()}@studenthub.com',
        role: role,
        isApproved: true,
        createdAt: DateTime.now(),
      );

      // Save session
      try {
        await SupabaseService.saveUserSession(
          _currentUser!.id,
          _currentUser!.role,
          _currentUser!.rollNumber,
          userName: _currentUser!.name,
          userEmail: _currentUser!.email,
        );
      } catch (e) {
        throw DatabaseException.insertFailed();
      }

      // Subscribe to notifications
      await _subscribeToNotifications();

    } on AppException {
      // Re-throw AppExceptions as-is
      _setLoading(false);
      rethrow;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e.toString();
      throw handleError(e, context: 'Login failed');
    } finally {
      _setLoading(false);
    }
  }

  // Logout
  Future<void> logout() async {
    if (kDebugMode) {
      print('Logout called for user: ${_currentUser?.id}');
    }
    _setLoading(true);
    try {
      // Kick off unsubscription in background with timeout so UI isn't blocked
      unawaited(
        _unsubscribeFromNotifications()
            .timeout(const Duration(seconds: 3), onTimeout: () {})
            .catchError((_) {}),
      );

      // Clear session quickly, then update local state so UI can navigate immediately
      await SupabaseService.clearUserSession();

      _currentUser = null;
      _isSubscribedToNotifications = false;
    } catch (e) {
      _errorMessage = 'Failed to logout: $e';
    } finally {
      _setLoading(false);
    }
  }

  // Update user profile
  Future<void> updateProfile({
    String? name,
    String? email,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return;

    _setLoading(true);
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (email != null) updates['email'] = email;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      if (updates.isNotEmpty) {
        await SupabaseService.updateUserProfile(_currentUser!.id, updates);
        _currentUser = _currentUser!.copyWith(
          name: name ?? _currentUser!.name,
          email: email ?? _currentUser!.email,
          avatarUrl: avatarUrl ?? _currentUser!.avatarUrl,
        );
      }
    } catch (e) {
      _errorMessage = 'Failed to update profile: $e';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Subscribe to notifications based on role
  Future<void> _subscribeToNotifications() async {
    if (_currentUser == null || _isSubscribedToNotifications) {
      if (kDebugMode) {
        print('Skipping notification subscription: user=${_currentUser?.id}, already subscribed=$_isSubscribedToNotifications');
      }
      return;
    }

    // Set flag IMMEDIATELY to prevent concurrent calls
    _isSubscribedToNotifications = true;

    if (kDebugMode) {
      print('Starting notification subscription for user: ${_currentUser!.id}');
    }

    try {
      // Subscribe to general notifications
      await NotificationService.subscribeToTopic('all_users');

      // Subscribe to role-specific notifications
      switch (_currentUser!.role) {
        case UserRole.student:
          await NotificationService.subscribeToTopic('students');
          break;
        case UserRole.admin:
          await NotificationService.subscribeToTopic('admins');
          break;
        case UserRole.moderator:
          await NotificationService.subscribeToTopic('moderators');
          break;
      }
      if (kDebugMode) {
        print('Completed notification subscription for user: ${_currentUser!.id}');
      }
    } catch (e) {
      // Reset flag on error so it can be retried
      _isSubscribedToNotifications = false;
      if (kDebugMode) {
        print('Failed to subscribe to notifications: $e');
      }
    }
  }

  // Unsubscribe from notifications
  Future<void> _unsubscribeFromNotifications() async {
    if (_currentUser == null || !_isSubscribedToNotifications) return;

    try {
      await Future.wait([
        NotificationService
            .unsubscribeFromTopic('all_users')
            .timeout(const Duration(seconds: 2), onTimeout: () {}),
        NotificationService
            .unsubscribeFromTopic('students')
            .timeout(const Duration(seconds: 2), onTimeout: () {}),
        NotificationService
            .unsubscribeFromTopic('admins')
            .timeout(const Duration(seconds: 2), onTimeout: () {}),
        NotificationService
            .unsubscribeFromTopic('moderators')
            .timeout(const Duration(seconds: 2), onTimeout: () {}),
      ], eagerError: false);
      if (kDebugMode) {
        print('Unsubscribed from all notification topics');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to unsubscribe from notifications: $e');
      }
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Clear error manually
  void clearError() {
    _clearError();
  }

  // Check if user has specific permission
  bool hasPermission(String permission) {
    if (_currentUser == null) return false;

    switch (permission) {
      case 'manage_users':
      case 'manage_events':
      case 'approve_files':
        return _currentUser!.role == UserRole.admin;
      case 'moderate_discussion':
        return _currentUser!.role == UserRole.admin || _currentUser!.role == UserRole.moderator;
      case 'upload_files':
      case 'join_discussion':
      case 'view_events':
        return _currentUser!.isApproved;
      default:
        return false;
    }
  }
}


