import 'category_model.dart';

class Space {
  final String id;
  String name;
  String? icon;
  bool isHidden;
  List<Category> categories;

  Space({
    required this.id,
    required this.name,
    this.icon,
    this.isHidden = false,
    List<Category>? categories,
  }) : categories = categories ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'isHidden': isHidden,
      'categories': categories.map((cat) => cat.toJson()).toList(),
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
    );
  }
}
