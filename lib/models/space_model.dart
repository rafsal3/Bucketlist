import 'category_model.dart';

class Space {
  final String id;
  String name;
  String? icon;
  bool isHidden;
  List<Category> categories;

  // Collaboration fields
  String? ownerId; // Person ID of the space owner
  List<String> collaboratorIds; // List of person IDs who can access this space

  Space({
    required this.id,
    required this.name,
    this.icon,
    this.isHidden = false,
    List<Category>? categories,
    this.ownerId,
    List<String>? collaboratorIds,
  })  : categories = categories ?? [],
        collaboratorIds = collaboratorIds ?? [];

  // Check if this is a shared space
  bool get isShared => collaboratorIds.isNotEmpty;

  // Get all user IDs (owner + collaborators)
  List<String> getAllUserIds() {
    final users = <String>[...collaboratorIds];
    if (ownerId != null && !users.contains(ownerId)) {
      users.insert(0, ownerId!);
    }
    return users;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'isHidden': isHidden,
      'categories': categories.map((cat) => cat.toJson()).toList(),
      'ownerId': ownerId,
      'collaboratorIds': collaboratorIds,
    };
  }

  factory Space.fromJson(Map<String, dynamic> json) {
    return Space(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      isHidden: json['isHidden'] as bool? ?? false,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((item) => Category.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      ownerId: json['ownerId'] as String?,
      collaboratorIds: json['collaboratorIds'] != null
          ? List<String>.from(json['collaboratorIds'] as List)
          : [],
    );
  }
}
