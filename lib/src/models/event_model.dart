import 'package:equatable/equatable.dart';

class EventModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final String time;
  final String createdBy;
  final DateTime createdAt;
  final String? imageUrl;
  final List<String> tags;
  final bool isActive;

  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.time,
    required this.createdBy,
    required this.createdAt,
    this.imageUrl,
    this.tags = const [],
    this.isActive = true,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      date: DateTime.parse(json['date'] as String),
      location: json['location'] as String? ?? '',
      time: json['time'] as String? ?? '',
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      imageUrl: json['image_url'] as String?,
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'location': location,
      'time': time,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'image_url': imageUrl,
      'tags': tags,
      'is_active': isActive,
    };
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    String? location,
    String? time,
    String? createdBy,
    DateTime? createdAt,
    String? imageUrl,
    List<String>? tags,
    bool? isActive,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      location: location ?? this.location,
      time: time ?? this.time,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        date,
        location,
        time,
        createdBy,
        createdAt,
        imageUrl,
        tags,
        isActive,
      ];
}