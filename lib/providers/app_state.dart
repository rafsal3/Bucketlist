import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart' as models;
import '../models/space_model.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  List<Space> _spaces = [];
  String _currentSpaceId = '';
  bool _isLoading = true;
  bool _isDarkMode = false;
  String _themeColor = 'blue'; // Default theme color

  // Authentication state
  bool _isAuthenticated = false;
  String _currentUser = '';
  String? _authToken;

  // API Service
  final ApiService _apiService = ApiService();

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

  // Authentication getters
  bool get isAuthenticated => _isAuthenticated;
  String get currentUser => _currentUser;

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

      // Load authentication state
      _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
      _currentUser = prefs.getString('currentUser') ?? '';
      _authToken = prefs.getString('authToken');

      // Set token in API service
      if (_authToken != null) {
        _apiService.setToken(_authToken);
      }

      if (_isAuthenticated && _authToken != null) {
        await _fetchInitialData();
      } else {
        // Fallback for unauthenticated state (shouldn't happen in pure API mode, but safe to keep empty)
        // Or if we want to allow offline access to previously cached data, we'd need to keep loading it.
        // User requested removing dummy/local data, so we'll just initialize empty or basic.
        if (_spaces.isEmpty) {
          _spaces = [
            Space(
              id: 'personal_space',
              name: 'Personal',
              icon: '👤',
              categories: [],
            )
          ];
          _currentSpaceId = 'personal_space';
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save authentication state
      await prefs.setBool('isAuthenticated', _isAuthenticated);
      await prefs.setString('currentUser', _currentUser);
      if (_authToken != null) {
        await prefs.setString('authToken', _authToken!);
      }
    } catch (e) {
      debugPrint('Error saving data: $e');
    }
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
  Future<void> addSpace(String name, String icon) async {
    try {
      final newSpaceData =
          await _apiService.createSpace(name: name, icon: icon);
      // Add default categories
      final defaultCats = _getDefaultCategories();
      for (var cat in defaultCats) {
        await _apiService.createCategory(
            spaceId: newSpaceData['id'], name: cat.name, icon: cat.icon);
      }

      await _fetchInitialData();
      switchSpace(newSpaceData['id']);
    } catch (e) {
      debugPrint('Error adding space: $e');
    }
  }

  Future<void> editSpace(String spaceId, String name, String icon) async {
    try {
      await _apiService.updateSpace(spaceId: spaceId, name: name, icon: icon);
      await _fetchInitialData();
    } catch (e) {
      debugPrint('Error editing space: $e');
    }
  }

  Future<void> toggleSpaceVisibility(String spaceId) async {
    final spaceIndex = _spaces.indexWhere((s) => s.id == spaceId);
    if (spaceIndex != -1) {
      final space = _spaces[spaceIndex];
      // Optimistic update
      space.isHidden = !space.isHidden;
      notifyListeners();

      try {
        await _apiService.toggleSpaceVisibility(spaceId, space.isHidden);
      } catch (e) {
        debugPrint('Error toggling space visibility: $e');
        // Revert
        space.isHidden = !space.isHidden;
        notifyListeners();
      }
    }
  }

  Future<void> reorderSpaces(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final space = _spaces.removeAt(oldIndex);
    _spaces.insert(newIndex, space);
    notifyListeners();

    try {
      final spaceIds = _spaces.map((s) => s.id).toList();
      await _apiService.reorderSpaces(spaceIds);
    } catch (e) {
      debugPrint('Error reordering spaces: $e');
      await _fetchInitialData();
    }
  }

  void switchSpace(String spaceId) {
    if (_spaces.any((s) => s.id == spaceId)) {
      _currentSpaceId = spaceId;
      _loadSpaceDetails(spaceId); // Fetch details on switch
      notifyListeners();
    }
  }

  Future<void> deleteSpace(String spaceId) async {
    try {
      await _apiService.deleteSpace(spaceId);
      await _fetchInitialData();
    } catch (e) {
      debugPrint('Error deleting space: $e');
    }
  }

  Future<void> addCategory(String name, String icon) async {
    try {
      await _apiService.createCategory(
          spaceId: _currentSpaceId, name: name, icon: icon);
      await _loadSpaceDetails(_currentSpaceId);
    } catch (e) {
      debugPrint('Error adding category: $e');
    }
  }

  Future<void> editCategory(String categoryId, String name, String icon) async {
    try {
      await _apiService.updateCategory(
          spaceId: _currentSpaceId,
          categoryId: categoryId,
          name: name,
          icon: icon);
      await _loadSpaceDetails(_currentSpaceId);
    } catch (e) {
      debugPrint('Error editing category: $e');
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await _apiService.deleteCategory(_currentSpaceId, categoryId);
      await _loadSpaceDetails(_currentSpaceId);
    } catch (e) {
      debugPrint('Error deleting category: $e');
    }
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

  Future<void> addItem(String? categoryId, String text,
      {String? imageUrl, String? description}) async {
    try {
      await _apiService.createItem(
          spaceId: _currentSpaceId,
          text: text,
          categoryId: categoryId,
          imageUrl: imageUrl,
          description: description);
      await _loadSpaceDetails(_currentSpaceId);
    } catch (e) {
      debugPrint('Error adding item: $e');
    }
  }

  Future<void> reorderItems(
      String categoryId, int oldIndex, int newIndex) async {
    // Find the category
    final categoryIndex = categories.indexWhere((cat) => cat.id == categoryId);
    if (categoryIndex == -1) return;

    final category = categories[categoryIndex];

    // Adjust newIndex if moving down
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // Perform reorder
    final item = category.items.removeAt(oldIndex);
    category.items.insert(newIndex, item);
    notifyListeners();

    try {
      final itemIds = category.items.map((i) => i.id).toList();
      await _apiService.reorderItems(_currentSpaceId, categoryId, itemIds);
    } catch (e) {
      debugPrint('Error reordering items: $e');
      await _loadSpaceDetails(_currentSpaceId);
    }
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final category = categories.removeAt(oldIndex);
    categories.insert(newIndex, category);
    notifyListeners();

    try {
      final categoryIds = categories.map((c) => c.id).toList();
      await _apiService.reorderCategories(_currentSpaceId, categoryIds);
    } catch (e) {
      debugPrint('Error reordering categories: $e');
      await _loadSpaceDetails(_currentSpaceId);
    }
  }

  Future<void> toggleCategoryVisibility(String categoryId) async {
    final categoryIndex = categories.indexWhere((cat) => cat.id == categoryId);
    if (categoryIndex != -1) {
      // Optimistic
      categories[categoryIndex].isHidden = !categories[categoryIndex].isHidden;
      notifyListeners();

      try {
        await _apiService.toggleCategoryVisibility(
            _currentSpaceId, categoryId, categories[categoryIndex].isHidden);
      } catch (e) {
        debugPrint('Error toggling category visibility: $e');
        // Revert
        categories[categoryIndex].isHidden =
            !categories[categoryIndex].isHidden;
        notifyListeners();
      }
    }
  }

  Future<void> toggleItem(String itemId) async {
    try {
      // Optimistic updatish? No, let's just wait for API to ensure sync
      // But user experience is better with optimistic.
      // We'll update local state first then call API.
      // ... actually, simpler to just call API and reload for now to guarantee truth.

      await _apiService.toggleItem(_currentSpaceId, itemId);

      // Update local state without full reload if possible?
      // Finding the item and toggling it locally:
      for (var category in categories) {
        final item = category.items.where((i) => i.id == itemId).firstOrNull;
        if (item != null) {
          item.isCompleted = !item.isCompleted;
          notifyListeners();
          break;
        }
      }

      // We could also reload:
      // await _loadSpaceDetails(_currentSpaceId);
    } catch (e) {
      debugPrint('Error toggling item: $e');
      await _loadSpaceDetails(_currentSpaceId); // Revert on error
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _apiService.deleteItem(_currentSpaceId, itemId);
      await _loadSpaceDetails(_currentSpaceId);
    } catch (e) {
      debugPrint('Error deleting item: $e');
    }
  }

  Future<void> moveItemToCategory(String itemId, String? newCategoryId) async {
    try {
      // Optimistic or wait?
      // Moving implies removing from one list and adding to another.
      // Complexity of local optimistic move matches previous implementation, but syncing with API is safer.
      await _apiService.moveItem(_currentSpaceId, itemId, newCategoryId);
      await _loadSpaceDetails(_currentSpaceId);
    } catch (e) {
      debugPrint('Error moving item: $e');
    }
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

  // Authentication methods
  Future<bool> login(String username, String password) async {
    try {
      final response = await _apiService.login(
        email: username,
        password: password,
      );

      _isAuthenticated = true;
      _currentUser = response.email;
      _authToken = response.token;
      _apiService.setToken(_authToken);

      await _saveData();
      await _fetchInitialData(); // Load user data from API
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<bool> register(String username, String password,
      {String? name}) async {
    try {
      final response = await _apiService.register(
        email: username,
        password: password,
        name: name ?? username.split('@').first,
      );

      _isAuthenticated = true;
      _currentUser = response.email;
      _authToken = response.token;
      _apiService.setToken(_authToken);

      await _saveData();
      await _fetchInitialData(); // Load user data from API
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _currentUser = '';
    _authToken = null;
    _apiService.setToken(null);
    await _saveData();
    notifyListeners();
  }

  // Get API service instance for other operations
  ApiService get apiService => _apiService;

  // API Data Fetching Methods
  Future<void> _fetchInitialData() async {
    try {
      final spacesList = await _apiService.getSpaces(includeHidden: true);

      if (spacesList.isEmpty) {
        // If no spaces, create default Personal space
        final newSpace =
            await _apiService.createSpace(name: 'Personal', icon: '👤');
        // Create default categories
        final defaultCats = _getDefaultCategories();
        for (var cat in defaultCats) {
          await _apiService.createCategory(
              spaceId: newSpace['id'], name: cat.name, icon: cat.icon);
        }
        // Fetch again
        await _fetchInitialData();
        return;
      }

      _spaces = spacesList
          .map((data) => Space(
                id: data['id'],
                name: data['name'],
                icon: data['icon'],
                isHidden: data['isHidden'] ?? false,
                categories: [],
              ))
          .toList();

      // Determine current space
      if (_spaces.isNotEmpty && !_spaces.any((s) => s.id == _currentSpaceId)) {
        // Try getting from prefs first if we want persistence across restarts
        // But for now just pick first
        _currentSpaceId = _spaces.first.id;
      }

      if (_currentSpaceId.isNotEmpty) {
        await _loadSpaceDetails(_currentSpaceId);
      }
    } catch (e) {
      debugPrint('Error fetching initial data: $e');
    }
  }

  Future<void> _loadSpaceDetails(String spaceId) async {
    try {
      // Fetch categories
      final categoriesList =
          await _apiService.getCategories(spaceId, includeHidden: true);

      // Fetch items
      // Fetch all items (limit 1000)
      final allItemsData = await _apiService.getItems(spaceId, limit: 1000);
      final itemsList = allItemsData['items'] as List;

      // Map Items
      final allItems =
          itemsList.map((i) => models.ChecklistItem.fromJson(i)).toList();

      // Map Categories
      final newCategories = categoriesList.map((catData) {
        final catId = catData['id'];
        final catItems =
            allItems.where((item) => item.categoryId == catId).toList();

        return models.Category(
          id: catId,
          name: catData['name'],
          icon: catData['icon'],
          isHidden: catData['isHidden'] ?? false,
          items: catItems,
        );
      }).toList();

      // Handle uncategorized items: put them in the first category's list so getUncategorizedItems finds them
      // OR better: Create a hidden "Uncategorized" bucket if we can't find a place?
      // The current logic `getUncategorizedItems` iterates ALL categories.
      // So we can just append them to the first category (or any) and they will be found.
      final uncategorizedItems =
          allItems.where((item) => item.categoryId == null).toList();
      if (newCategories.isNotEmpty && uncategorizedItems.isNotEmpty) {
        newCategories.first.items.addAll(uncategorizedItems);
      }

      // Update the space
      final index = _spaces.indexWhere((s) => s.id == spaceId);
      if (index != -1) {
        _spaces[index].categories = newCategories;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading space details: $e');
    }
  }
}
