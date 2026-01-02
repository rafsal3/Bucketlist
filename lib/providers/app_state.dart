import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart' as models;
import '../models/space_model.dart';
import '../models/sync_status.dart';

class AppState extends ChangeNotifier {
  List<Space> _spaces = [];
  String _currentSpaceId = '';
  bool _isLoading = true;
  bool _isDarkMode = false;
  String _themeColor = 'blue'; // Default theme color
  int _lastModifiedAt = 0; // Global timestamp for sync decisions

  // Sync state (UI-only, not persisted with data)
  SyncStatus _syncStatus = SyncStatus.localOnly;
  String? _syncErrorMessage;

  // Getters for the current space
  Space get currentSpace => _spaces.firstWhere(
        (s) => s.id == _currentSpaceId,
        orElse: () => _spaces.isNotEmpty
            ? _spaces.first
            : Space(id: 'temp', name: 'Loading', categories: []),
      );

  List<Space> get spaces => _spaces;
  List<models.Category> get categories => currentSpace.categories;

  bool get isLoading => _isLoading;
  bool get isDarkMode => _isDarkMode;
  String get themeColor => _themeColor;
  int get lastModifiedAt => _lastModifiedAt;

  // Sync state getters
  SyncStatus get syncStatus => _syncStatus;
  String? get syncErrorMessage => _syncErrorMessage;

  int get totalCompleted =>
      categories.fold<int>(0, (sum, cat) => sum + cat.completedCount);
  int get totalItems =>
      categories.fold<int>(0, (sum, cat) => sum + cat.totalCount);
  double get overallProgress =>
      totalItems == 0 ? 0.0 : totalCompleted / totalItems;

  AppState() {
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _themeColor = prefs.getString('themeColor') ?? 'blue';
      _lastModifiedAt = prefs.getInt('lastModifiedAt') ?? 0;

      final String? spacesJson = prefs.getString('spaces');

      if (spacesJson != null) {
        // Load spaces directly
        final List<dynamic> decoded = jsonDecode(spacesJson);
        _spaces = decoded.map((json) => Space.fromJson(json)).toList();
        _currentSpaceId = prefs.getString('currentSpaceId') ??
            (_spaces.isNotEmpty ? _spaces.first.id : '');
      } else {
        // Legacy migration or fresh install
        final String? categoriesJson = prefs.getString('categories');
        List<models.Category> initialCategories;

        if (categoriesJson != null) {
          // Migration: Load existing categories
          final List<dynamic> decoded = jsonDecode(categoriesJson);
          initialCategories =
              decoded.map((json) => models.Category.fromJson(json)).toList();
        } else {
          // Fresh install: Default categories
          initialCategories = _getDefaultCategories();
        }

        // Create default "Personal" space
        final personalSpace = Space(
          id: 'personal_space',
          name: 'Personal',
          icon: '👤',
          categories: initialCategories,
        );

        _spaces = [personalSpace];
        _currentSpaceId = personalSpace.id;

        // Save immediately to complete migration
        _saveData();
      }

      // Safety check if currentSpaceId is invalid
      if (!_spaces.any((s) => s.id == _currentSpaceId) && _spaces.isNotEmpty) {
        _currentSpaceId = _spaces.first.id;
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      // Fallback
      _spaces = [
        Space(
          id: 'personal_space',
          name: 'Personal',
          icon: '👤',
          categories: _getDefaultCategories(),
        )
      ];
      _currentSpaceId = 'personal_space';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save spaces
      final String encoded =
          jsonEncode(_spaces.map((space) => space.toJson()).toList());
      await prefs.setString('spaces', encoded);

      // Save current space selection
      await prefs.setString('currentSpaceId', _currentSpaceId);

      // Save lastModifiedAt
      await prefs.setInt('lastModifiedAt', _lastModifiedAt);
    } catch (e) {
      debugPrint('Error saving data: $e');
    }
  }

  /// Updates the global lastModifiedAt timestamp to current time
  /// Call this whenever any data is created, modified, moved, reordered, or toggled
  void _updateLastModified() {
    _lastModifiedAt = DateTime.now().millisecondsSinceEpoch;
    // Mark as local only since we have unsaved changes
    if (_syncStatus == SyncStatus.synced) {
      _syncStatus = SyncStatus.localOnly;
    }
  }

  // Sync Status Management Methods

  /// Sets sync status to syncing
  void setSyncing() {
    _syncStatus = SyncStatus.syncing;
    _syncErrorMessage = null;
    notifyListeners();
  }

  /// Sets sync status to synced
  void setSynced() {
    _syncStatus = SyncStatus.synced;
    _syncErrorMessage = null;
    notifyListeners();
  }

  /// Sets sync status to error with optional error message
  void setSyncError([String? errorMessage]) {
    _syncStatus = SyncStatus.error;
    _syncErrorMessage = errorMessage;
    notifyListeners();
  }

  /// Sets sync status to local only
  void setLocalOnly() {
    _syncStatus = SyncStatus.localOnly;
    _syncErrorMessage = null;
    notifyListeners();
  }

  /// Clears sync error and returns to previous state
  void clearSyncError() {
    if (_syncStatus == SyncStatus.error) {
      _syncStatus = SyncStatus.localOnly;
      _syncErrorMessage = null;
      notifyListeners();
    }
  }

  // ============================================================================
  // UNIFIED MUTATION WRAPPER
  // ============================================================================

  /// **CRITICAL**: All data mutations MUST go through this function.
  /// This ensures:
  /// 1. Local data is modified
  /// 2. lastModifiedAt timestamp is updated
  /// 3. Sync status is marked as pending (localOnly)
  /// 4. Data is persisted to storage
  /// 5. UI is notified
  ///
  /// This makes cloud sync trivial later - just add sync logic here!
  Future<void> mutateData(Function action) async {
    // 1. Execute the mutation action
    action();

    // 2. Update timestamp and mark as needing sync
    _updateLastModified();

    // 3. Persist to local storage
    await _saveData();

    // 4. Notify UI listeners
    notifyListeners();

    // TODO: In Phase 2, add cloud sync trigger here
  }

  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveTheme();
    notifyListeners();
  }

  void setThemeColor(String color) {
    _themeColor = color;
    _saveThemeColor();
    notifyListeners();
  }

  Future<void> _saveThemeColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('themeColor', _themeColor);
    } catch (e) {
      debugPrint('Error saving theme color: $e');
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

  // Space Management
  // Space Management
  void addSpace(String name, String icon) {
    mutateData(() {
      // Generate a unique ID
      final id = 'space_${DateTime.now().millisecondsSinceEpoch}';

      final newSpace = Space(
        id: id,
        name: name,
        icon: icon,
        categories: _getDefaultCategories(),
      );

      _spaces.add(newSpace);
      _currentSpaceId = id; // Switch to new space automatically
    });
  }

  void editSpace(String spaceId, String name, String icon) {
    mutateData(() {
      final spaceIndex = _spaces.indexWhere((s) => s.id == spaceId);
      if (spaceIndex != -1) {
        _spaces[spaceIndex].name = name;
        _spaces[spaceIndex].icon = icon;
      }
    });
  }

  void toggleSpaceVisibility(String spaceId) {
    mutateData(() {
      // Prevent hiding the current space or the last visible space if possible,
      // but for now just toggle.
      final spaceIndex = _spaces.indexWhere((s) => s.id == spaceId);
      if (spaceIndex != -1) {
        _spaces[spaceIndex].isHidden = !_spaces[spaceIndex].isHidden;
      }
    });
  }

  void reorderSpaces(int oldIndex, int newIndex) {
    mutateData(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final space = _spaces.removeAt(oldIndex);
      _spaces.insert(newIndex, space);
    });
  }

  void switchSpace(String spaceId) {
    if (_spaces.any((s) => s.id == spaceId)) {
      _currentSpaceId = spaceId;
      _saveData();
      notifyListeners();
    }
  }

  void deleteSpace(String spaceId) {
    mutateData(() {
      if (_spaces.length <= 1) return; // Prevent deleting last space

      _spaces.removeWhere((s) => s.id == spaceId);

      if (_currentSpaceId == spaceId) {
        // Switch to the first available space
        _currentSpaceId = _spaces.first.id;
      }
    });
  }

  void addCategory(String name, String icon) {
    mutateData(() {
      final category = models.Category(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        icon: icon,
      );
      currentSpace.categories.add(category);
    });
  }

  void editCategory(String categoryId, String name, String icon) {
    mutateData(() {
      final categoryIndex =
          currentSpace.categories.indexWhere((cat) => cat.id == categoryId);
      if (categoryIndex != -1) {
        currentSpace.categories[categoryIndex].name = name;
        currentSpace.categories[categoryIndex].icon = icon;
      }
    });
  }

  void deleteCategory(String categoryId) {
    mutateData(() {
      currentSpace.categories.removeWhere((cat) => cat.id == categoryId);
    });
  }

  // Get all items across all visible categories
  List<models.ChecklistItem> getAllItems() {
    List<models.ChecklistItem> allItems = [];
    for (var category in categories) {
      if (!category.isHidden) {
        allItems.addAll(category.items);
      }
    }
    // Sort by ID (which contains timestamp) in descending order (latest first)
    allItems.sort((a, b) {
      // Extract timestamp from ID (format: item_<timestamp>)
      final timestampA = int.tryParse(a.id.split('_').last) ?? 0;
      final timestampB = int.tryParse(b.id.split('_').last) ?? 0;
      return timestampB.compareTo(timestampA); // Descending order
    });
    return allItems;
  }

  void addItem(String? categoryId, String text,
      {String? imageUrl, String? description}) {
    mutateData(() {
      final item = models.ChecklistItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        categoryId: categoryId,
        imageUrl: imageUrl,
        description: description,
      );

      if (categoryId != null) {
        final category = categories.firstWhere((cat) => cat.id == categoryId);
        category.items.insert(0, item);
      } else {
        // For uncategorized items, we'll add them to a special handling
        // They will be stored in the first category but marked as uncategorized
        if (categories.isNotEmpty) {
          categories.first.items.insert(0, item);
        }
      }
    });
  }

  void reorderItems(String categoryId, int oldIndex, int newIndex) {
    mutateData(() {
      // Find the category
      final categoryIndex =
          categories.indexWhere((cat) => cat.id == categoryId);
      if (categoryIndex == -1) return;

      final category = categories[categoryIndex];

      // Adjust newIndex if moving down
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      // Perform reorder
      final item = category.items.removeAt(oldIndex);
      category.items.insert(newIndex, item);
    });
  }

  void reorderCategories(int oldIndex, int newIndex) {
    mutateData(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final category = categories.removeAt(oldIndex);
      categories.insert(newIndex, category);
    });
  }

  void toggleCategoryVisibility(String categoryId) {
    mutateData(() {
      final categoryIndex =
          categories.indexWhere((cat) => cat.id == categoryId);
      if (categoryIndex != -1) {
        categories[categoryIndex].isHidden =
            !categories[categoryIndex].isHidden;
      }
    });
  }

  void toggleItem(String itemId) {
    mutateData(() {
      for (var category in categories) {
        final itemIndex =
            category.items.indexWhere((item) => item.id == itemId);
        if (itemIndex != -1) {
          category.items[itemIndex].isCompleted =
              !category.items[itemIndex].isCompleted;
          return;
        }
      }
    });
  }

  void deleteItem(String itemId) {
    mutateData(() {
      for (var category in categories) {
        category.items.removeWhere((item) => item.id == itemId);
      }
    });
  }

  void moveItemToCategory(String itemId, String? newCategoryId) {
    mutateData(() {
      models.ChecklistItem? itemToMove;

      // Find and remove the item from its current category
      for (var category in categories) {
        final itemIndex =
            category.items.indexWhere((item) => item.id == itemId);
        if (itemIndex != -1) {
          itemToMove = category.items.removeAt(itemIndex);
          break;
        }
      }

      if (itemToMove != null) {
        itemToMove.categoryId = newCategoryId;

        if (newCategoryId != null) {
          final newCategory =
              categories.firstWhere((cat) => cat.id == newCategoryId);
          newCategory.items.insert(0, itemToMove); // Insert at beginning
        } else {
          // Move to uncategorized
          if (categories.isNotEmpty) {
            categories.first.items.insert(0, itemToMove); // Insert at beginning
          }
        }
      }
    });
  }

  // Get items for a specific category
  List<models.ChecklistItem> getItemsForCategory(String categoryId) {
    final category = categories.firstWhere(
      (cat) => cat.id == categoryId,
      orElse: () => models.Category(id: '', name: '', icon: ''),
    );
    // Only return items that actually belong to this category
    return category.items
        .where((item) => item.categoryId == categoryId)
        .toList();
  }

  // Get uncategorized items
  List<models.ChecklistItem> getUncategorizedItems() {
    List<models.ChecklistItem> uncategorized = [];
    for (var category in categories) {
      uncategorized
          .addAll(category.items.where((item) => item.categoryId == null));
    }
    return uncategorized;
  }
}
