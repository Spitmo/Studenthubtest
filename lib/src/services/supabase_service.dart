import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://qbutsawjtzvnoffkcsor.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFidXRzYXdqdHp2bm9mZmtjc29yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3MTkyMjQsImV4cCI6MjA3NjI5NTIyNH0.fquFrkAr5rfMccFT7I_lXJuUOnrVULEtPtV2pjBFRZk';

  static SupabaseClient get client => Supabase.instance.client;

  // Realtime channels
  static RealtimeChannel? _eventsChannel;
  static RealtimeChannel? _messagesChannel;
  static RealtimeChannel? _uploadsChannel;
  static RealtimeChannel? _usersChannel;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    // Initialize realtime channels
    _initializeRealtimeChannels();
  }

  // ==================== REALTIME IMPLEMENTATION ====================

  static void _initializeRealtimeChannels() {
    // Events realtime channel
    _eventsChannel = client.channel('events-realtime').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          callback: (payload) {
            print('🎯 Events Real-time Update: ${payload.eventType}');
            // This will be handled by screens
          },
        );

    // Messages realtime channel
    _messagesChannel = client.channel('messages-realtime').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            print('💬 Messages Real-time Update: ${payload.eventType}');
            // This will be handled by screens
          },
        );

    // Uploads realtime channel
    _uploadsChannel = client.channel('uploads-realtime').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'uploads',
          callback: (payload) {
            print('📁 Uploads Real-time Update: ${payload.eventType}');
            // This will be handled by screens
          },
        );

    // Users realtime channel
    _usersChannel = client.channel('users-realtime').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: (payload) {
            print('👤 Users Real-time Update: ${payload.eventType}');
            // This will be handled by screens
          },
        );

    // Subscribe to all channels
    _subscribeToChannels();
  }

  static void _subscribeToChannels() {
    _eventsChannel?.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('✅ Events realtime subscribed');
      }
      if (error != null) {
        print('❌ Events realtime error: $error');
      }
    });

    _messagesChannel?.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('✅ Messages realtime subscribed');
      }
      if (error != null) {
        print('❌ Messages realtime error: $error');
      }
    });

    _uploadsChannel?.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('✅ Uploads realtime subscribed');
      }
      if (error != null) {
        print('❌ Uploads realtime error: $error');
      }
    });

    _usersChannel?.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('✅ Users realtime subscribed');
      }
      if (error != null) {
        print('❌ Users realtime error: $error');
      }
    });
  }

  // Realtime subscription methods for screens
  static RealtimeChannel getEventsRealtime(Function(dynamic) onUpdate) {
    return client.channel('events-custom').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          callback: onUpdate,
        );
  }

  static RealtimeChannel getMessagesRealtime(Function(dynamic) onUpdate) {
    return client.channel('messages-custom').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: onUpdate,
        );
  }

  static RealtimeChannel getUploadsRealtime(Function(dynamic) onUpdate) {
    return client.channel('uploads-custom').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'uploads',
          callback: onUpdate,
        );
  }

  // Cleanup method
  static void dispose() {
    _eventsChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    _uploadsChannel?.unsubscribe();
    _usersChannel?.unsubscribe();

    _eventsChannel = null;
    _messagesChannel = null;
    _uploadsChannel = null;
    _usersChannel = null;

    print('🔴 All realtime channels disposed');
  }

  // ==================== EXISTING CODE (WITH FIXES) ====================

  // Helper to safely convert various response shapes to a List<Map<String, dynamic>>
  static List<Map<String, dynamic>> _toList(dynamic response) {
    if (response == null) return [];
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    // Some Supabase responses wrap data in `.data`
    try {
      final data = (response as dynamic).data;
      if (data is List) return List<Map<String, dynamic>>.from(data);
    } catch (_) {}
    return [];
  }

  // User Management
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required String rollNumber,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        'roll_number': rollNumber,
      },
    );
    return response;
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
    dispose(); // Cleanup realtime on logout
  }

  static User? get currentUser => client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  // User Profile Management - FIXED TABLE NAME
  static Future<void> createUserProfile({
    required String userId,
    required String name,
    required String rollNumber,
    required String role,
  }) async {
    await client.from('users').insert({
      // CHANGED: 'user_profiles' -> 'users'
      'id': userId,
      'name': name,
      'roll_number': rollNumber,
      'role': role,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await client
        .from('users') // CHANGED: 'user_profiles' -> 'users'
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (response == null) return null;
    try {
      return Map<String, dynamic>.from(response as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    await client
        .from('users')
        .update(updates)
        .eq('id', userId); // CHANGED table name
  }

  // Events Management - FIXED FIELD NAMES
  static Future<void> createEvent({
    required String title,
    required DateTime date,
    required String description,
    required String createdBy,
  }) async {
    await client.from('events').insert({
      'title': title,
      'event_date': date.toIso8601String(), // CHANGED: 'date' -> 'event_date'
      'description': description,
      'created_by': createdBy,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getEvents() async {
    final response = await client.from('events').select().order('event_date',
        ascending: true); // CHANGED: 'date' -> 'event_date'
    return _toList(response);
  }

  static Future<void> deleteEvent(String eventId) async {
    await client.from('events').delete().eq('id', eventId);
  }

  // File Uploads Management - FIXED FIELD NAMES
  static Future<void> createUpload({
    required String filename,
    required String remark,
    required String uploadedBy,
  }) async {
    await client.from('uploads').insert({
      'file_name': filename, // CHANGED: 'filename' -> 'file_name'
      'remark': remark,
      'student_id': uploadedBy, // CHANGED: 'uploaded_by' -> 'student_id'
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingUploads() async {
    final response = await client
        .from('uploads')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return _toList(response);
  }

  static Future<void> approveUpload(String uploadId) async {
    await client.from('uploads').update({
      'status': 'approved',
    }).eq('id', uploadId);
  }

  static Future<void> rejectUpload(String uploadId) async {
    await client.from('uploads').update({
      'status': 'rejected',
    }).eq('id', uploadId);
  }

  // Analytics - FIXED TABLE NAMES
  static Future<Map<String, int>> getAnalytics() async {
    final studentsResp = await client
        .from('users') // CHANGED: 'user_profiles' -> 'users'
        .select()
        .eq('role', 'student');
    final totalStudents = _toList(studentsResp).length;

    final pendingUploadsResp =
        await client.from('uploads').select().eq('status', 'pending');
    final pendingUploads = _toList(pendingUploadsResp).length;

    final eventsResp = await client.from('events').select();
    final totalEvents = _toList(eventsResp).length;

    final usersResp = await client.from('users').select(); // CHANGED table name
    final totalUsers = _toList(usersResp).length;

    return {
      'totalStudents': totalStudents,
      'pendingUploads': pendingUploads,
      'totalEvents': totalEvents,
      'totalUsers': totalUsers,
    };
  }

  // Theme Preferences
  static Future<void> saveThemePreference(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  static Future<bool> getThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isDarkMode') ?? false;
  }

  // Connection Test
  static Future<bool> testConnection() async {
    try {
      await client.from('users').select('id').limit(1); // CHANGED table name
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get Student-specific uploads - FIXED FIELD NAME
  static Future<List<Map<String, dynamic>>> getStudentUploads(
      String studentId) async {
    // CHANGED parameter name
    try {
      final response = await client
          .from('uploads')
          .select()
          .eq('student_id', studentId) // CHANGED: 'uploaded_by' -> 'student_id'
          .order('created_at', ascending: false);
      return _toList(response);
    } catch (e) {
      return [];
    }
  }

  // Get Student-specific analytics
  static Future<Map<String, int>> getStudentAnalytics(String studentId) async {
    try {
      final studentUploads = await getStudentUploads(studentId);
      final totalUploads = studentUploads.length;
      final approvedUploads = studentUploads
          .where((upload) => upload['status'] == 'approved')
          .length;
      final pendingUploads = studentUploads
          .where((upload) => upload['status'] == 'pending')
          .length;

      return {
        'totalUploads': totalUploads,
        'approvedUploads': approvedUploads,
        'pendingUploads': pendingUploads,
      };
    } catch (e) {
      return {
        'totalUploads': 0,
        'approvedUploads': 0,
        'pendingUploads': 0,
      };
    }
  }
}
