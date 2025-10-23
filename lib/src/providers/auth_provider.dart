import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../exceptions/app_exceptions.dart' as app_exceptions;
import '../services/supabase_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;
  bool _isSubscribedToNotifications = false;

  AuthProvider() {
    _initializeAuth();
  }

  // Getters
  UserModel? get currentUser => _currentUser;
  String? get rollNumber => _currentUser?.rollNumber;
  UserRole get role => _currentUser?.role ?? UserRole.student;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;

  // For backward compatibility
  String? get userId => _currentUser?.id;
  String? get userName => _currentUser?.name;
  String? get userEmail => _currentUser?.email;

  // Initialize auth
  Future<void> _initializeAuth() async {
    try {
      final session = await SupabaseService.getUserSession();
      final userId = session['user_id'];

      if (userId != null) {
        await _loadUserProfile(userId);
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to initialize auth: $e';
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Load user profile from database
  Future<void> _loadUserProfile(String userId) async {
    try {
      _setLoading(true);
      final userData = await SupabaseService.getUserById(userId);

      if (userData != null) {
        _currentUser = UserModel(
          id: userId,
          name: userData['name'] ?? 'User',
          rollNumber: userData['roll_number'] ?? 'N/A',
          email: '',
          role: _parseUserRole(userData['role']),
          isApproved: true,
          createdAt: DateTime.now(),
        );

        await _subscribeToNotifications();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to load user profile: $e';
    } finally {
      _setLoading(false);
    }
  }

  // Parse user role from string
  UserRole _parseUserRole(String? roleString) {
    if (roleString == null) return UserRole.student;
    switch (roleString.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'moderator':
        return UserRole.moderator;
      default:
        return UserRole.student;
    }
  }

  // PURE ACCESS CODE BASED LOGIN
  Future<void> login({required String accessCode, String? name}) async {
    //temp fix
    _setLoading(true);
    _clearError();

    try {
      if (accessCode.trim().isEmpty) {
        throw app_exceptions.ValidationException.emptyField('Access Code');
      }

      // Get ALL users with this access code
      final usersList = await SupabaseService.getUsersByAccessCode(accessCode);

      if (usersList.isEmpty) {
        throw app_exceptions.AuthException.invalidCredentials();
      }

      // Take the first user (for now)
      final userData = usersList.first;

      // Create user without email
      _currentUser = UserModel(
        id: userData['id'],
        name: userData['name'] ?? 'User',
        rollNumber: userData['roll_number'] ?? 'N/A',
        email: '',
        role: _parseUserRole(userData['role']),
        isApproved: true,
        createdAt: DateTime.now(),
      );

      // Save session
      await SupabaseService.saveUserSession(
        _currentUser!.id,
        _currentUser!.role.name,
        _currentUser!.rollNumber,
        userName: _currentUser!.name,
      );

      await _subscribeToNotifications();
      notifyListeners();

      if (kDebugMode) {
        print('✅ Login successful: ${_currentUser!.name}');
      }
    } catch (e) {
      _errorMessage = 'Login failed: $e';
      throw app_exceptions.AuthException.invalidCredentials();
    } finally {
      _setLoading(false);
    }
  }

  // Logout
  Future<void> logout() async {
    _setLoading(true);
    try {
      _currentUser = null;
      await _unsubscribeFromNotifications();
      await SupabaseService.clearUserSession();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Logout failed: $e';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Subscribe to notifications
  Future<void> _subscribeToNotifications() async {
    if (_currentUser == null || _isSubscribedToNotifications) return;
    _isSubscribedToNotifications = true;
    try {
      await NotificationService.subscribeToTopic('all_users');
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
    } catch (e) {
      _isSubscribedToNotifications = false;
    }
  }

  // Unsubscribe from notifications
  Future<void> _unsubscribeFromNotifications() async {
    if (!_isSubscribedToNotifications) return;
    try {
      await Future.wait([
        NotificationService.unsubscribeFromTopic('all_users'),
        NotificationService.unsubscribeFromTopic('students'),
        NotificationService.unsubscribeFromTopic('admins'),
        NotificationService.unsubscribeFromTopic('moderators'),
      ], eagerError: false);
    } catch (e) {
      // Ignore errors
    } finally {
      _isSubscribedToNotifications = false;
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  // Check permissions
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

  // For routes.dart
  Future<void> initialize() async {
    await _initializeAuth();
  }
}
