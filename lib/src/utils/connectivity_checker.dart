import 'package:connectivity_plus/connectivity_plus.dart';
import '../exceptions/app_exceptions.dart';

class ConnectivityChecker {
  static final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connectivity
  static Future<bool> hasConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      
      // Check if connected to wifi or mobile data
      return connectivityResult.contains(ConnectivityResult.wifi) ||
             connectivityResult.contains(ConnectivityResult.mobile) ||
             connectivityResult.contains(ConnectivityResult.ethernet);
    } catch (e) {
      // If check fails, assume no connection
      return false;
    }
  }

  /// Check connection and throw exception if not connected
  static Future<void> ensureConnection() async {
    final hasConn = await hasConnection();
    if (!hasConn) {
      throw NetworkException.noConnection();
    }
  }

  /// Get connectivity stream to monitor changes
  static Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged;
  }

  /// Get current connectivity status as a readable string
  static Future<String> getConnectionStatus() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      
      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        return 'WiFi';
      } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
        return 'Mobile Data';
      } else if (connectivityResult.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      } else {
        return 'No Connection';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
