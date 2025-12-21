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

  void addItem(String categoryId, String text) {
    final category = _categories.firstWhere((cat) => cat.id == categoryId);
    final item = models.ChecklistItem(
      id: 'item_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
    );
    category.items.add(item);
    _saveData();
    notifyListeners();
  }

  void toggleItem(String categoryId, String itemId) {
    final category = _categories.firstWhere((cat) => cat.id == categoryId);
    final item = category.items.firstWhere((item) => item.id == itemId);
    item.isCompleted = !item.isCompleted;
    _saveData();
    notifyListeners();
  }

  void deleteItem(String categoryId, String itemId) {
    final category = _categories.firstWhere((cat) => cat.id == categoryId);
    category.items.removeWhere((item) => item.id == itemId);
    _saveData();
    notifyListeners();
  }
}
