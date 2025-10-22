import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;

  // Initialize theme provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _isDarkMode = await SupabaseService.getThemePreference();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // Use default theme if loading fails
      _isDarkMode = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    try {
      await SupabaseService.saveThemePreference(_isDarkMode);
    } catch (e) {
      // If saving fails, still toggle the theme locally
    }
    notifyListeners();
  }

  void setTheme(bool isDark) {
    if (_isDarkMode == isDark) return;
    _isDarkMode = isDark;
    SupabaseService.saveThemePreference(_isDarkMode);
    notifyListeners();
  }
}
