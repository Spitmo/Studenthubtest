import 'package:flutter/foundation.dart';

enum UserRole { none, student, admin }

class AuthProvider extends ChangeNotifier {
  String? _rollNumber;
  UserRole _role = UserRole.none;

  String? get rollNumber => _rollNumber;
  UserRole get role => _role;
  bool get isLoggedIn => _role != UserRole.none;

  void login({required String rollNumber, required String accessCode}) {
    if (accessCode == 'student123') {
      _role = UserRole.student;
      _rollNumber = rollNumber;
      notifyListeners();
      return;
    }
    if (accessCode == 'admin123') {
      _role = UserRole.admin;
      _rollNumber = rollNumber;
      notifyListeners();
      return;
    }
    throw Exception('Invalid access code');
  }

  void logout() {
    _role = UserRole.none;
    _rollNumber = null;
    notifyListeners();
  }
}


