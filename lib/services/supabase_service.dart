import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import '../src/models/user_model.dart';
import '../src/models/event_model.dart';
import '../src/models/file_upload_model.dart';
import '../src/models/message_model.dart';
import '../src/exceptions/app_exceptions.dart';
import '../src/utils/connectivity_checker.dart';

class SupabaseService {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: ".env");
      
      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        throw DatabaseException(
          'Supabase configuration missing',
          details: 'Please check your .env file',
        );
      }
      
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException(
        'Failed to initialize database',
        details: e.toString(),
        originalError: e,
      );
    }
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
    try {
      await ConnectivityChecker.ensureConnection();
      
      final response = await client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      if (e is AppException) rethrow;
      throw handleError(e, context: 'Failed to fetch user profile');
    }
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
    try {
      await ConnectivityChecker.ensureConnection();
      
      final response = await client
          .from('events')
          .select()
          .order('date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (e is AppException) rethrow;
      throw handleError(e, context: 'Failed to fetch events');
    }
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

  // Enhanced File Upload with Supabase Storage
  static Future<String?> uploadFile(File file, String fileName, String bucket) async {
    try {
      await ConnectivityChecker.ensureConnection();
      
      // Check file size (limit to 10MB)
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw FileException.fileTooLarge();
      }
      
      final path = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await client.storage.from(bucket).upload(path, file);
      final url = client.storage.from(bucket).getPublicUrl(path);
      return url;
    } catch (e) {
      if (e is AppException) rethrow;
      throw FileException.uploadFailed();
    }
  }

  static Future<void> deleteFile(String path, String bucket) async {
    try {
      await client.storage.from(bucket).remove([path]);
    } catch (e) {
      throw Exception('File deletion failed: $e');
    }
  }

  // Enhanced File Upload Management with Models
  static Future<FileUploadModel> createFileUploadWithModel({
    required String filename,
    required String originalName,
    required String remark,
    required String uploadedBy,
    String? fileUrl,
    int? fileSize,
    String? mimeType,
    List<String> tags = const [],
  }) async {
    final response = await client.from('file_uploads').insert({
      'filename': filename,
      'original_name': originalName,
      'remark': remark,
      'uploaded_by': uploadedBy,
      'file_url': fileUrl,
      'file_size': fileSize,
      'mime_type': mimeType,
      'tags': tags,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();
    
    return FileUploadModel.fromJson(response);
  }

  static Future<List<FileUploadModel>> getFileUploads({UploadStatus? status}) async {
    var query = client.from('file_uploads').select();
    
    if (status != null) {
      query = query.eq('status', status.name);
    }
    
    final response = await query.order('created_at', ascending: false);
    return response.map<FileUploadModel>((json) => FileUploadModel.fromJson(json)).toList();
  }

  // Enhanced Event Management with Models
  static Future<EventModel> createEventWithModel({
    required String title,
    required DateTime date,
    required String description,
    required String location,
    required String time,
    required String createdBy,
    String? imageUrl,
    List<String> tags = const [],
  }) async {
    final response = await client.from('events').insert({
      'title': title,
      'date': date.toIso8601String(),
      'description': description,
      'location': location,
      'time': time,
      'created_by': createdBy,
      'image_url': imageUrl,
      'tags': tags,
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();
    
    return EventModel.fromJson(response);
  }

  static Future<List<EventModel>> getEventsWithModel({bool activeOnly = true}) async {
    var query = client.from('events').select();
    
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    
    final response = await query.order('date', ascending: true);
    return response.map<EventModel>((json) => EventModel.fromJson(json)).toList();
  }

  // Real-time Message System
  static Future<MessageModel> sendMessage({
    required String text,
    required String senderId,
    required String senderName,
    String? senderAvatarUrl,
    String? replyToId,
    List<String> attachments = const [],
  }) async {
    final response = await client.from('messages').insert({
      'text': text,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar_url': senderAvatarUrl,
      'reply_to_id': replyToId,
      'attachments': attachments,
      'timestamp': DateTime.now().toIso8601String(),
      'is_edited': false,
    }).select().single();
    
    return MessageModel.fromJson(response);
  }

  static Stream<List<MessageModel>> getMessagesStream() {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: true)
        .map((data) => data.map<MessageModel>((json) => MessageModel.fromJson(json)).toList());
  }

  static Future<List<MessageModel>> getMessages({int limit = 50, int offset = 0}) async {
    final response = await client
        .from('messages')
        .select()
        .order('timestamp', ascending: false)
        .range(offset, offset + limit - 1);
    
    return response.map<MessageModel>((json) => MessageModel.fromJson(json)).toList().reversed.toList();
  }

  // Search functionality
  static Future<List<EventModel>> searchEvents(String query) async {
    if (query.isEmpty) return await getEventsWithModel();
    
    final response = await client
        .from('events')
        .select()
        .or('title.ilike.%$query%,description.ilike.%$query%')
        .eq('is_active', true)
        .order('date', ascending: true);
    
    return response.map<EventModel>((json) => EventModel.fromJson(json)).toList();
  }

  static Future<List<FileUploadModel>> searchFiles(String query) async {
    if (query.isEmpty) return await getFileUploads();
    
    final response = await client
        .from('file_uploads')
        .select()
        .or('filename.ilike.%$query%,remark.ilike.%$query%')
        .order('created_at', ascending: false);
    
    return response.map<FileUploadModel>((json) => FileUploadModel.fromJson(json)).toList();
  }

  static Future<List<MessageModel>> searchMessages(String query) async {
    if (query.isEmpty) return await getMessages();
    
    final response = await client
        .from('messages')
        .select()
        .ilike('text', '%$query%')
        .order('timestamp', ascending: false)
        .limit(20);
    
    return response.map<MessageModel>((json) => MessageModel.fromJson(json)).toList();
  }

  // Enhanced User Management
  static Future<List<UserModel>> getUsersWithModel({UserRole? role, bool? isApproved}) async {
    var query = client.from('user_profiles').select();
    
    if (role != null) {
      query = query.eq('role', role.name);
    }
    if (isApproved != null) {
      query = query.eq('is_approved', isApproved);
    }
    
    final response = await query.order('created_at', ascending: false);
    return response.map<UserModel>((json) => UserModel.fromJson(json)).toList();
  }

  static Future<void> bulkApproveUsers(List<String> userIds) async {
    await client
        .from('user_profiles')
        .update({
          'is_approved': true,
          'approved_at': DateTime.now().toIso8601String(),
        })
        .inFilter('id', userIds);
  }

  static Future<void> bulkRejectUsers(List<String> userIds) async {
    await client
        .from('user_profiles')
        .delete()
        .inFilter('id', userIds);
  }

  // Connectivity and Error Handling
  static Future<bool> isConnected() async {
    try {
      await client.from('user_profiles').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
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

  // Session Management
  static Future<void> saveUserSession(String userId, UserRole role, String rollNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('user_role', role.name);
    await prefs.setString('roll_number', rollNumber);
  }

  static Future<Map<String, String?>> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'user_id': prefs.getString('user_id'),
      'user_role': prefs.getString('user_role'),
      'roll_number': prefs.getString('roll_number'),
    };
  }

  static Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.remove('roll_number');
  }
}
