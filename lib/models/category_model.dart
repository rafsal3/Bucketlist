class ChecklistItem {
  final String id;
  String text;
  bool isCompleted;
  String? categoryId; // null means uncategorized

  ChecklistItem({
    required this.id,
    required this.text,
    this.isCompleted = false,
    this.categoryId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
      'categoryId': categoryId,
    };
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      text: json['text'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      categoryId: json['categoryId'] as String?,
    );
  }
}

class Category {
  final String id;
  String name;
  String icon;
  List<ChecklistItem> items;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    List<ChecklistItem>? items,
  }) : items = items ?? [];

  int get completedCount => items.where((item) => item.isCompleted).length;
  int get totalCount => items.length;
  double get progress => totalCount == 0 ? 0.0 : completedCount / totalCount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) =>
                  ChecklistItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
