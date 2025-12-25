class Person {
  final String id;
  final String name;
  final String uniqueCode; // 6-digit code like "ABC123"
  final String avatarColor; // Hex color for avatar background
  final DateTime connectedAt;

  Person({
    required this.id,
    required this.name,
    required this.uniqueCode,
    required this.avatarColor,
    DateTime? connectedAt,
  }) : connectedAt = connectedAt ?? DateTime.now();

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'uniqueCode': uniqueCode,
      'avatarColor': avatarColor,
      'connectedAt': connectedAt.toIso8601String(),
    };
  }

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as String,
      name: json['name'] as String,
      uniqueCode: json['uniqueCode'] as String,
      avatarColor: json['avatarColor'] as String,
      connectedAt: DateTime.parse(json['connectedAt'] as String),
    );
  }
}
