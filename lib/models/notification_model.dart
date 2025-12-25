enum NotificationType {
  spaceInvite,
  connectionRequest,
  taskCompleted,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;

  // Optional data based on notification type
  final String? personId;
  final String? personName;
  final String? spaceId;
  final String? spaceName;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    DateTime? timestamp,
    this.isRead = false,
    this.personId,
    this.personName,
    this.spaceId,
    this.spaceName,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'personId': personId,
      'personName': personName,
      'spaceId': spaceId,
      'spaceName': spaceName,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => NotificationType.spaceInvite,
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      personId: json['personId'] as String?,
      personName: json['personName'] as String?,
      spaceId: json['spaceId'] as String?,
      spaceName: json['spaceName'] as String?,
    );
  }
}
