import 'category_model.dart';

class Space {
  final String id;
  String name;
  String? icon;
  bool isHidden;
  int order;
  bool deleted;
  String? deviceId;
  String? userId;
  DateTime? createdAt;
  DateTime? updatedAt;
  List<Category> categories;

  Space({
    required this.id,
    required this.name,
    this.icon,
    this.isHidden = false,
    this.order = 0,
    this.deleted = false,
    this.deviceId,
    this.userId,
    this.createdAt,
    this.updatedAt,
    List<Category>? categories,
  }) : categories = categories ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'isHidden': isHidden,
      'order': order,
      'deleted': deleted,
      'deviceId': deviceId,
      'userId': userId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'categories': categories.map((cat) => cat.toJson()).toList(),
    };
  }

  factory Space.fromJson(Map<String, dynamic> json) {
    return Space(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      isHidden: json['isHidden'] as bool? ?? false,
      order: json['order'] as int? ?? 0,
      deleted: json['deleted'] as bool? ?? false,
      deviceId: json['deviceId'] as String?,
      userId: json['userId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((item) => Category.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
