class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // 'emergency', 'match', 'accepted', 'declined', 'reminder'
  final DateTime timestamp;
  final bool isRead;
  final String? relatedRequestId;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    DateTime? timestamp,
    this.isRead = false,
    this.relatedRequestId,
  }) : timestamp = timestamp ?? DateTime.now();

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'emergency',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
      relatedRequestId: json['relatedRequestId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'relatedRequestId': relatedRequestId,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? type,
    DateTime? timestamp,
    bool? isRead,
    String? relatedRequestId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      relatedRequestId: relatedRequestId ?? this.relatedRequestId,
    );
  }
}
