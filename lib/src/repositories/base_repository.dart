import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/supabase_service.dart';

abstract class BaseRepository {
  // Check network connectivity
  Future<bool> hasNetworkConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  // Check if Supabase is connected
  Future<bool> hasSupabaseConnection() async {
    return await SupabaseService.isConnected();
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