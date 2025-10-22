import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../exceptions/app_exceptions.dart';
import '../../services/supabase_service.dart';
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      // Check if Supabase has current user (using Supabase auth)
      final currentUser = SupabaseService.currentUser;

      if (currentUser != null) {
        // Try to get user profile from Supabase
        try {
          final userProfile =
              await SupabaseService.getUserProfile(currentUser.id);

          if (userProfile != null) {
            // Create UserModel from Supabase data
            _currentUser = UserModel(
              id: currentUser.id,
              name: userProfile['name'] ?? 'User',
              rollNumber: userProfile['roll_number'] ?? 'Unknown',
              email: currentUser.email ??
                  '${userProfile['roll_number']}@studenthub.com',
              role: _getRoleFromString(userProfile['role'] ?? 'student'),
              isApproved: userProfile['is_approved'] ?? true,
              createdAt: DateTime.now(),
            );

            await _subscribeToNotifications();
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed to fetch user profile: $e');
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
  Future<void> login(
      {required String rollNumber, required String accessCode}) async {
    _setLoading(true);
    _clearError();

    try {
      // Validate inputs
      if (rollNumber.trim().isEmpty) {
        throw ValidationException.emptyField('Roll Number');
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
        id: 'mock_${rollNumber}_${role.name}',
        name: role == UserRole.admin ? 'Admin User' : 'Student User',
        rollNumber: rollNumber,
        email: '${rollNumber}@studenthub.com',
        role: role,
        isApproved: true,
        createdAt: DateTime.now(),
      );

      // Save session using SharedPreferences (simple approach)
      await _saveUserSessionToPrefs();

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
      // Unsubscribe from notifications
      await _unsubscribeFromNotifications();

      // Clear session from preferences
      await _clearUserSessionFromPrefs();

      // Also sign out from Supabase if needed
      try {
        await SupabaseService.signOut();
      } catch (e) {
        if (kDebugMode) {
          print('Supabase signout error: $e');
        }
      }

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
        // Update in Supabase
        await SupabaseService.updateUserProfile(_currentUser!.id, updates);

        // Update local user model
        _currentUser = _currentUser!.copyWith(
          name: name ?? _currentUser!.name,
          email: email ?? _currentUser!.email,
          avatarUrl: avatarUrl ?? _currentUser!.avatarUrl,
        );

        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to update profile: $e';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ============ SESSION MANAGEMENT USING SHARED_PREFERENCES ============

  Future<void> _saveUserSessionToPrefs() async {
    // Using SharedPreferences for simple session storage
    // You can replace this with more secure storage if needed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', _currentUser!.id);
    await prefs.setString('user_role', _currentUser!.role.name);
    await prefs.setString('roll_number', _currentUser!.rollNumber);
    await prefs.setString('user_name', _currentUser!.name);
  }

  Future<void> _clearUserSessionFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.remove('roll_number');
    await prefs.remove('user_name');
  }

  Future<Map<String, String>> _getUserSessionFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'user_id': prefs.getString('user_id') ?? '',
      'user_role': prefs.getString('user_role') ?? '',
      'roll_number': prefs.getString('roll_number') ?? '',
      'user_name': prefs.getString('user_name') ?? '',
    };
  }

  // ============ HELPER METHODS ============

  UserRole _getRoleFromString(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'moderator':
        return UserRole.moderator;
      case 'student':
      default:
        return UserRole.student;
    }
  }

  // Subscribe to notifications based on role
  Future<void> _subscribeToNotifications() async {
    if (_currentUser == null || _isSubscribedToNotifications) {
      if (kDebugMode) {
        print(
            'Skipping notification subscription: user=${_currentUser?.id}, already subscribed=$_isSubscribedToNotifications');
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
        print(
            'Completed notification subscription for user: ${_currentUser!.id}');
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
      await NotificationService.unsubscribeFromTopic('all_users');
      await NotificationService.unsubscribeFromTopic('students');
      await NotificationService.unsubscribeFromTopic('admins');
      await NotificationService.unsubscribeFromTopic('moderators');
      if (kDebugMode) {
        print('Unsubscribed from all notification topics');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to unsubscribe from notifications: $e');
      }
    }
  }

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
        return _currentUser!.role == UserRole.admin ||
            _currentUser!.role == UserRole.moderator;
      case 'upload_files':
      case 'join_discussion':
      case 'view_events':
        return _currentUser!.isApproved;
      default:
        return false;
    }
  }
}
