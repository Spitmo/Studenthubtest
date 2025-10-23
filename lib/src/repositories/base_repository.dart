import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class BaseRepository {
  // Check network connectivity
  Future<bool> hasNetworkConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  // Check if Supabase is connected - FIXED VERSION
  Future<bool> hasSupabaseConnection() async {
    try {
      // Direct Supabase instance check
      final client = Supabase.instance.client;
      // Try a simple query to verify connection
      await client.from('users').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Handle errors consistently
  Exception handleError(dynamic error) {
    if (error is Exception) {
      return error;
    }
    return Exception('An unexpected error occurred: $error');
  }

  // Execute operations with error handling and connectivity checks
  Future<T> executeWithErrorHandling<T>(
    Future<T> Function() operation, {
    bool requiresNetwork = true,
    T? fallbackValue,
  }) async {
    try {
      if (requiresNetwork) {
        final hasNetwork = await hasNetworkConnection();
        if (!hasNetwork) {
          throw Exception('No network connection available');
        }

        final hasSupabase = await hasSupabaseConnection();
        if (!hasSupabase) {
          throw Exception('Unable to connect to server');
        }
      }

      return await operation();
    } catch (e) {
      if (fallbackValue != null) {
        return fallbackValue;
      }
      throw handleError(e);
    }
  }
}
