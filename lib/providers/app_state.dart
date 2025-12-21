import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart' as models;

class AppState extends ChangeNotifier {
  List<models.Category> _categories = [];
  bool _isLoading = true;

  List<models.Category> get categories => _categories;
  bool get isLoading => _isLoading;

  int get totalCompleted =>
      _categories.fold<int>(0, (sum, cat) => sum + cat.completedCount);
  int get totalItems =>
      _categories.fold<int>(0, (sum, cat) => sum + cat.totalCount);
  double get overallProgress =>
      totalItems == 0 ? 0.0 : totalCompleted / totalItems;

  AppState() {
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? categoriesJson = prefs.getString('categories');

      if (categoriesJson != null) {
        final List<dynamic> decoded = jsonDecode(categoriesJson);
        _categories =
            decoded.map((json) => models.Category.fromJson(json)).toList();
      } else {
        // Initialize with default categories
        _categories = _getDefaultCategories();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      _categories = _getDefaultCategories();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded =
          jsonEncode(_categories.map((cat) => cat.toJson()).toList());
      await prefs.setString('categories', encoded);
    } catch (e) {
      debugPrint('Error saving data: $e');
    }
  }

  List<models.Category> _getDefaultCategories() {
    return [
      models.Category(
        id: 'default_places',
        name: 'Places',
        icon: '🌍',
      ),
      models.Category(
        id: 'default_books',
        name: 'Books',
        icon: '📚',
      ),
      models.Category(
        id: 'default_movies',
        name: 'Movies',
        icon: '🎬',
      ),
      models.Category(
        id: 'default_music',
        name: 'Music',
        icon: '🎵',
      ),
      models.Category(
        id: 'default_life_goals',
        name: 'Life Goals',
        icon: '⭐',
      ),
      models.Category(
        id: 'default_skills',
        name: 'Skills',
        icon: '🎯',
      ),
    ];
  }

  void addCategory(String name, String icon) {
    final category = models.Category(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      icon: icon,
    );
    _categories.add(category);
    _saveData();
    notifyListeners();
  }

  void deleteCategory(String categoryId) {
    _categories.removeWhere((cat) => cat.id == categoryId);
    _saveData();
    notifyListeners();
  }

  // Get all items across all categories
  List<models.ChecklistItem> getAllItems() {
    List<models.ChecklistItem> allItems = [];
    for (var category in _categories) {
      allItems.addAll(category.items);
    }
    return allItems;
  }

  void addItem(String? categoryId, String text) {
    final item = models.ChecklistItem(
      id: 'item_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      categoryId: categoryId,
    );

    if (categoryId != null) {
      final category = _categories.firstWhere((cat) => cat.id == categoryId);
      category.items.add(item);
    } else {
      // For uncategorized items, we'll add them to a special handling
      // They will be stored in the first category but marked as uncategorized
      if (_categories.isNotEmpty) {
        _categories.first.items.add(item);
      }
    }
    _saveData();
    notifyListeners();
  }

  void toggleItem(String itemId) {
    for (var category in _categories) {
      final itemIndex = category.items.indexWhere((item) => item.id == itemId);
      if (itemIndex != -1) {
        category.items[itemIndex].isCompleted =
            !category.items[itemIndex].isCompleted;
        _saveData();
        notifyListeners();
        return;
      }
    }
  }

  void deleteItem(String itemId) {
    for (var category in _categories) {
      category.items.removeWhere((item) => item.id == itemId);
    }
    _saveData();
    notifyListeners();
  }

  void moveItemToCategory(String itemId, String? newCategoryId) {
    models.ChecklistItem? itemToMove;

    // Find and remove the item from its current category
    for (var category in _categories) {
      final itemIndex = category.items.indexWhere((item) => item.id == itemId);
      if (itemIndex != -1) {
        itemToMove = category.items.removeAt(itemIndex);
        break;
      }
    }

    if (itemToMove != null) {
      itemToMove.categoryId = newCategoryId;

      if (newCategoryId != null) {
        final newCategory =
            _categories.firstWhere((cat) => cat.id == newCategoryId);
        newCategory.items.add(itemToMove);
      } else {
        // Move to uncategorized
        if (_categories.isNotEmpty) {
          _categories.first.items.add(itemToMove);
        }
      }

      _saveData();
      notifyListeners();
    }
  }

  // Get items for a specific category
  List<models.ChecklistItem> getItemsForCategory(String categoryId) {
    final category = _categories.firstWhere((cat) => cat.id == categoryId);
    return category.items
        .where((item) => item.categoryId == categoryId)
        .toList();
  }

  // Get uncategorized items
  List<models.ChecklistItem> getUncategorizedItems() {
    List<models.ChecklistItem> uncategorized = [];
    for (var category in _categories) {
      uncategorized
          .addAll(category.items.where((item) => item.categoryId == null));
    }
    return uncategorized;
  }
}
