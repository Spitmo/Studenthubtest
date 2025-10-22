import 'package:equatable/equatable.dart';

enum UserRole { student, admin, moderator }

class UserModel extends Equatable {
  final String id;
  final String name;
  final String rollNumber;
  final String email;
  final UserRole role;
  final bool isApproved;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.email,
    required this.role,
    this.isApproved = false,
    this.createdAt,
    this.approvedAt,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      rollNumber: json['roll_number'] as String,
      email: json['email'] ?? '',
      role: _parseRole(json['role'] as String?),
      isApproved: json['is_approved'] as bool? ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
      approvedAt: json['approved_at'] != null 
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'roll_number': rollNumber,
      'email': email,
      'role': role.name,
      'is_approved': isApproved,
      'created_at': createdAt?.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'avatar_url': avatarUrl,
    };
  }

  static UserRole _parseRole(String? roleString) {
    switch (roleString?.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'moderator':
        return UserRole.moderator;
      case 'student':
      default:
        return UserRole.student;
    }
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? rollNumber,
    String? email,
    UserRole? role,
    bool? isApproved,
    DateTime? createdAt,
    DateTime? approvedAt,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      rollNumber: rollNumber ?? this.rollNumber,
      email: email ?? this.email,
      role: role ?? this.role,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        rollNumber,
        email,
        role,
        isApproved,
        createdAt,
        approvedAt,
        avatarUrl,
      ];
}