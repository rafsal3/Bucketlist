class ChecklistItem {
  final String id;
  String text;
  bool isCompleted;
  String? categoryId; // null means uncategorized
  String? spaceId;
  String? imageUrl;
  String? description;
  int order;
  bool deleted;
  String? deviceId;
  String? userId;
  DateTime? createdAt;
  DateTime? updatedAt;

  ChecklistItem({
    required this.id,
    required this.text,
    this.isCompleted = false,
    this.categoryId,
    this.spaceId,
    this.imageUrl,
    this.description,
    this.order = 0,
    this.deleted = false,
    this.deviceId,
    this.userId,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
      'categoryId': categoryId,
      'spaceId': spaceId,
      'imageUrl': imageUrl,
      'description': description,
      'order': order,
      'deleted': deleted,
      'deviceId': deviceId,
      'userId': userId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      text: json['text'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      categoryId: json['categoryId'] as String?,
      spaceId: json['spaceId'] as String?,
      imageUrl: json['imageUrl'] as String?,
      description: json['description'] as String?,
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
    );
  }
}

class Category {
  final String id;
  String name;
  String icon;
  bool isHidden;
  String? spaceId;
  int order;
  bool deleted;
  String? deviceId;
  String? userId;
  DateTime? createdAt;
  DateTime? updatedAt;
  List<ChecklistItem> items;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    this.isHidden = false,
    this.spaceId,
    this.order = 0,
    this.deleted = false,
    this.deviceId,
    this.userId,
    this.createdAt,
    this.updatedAt,
    List<ChecklistItem>? items,
  }) : items = items ?? [];

  // Only count items that actually belong to this category
  int get completedCount =>
      items.where((item) => item.categoryId == id && item.isCompleted).length;
  int get totalCount => items.where((item) => item.categoryId == id).length;
  double get progress => totalCount == 0 ? 0.0 : completedCount / totalCount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'isHidden': isHidden,
      'spaceId': spaceId,
      'order': order,
      'deleted': deleted,
      'deviceId': deviceId,
      'userId': userId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      isHidden: json['isHidden'] as bool? ?? false,
      spaceId: json['spaceId'] as String?,
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
      items: (json['items'] as List<dynamic>?)
              ?.map((item) =>
                  ChecklistItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
