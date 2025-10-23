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
          },
        );

    // Messages realtime channel
    _messagesChannel = client.channel('messages-realtime').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            print('💬 Messages Real-time Update: ${payload.eventType}');
          },
        );

    // Uploads realtime channel
    _uploadsChannel = client.channel('uploads-realtime').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'uploads',
          callback: (payload) {
            print('📁 Uploads Real-time Update: ${payload.eventType}');
          },
        );

    // Users realtime channel
    _usersChannel = client.channel('users-realtime').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: (payload) {
            print('👤 Users Real-time Update: ${payload.eventType}');
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

  // ==================== AUTH METHODS ====================

  // Get user session from SharedPreferences
  static Future<Map<String, dynamic>> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'user_id': prefs.getString('user_id'),
      'user_role': prefs.getString('user_role'),
      'roll_number': prefs.getString('roll_number'),
      'user_name': prefs.getString('user_name'),
    };
  }

  // Save user session to SharedPreferences
  static Future<void> saveUserSession(
    String userId,
    String userRole,
    String rollNumber, {
    String? userName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('user_role', userRole);
    await prefs.setString('roll_number', rollNumber);
    if (userName != null) {
      await prefs.setString('user_name', userName);
    }
  }

  // Clear user session
  static Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.remove('roll_number');
    await prefs.remove('user_name');
  }

  // Get user by ID from Supabase
  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final response =
          await client.from('users').select().eq('id', userId).single();
      return response;
    } catch (e) {
      return null;
    }
  }

  // Get users by access code from Supabase
  static Future<List<Map<String, dynamic>>> getUsersByAccessCode(
      String accessCode) async {
    try {
      final response =
          await client.from('users').select().eq('access_code', accessCode);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // ==================== USER MANAGEMENT ====================

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await client
          .from('users')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // ==================== EVENTS MANAGEMENT ====================

  static Future<void> createEvent({
    required String title,
    required DateTime date,
    required String description,
    required String createdBy,
  }) async {
    await client.from('events').insert({
      'title': title,
      'event_date': date.toIso8601String(),
      'description': description,
      'created_by': createdBy,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getEvents() async {
    try {
      final response = await client.from('events').select().order('created_at',
          ascending:
              false); // FIXED: Changed from event_date to created_at and set to descending
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  static Future<void> deleteEvent(String eventId) async {
    await client.from('events').delete().eq('id', eventId);
  }

  // ==================== UPLOADS MANAGEMENT ====================

  static Future<void> createUpload({
    required String filename,
    required String remark,
    required String uploadedBy,
  }) async {
    await client.from('uploads').insert({
      'file_name': filename,
      'remark': remark,
      'student_id': uploadedBy,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingUploads() async {
    try {
      final response = await client
          .from('uploads')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getStudentUploads(
      String studentId) async {
    try {
      final response = await client
          .from('uploads')
          .select()
          .eq('student_id', studentId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
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

  // ==================== MESSAGES MANAGEMENT ====================

  static Future<void> createMessage({
    required String message,
    required String userId,
  }) async {
    await client.from('messages').insert({
      'message': message,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getMessages() async {
    try {
      final response = await client
          .from('messages')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // ==================== ACCESS REQUESTS MANAGEMENT ====================

  static Future<void> createAccessRequest({
    required String name,
  }) async {
    await client.from('access_requests').insert({
      'name': name,
      'status': 'pending',
      'requested_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingAccessRequests() async {
    try {
      final response = await client
          .from('access_requests')
          .select()
          .eq('status', 'pending')
          .order('requested_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  static Future<void> approveAccessRequest(
      String requestId, String accessCode) async {
    await client.from('access_requests').update({
      'status': 'approved',
      'access_code': accessCode,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  static Future<void> rejectAccessRequest(String requestId) async {
    await client.from('access_requests').update({
      'status': 'rejected',
      'rejected_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  // ==================== ANALYTICS ====================

  static Future<Map<String, int>> getAnalytics() async {
    try {
      final studentsResp = await client
          .from('users')
          .select('id')
          .eq('role', 'student')
          .count(CountOption.exact);

      final pendingUploadsResp = await client
          .from('uploads')
          .select('id')
          .eq('status', 'pending')
          .count(CountOption.exact);

      final eventsResp =
          await client.from('events').select('id').count(CountOption.exact);

      final usersResp =
          await client.from('users').select('id').count(CountOption.exact);

      return {
        'totalStudents': studentsResp.count,
        'pendingUploads': pendingUploadsResp.count,
        'totalEvents': eventsResp.count,
        'totalUsers': usersResp.count,
      };
    } catch (e) {
      return {
        'totalStudents': 0,
        'pendingUploads': 0,
        'totalEvents': 0,
        'totalUsers': 0,
      };
    }
  }

  // ==================== THEME PREFERENCES ====================

  static Future<void> saveThemePreference(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  static Future<bool> getThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isDarkMode') ?? false;
  }

  // ==================== CONNECTION TEST ====================

  static Future<bool> testConnection() async {
    try {
      await client.from('users').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }
}
