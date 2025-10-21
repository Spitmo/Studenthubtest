import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://qbutsawjtzvnoffkcsor.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFidXRzYXdqdHp2bm9mZmtjc29yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3MTkyMjQsImV4cCI6MjA3NjI5NTIyNH0.fquFrkAr5rfMccFT7I_lXJuUOnrVULEtPtV2pjBFRZk';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
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
  }

  static User? get currentUser => client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  // User Profile Management
  static Future<void> createUserProfile({
    required String userId,
    required String name,
    required String rollNumber,
    required String role,
  }) async {
    await client.from('user_profiles').insert({
      'id': userId,
      'name': name,
      'roll_number': rollNumber,
      'role': role,
      'is_approved': role == 'admin', // Auto-approve admins
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await client
        .from('user_profiles')
        .select()
        .eq('id', userId)
        .single();
    return response;
  }

  static Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    await client
        .from('user_profiles')
        .update(updates)
        .eq('id', userId);
  }

  static Future<void> approveUser(String userId) async {
    await client
        .from('user_profiles')
        .update({'is_approved': true, 'approved_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  static Future<void> rejectUser(String userId) async {
    await client
        .from('user_profiles')
        .delete()
        .eq('id', userId);
  }

  // Pending Users Management
  static Future<List<Map<String, dynamic>>> getPendingUsers() async {
    final response = await client
        .from('user_profiles')
        .select()
        .eq('is_approved', false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await client
        .from('user_profiles')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Events Management
  static Future<void> createEvent({
    required String title,
    required DateTime date,
    required String description,
    required String createdBy,
  }) async {
    await client.from('events').insert({
      'title': title,
      'date': date.toIso8601String(),
      'description': description,
      'created_by': createdBy,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getEvents() async {
    final response = await client
        .from('events')
        .select()
        .order('date', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> deleteEvent(String eventId) async {
    await client
        .from('events')
        .delete()
        .eq('id', eventId);
  }

  // File Uploads Management
  static Future<void> createFileUpload({
    required String filename,
    required String remark,
    required String uploadedBy,
  }) async {
    await client.from('file_uploads').insert({
      'filename': filename,
      'remark': remark,
      'uploaded_by': uploadedBy,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingUploads() async {
    final response = await client
        .from('file_uploads')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> approveUpload(String uploadId) async {
    await client
        .from('file_uploads')
        .update({
      'status': 'approved',
      'approved_at': DateTime.now().toIso8601String(),
    })
        .eq('id', uploadId);
  }

  static Future<void> rejectUpload(String uploadId) async {
    await client
        .from('file_uploads')
        .update({
      'status': 'rejected',
      'rejected_at': DateTime.now().toIso8601String(),
    })
        .eq('id', uploadId);
  }

  // Analytics
  static Future<Map<String, int>> getAnalytics() async {
    // --- FIX 1 ---
    final totalStudents = await client
        .from('user_profiles')
        .select('id')
        .eq('role', 'student')
        .eq('is_approved', true)
        .count(CountOption.exact); // Chained .count()

    // --- FIX 2 ---
    final pendingUploads = await client
        .from('file_uploads')
        .select('id')
        .eq('status', 'pending')
        .count(CountOption.exact); // Chained .count()

    // --- FIX 3 ---
    final totalEvents = await client
        .from('events')
        .select('id')
        .count(CountOption.exact); // Chained .count()

    // --- FIX 4 ---
    final totalUsers = await client
        .from('user_profiles')
        .select('id')
        .eq('is_approved', true)
        .count(CountOption.exact); // Chained .count()

    return {
      'totalStudents': totalStudents.count ?? 0,
      'pendingUploads': pendingUploads.count ?? 0,
      'totalEvents': totalEvents.count ?? 0,
      'totalUsers': totalUsers.count ?? 0,
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
      // Try to query a simple table to test connection
      await client.from('user_profiles').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get Student-specific uploads
  static Future<List<Map<String, dynamic>>> getStudentUploads(String rollNumber) async {
    try {
      final response = await client
          .from('file_uploads')
          .select()
          .eq('uploaded_by', rollNumber)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // Get Student-specific analytics
  static Future<Map<String, int>> getStudentAnalytics(String rollNumber) async {
    try {
      final studentUploads = await getStudentUploads(rollNumber);
      final totalUploads = studentUploads.length;
      final approvedUploads = studentUploads.where((upload) => upload['status'] == 'approved').length;
      final pendingUploads = studentUploads.where((upload) => upload['status'] == 'pending').length;
      
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