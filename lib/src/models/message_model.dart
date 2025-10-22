import 'package:equatable/equatable.dart';

class MessageModel extends Equatable {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final DateTime timestamp;
  final String? replyToId;
  final List<String> attachments;
  final bool isEdited;
  final DateTime? editedAt;

  const MessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.timestamp,
    this.replyToId,
    this.attachments = const [],
    this.isEdited = false,
    this.editedAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      text: json['text'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      senderAvatarUrl: json['sender_avatar_url'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      replyToId: json['reply_to_id'] as String?,
      attachments: (json['attachments'] as List?)?.cast<String>() ?? [],
      isEdited: json['is_edited'] as bool? ?? false,
      editedAt: json['edited_at'] != null 
          ? DateTime.parse(json['edited_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar_url': senderAvatarUrl,
      'timestamp': timestamp.toIso8601String(),
      'reply_to_id': replyToId,
      'attachments': attachments,
      'is_edited': isEdited,
      'edited_at': editedAt?.toIso8601String(),
    };
  }

  MessageModel copyWith({
    String? id,
    String? text,
    String? senderId,
    String? senderName,
    String? senderAvatarUrl,
    DateTime? timestamp,
    String? replyToId,
    List<String>? attachments,
    bool? isEdited,
    DateTime? editedAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      timestamp: timestamp ?? this.timestamp,
      replyToId: replyToId ?? this.replyToId,
      attachments: attachments ?? this.attachments,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        text,
        senderId,
        senderName,
        senderAvatarUrl,
        timestamp,
        replyToId,
        attachments,
        isEdited,
        editedAt,
      ];
}