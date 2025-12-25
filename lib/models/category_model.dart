class ChecklistItem {
  final String id;
  String text;
  bool isCompleted;
  String? categoryId; // null means uncategorized
  String? imageUrl;
  String? description;

  // For shared spaces: tracks completion per user
  // Key: userId, Value: isCompleted
  Map<String, bool> userCompletions;

  ChecklistItem({
    required this.id,
    required this.text,
    this.isCompleted = false,
    this.categoryId,
    this.imageUrl,
    this.description,
    Map<String, bool>? userCompletions,
  }) : userCompletions = userCompletions ?? {};

  // Check if all users in a shared space have completed
  bool isCompletedByAll(List<String> userIds) {
    if (userIds.isEmpty) return isCompleted;
    return userIds.every((userId) => userCompletions[userId] == true);
  }

  // Get list of users who completed this item
  List<String> getCompletedUsers() {
    return userCompletions.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  // Check if a specific user completed this item
  bool isCompletedByUser(String userId) {
    return userCompletions[userId] == true;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
      'categoryId': categoryId,
      'imageUrl': imageUrl,
      'description': description,
      'userCompletions': userCompletions,
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
      userCompletions: json['userCompletions'] != null
          ? Map<String, bool>.from(json['userCompletions'] as Map)
          : {},
    );
  }
}

class Category {
  final String id;
  String name;
  String icon;
  bool isHidden;
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
