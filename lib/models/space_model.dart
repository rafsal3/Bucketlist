import 'package:hive/hive.dart';
import 'category_model.dart';

part 'space_model.g.dart';

@HiveType(typeId: 2)
class Space extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String? icon;
  @HiveField(3)
  bool isHidden;
  @HiveField(4)
  List<Category> categories;
  @HiveField(5)
  List<ChecklistItem>
      uncategorizedItems; // Dedicated storage for uncategorized items

  Space({
    required this.id,
    required this.name,
    this.icon,
    this.isHidden = false,
    List<Category>? categories,
    List<ChecklistItem>? uncategorizedItems,
  })  : categories = categories ?? [],
        uncategorizedItems = uncategorizedItems ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'isHidden': isHidden,
      'categories': categories.map((cat) => cat.toJson()).toList(),
      'uncategorizedItems':
          uncategorizedItems.map((item) => item.toJson()).toList(),
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
      uncategorizedItems: (json['uncategorizedItems'] as List<dynamic>?)
              ?.map((item) =>
                  ChecklistItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
