import 'package:hive/hive.dart';

part 'category_model.g.dart';

@HiveType(typeId: 0)
class ChecklistItem {
  @HiveField(0)
  final String id;
  @HiveField(1)
  String text;
  @HiveField(2)
  bool isCompleted;
  @HiveField(3)
  String? categoryId; // null means uncategorized
  @HiveField(4)
  String? imageUrl;
  @HiveField(5)
  String? description;

  ChecklistItem({
    required this.id,
    required this.text,
    this.isCompleted = false,
    this.categoryId,
    this.imageUrl,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
      'categoryId': categoryId,
      'imageUrl': imageUrl,
      'description': description,
    };
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      text: json['text'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      categoryId: json['categoryId'] as String?,
      imageUrl: json['imageUrl'] as String?,
      description: json['description'] as String?,
    );
  }
}

@HiveType(typeId: 1)
class Category {
  @HiveField(0)
  final String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String icon;
  @HiveField(3)
  bool isHidden;
  @HiveField(4)
  List<ChecklistItem> items;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    this.isHidden = false,
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
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      isHidden: json['isHidden'] as bool? ?? false,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) =>
                  ChecklistItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
