import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart' as models;
import '../models/space_model.dart';
import '../models/person_model.dart';
import '../models/notification_model.dart';

class AppState extends ChangeNotifier {
  List<Space> _spaces = [];
  String _currentSpaceId = '';
  bool _isLoading = true;
  bool _isDarkMode = false;
  String _themeColor = 'blue'; // Default theme color

  // Collaboration features
  List<Person> _people = [];
  List<AppNotification> _notifications = [];
  final String currentUserId = 'user_001'; // Dummy current user ID

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

  // Collaboration getters
  List<Person> get people => _people;
  List<AppNotification> get notifications => _notifications;
  int get unreadNotificationCount =>
      _notifications.where((n) => !n.isRead).length;

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
  void addSpace(String name, String icon) {
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
    _saveData();
    notifyListeners();
  }

  void editSpace(String spaceId, String name, String icon) {
    final spaceIndex = _spaces.indexWhere((s) => s.id == spaceId);
    if (spaceIndex != -1) {
      _spaces[spaceIndex].name = name;
      _spaces[spaceIndex].icon = icon;
      _saveData();
      notifyListeners();
    }
  }

  void toggleSpaceVisibility(String spaceId) {
    // Prevent hiding the current space or the last visible space if possible,
    // but for now just toggle.
    final spaceIndex = _spaces.indexWhere((s) => s.id == spaceId);
    if (spaceIndex != -1) {
      _spaces[spaceIndex].isHidden = !_spaces[spaceIndex].isHidden;
      _saveData();
      notifyListeners();
    }
  }

  void reorderSpaces(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final space = _spaces.removeAt(oldIndex);
    _spaces.insert(newIndex, space);
    _saveData();
    notifyListeners();
  }

  void switchSpace(String spaceId) {
    if (_spaces.any((s) => s.id == spaceId)) {
      _currentSpaceId = spaceId;
      _saveData();
      notifyListeners();
    }
  }

  void deleteSpace(String spaceId) {
    if (_spaces.length <= 1) return; // Prevent deleting last space

    _spaces.removeWhere((s) => s.id == spaceId);

    if (_currentSpaceId == spaceId) {
      // Switch to the first available space
      _currentSpaceId = _spaces.first.id;
    }

    _saveData();
    notifyListeners();
  }

  void addCategory(String name, String icon) {
    final category = models.Category(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      icon: icon,
    );
    currentSpace.categories.add(category);
    _saveData();
    notifyListeners();
  }

  void editCategory(String categoryId, String name, String icon) {
    final categoryIndex =
        currentSpace.categories.indexWhere((cat) => cat.id == categoryId);
    if (categoryIndex != -1) {
      currentSpace.categories[categoryIndex].name = name;
      currentSpace.categories[categoryIndex].icon = icon;
      _saveData();
      notifyListeners();
    }
  }

  void deleteCategory(String categoryId) {
    currentSpace.categories.removeWhere((cat) => cat.id == categoryId);
    _saveData();
    notifyListeners();
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
    _saveData();
    notifyListeners();
  }

  void reorderItems(String categoryId, int oldIndex, int newIndex) {
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

    _saveData();
    notifyListeners();
  }

  void reorderCategories(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final category = categories.removeAt(oldIndex);
    categories.insert(newIndex, category);
    _saveData();
    notifyListeners();
  }

  void toggleCategoryVisibility(String categoryId) {
    final categoryIndex = categories.indexWhere((cat) => cat.id == categoryId);
    if (categoryIndex != -1) {
      categories[categoryIndex].isHidden = !categories[categoryIndex].isHidden;
      _saveData();
      notifyListeners();
    }
  }

  void toggleItem(String itemId) {
    for (var category in categories) {
      final itemIndex = category.items.indexWhere((item) => item.id == itemId);
      if (itemIndex != -1) {
        final item = category.items[itemIndex];

        // If this is a shared space, track per-user completion
        if (currentSpace.isShared) {
          final isCurrentlyCompleted =
              item.userCompletions[currentUserId] ?? false;
          item.userCompletions[currentUserId] = !isCurrentlyCompleted;

          // Update overall completion if all users completed
          final allUserIds = currentSpace.getAllUserIds();
          item.isCompleted = item.isCompletedByAll(allUserIds);
        } else {
          // Regular toggle for non-shared spaces
          item.isCompleted = !item.isCompleted;
        }

        _saveData();
        notifyListeners();
        return;
      }
    }
  }

  void deleteItem(String itemId) {
    for (var category in categories) {
      category.items.removeWhere((item) => item.id == itemId);
    }
    _saveData();
    notifyListeners();
  }

  void moveItemToCategory(String itemId, String? newCategoryId) {
    models.ChecklistItem? itemToMove;

    // Find and remove the item from its current category
    for (var category in categories) {
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
            categories.firstWhere((cat) => cat.id == newCategoryId);
        newCategory.items.insert(0, itemToMove); // Insert at beginning
      } else {
        // Move to uncategorized
        if (categories.isNotEmpty) {
          categories.first.items.insert(0, itemToMove); // Insert at beginning
        }
      }

      _saveData();
      notifyListeners();
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

  // ===== COLLABORATION FEATURES =====

  // People Management
  void addPerson(Person person) {
    _people.add(person);
    _saveData();
    notifyListeners();
  }

  void removePerson(String personId) {
    _people.removeWhere((p) => p.id == personId);

    // Remove from all shared spaces
    for (var space in _spaces) {
      space.collaboratorIds.removeWhere((id) => id == personId);
    }

    _saveData();
    notifyListeners();
  }

  Person? getPersonById(String personId) {
    try {
      return _people.firstWhere((p) => p.id == personId);
    } catch (e) {
      return null;
    }
  }

  // Connect via unique code (dummy implementation)
  void connectViaCode(String code) {
    // Simulate finding a person by code
    final dummyPerson = _generateDummyPerson(code);
    addPerson(dummyPerson);
  }

  // Notification Management
  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    _saveData();
    notifyListeners();
  }

  void markNotificationAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index].isRead = true;
      _saveData();
      notifyListeners();
    }
  }

  void deleteNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _saveData();
    notifyListeners();
  }

  void acceptSpaceInvite(String notificationId, String spaceId) {
    // In a real app, this would join the space
    // For now, just remove the notification
    deleteNotification(notificationId);
  }

  void declineSpaceInvite(String notificationId) {
    deleteNotification(notificationId);
  }

  // Space Collaboration
  void addCollaboratorsToSpace(String spaceId, List<String> personIds) {
    final spaceIndex = _spaces.indexWhere((s) => s.id == spaceId);
    if (spaceIndex != -1) {
      for (var personId in personIds) {
        if (!_spaces[spaceIndex].collaboratorIds.contains(personId)) {
          _spaces[spaceIndex].collaboratorIds.add(personId);
        }
      }
      _spaces[spaceIndex].ownerId = currentUserId;
      _saveData();
      notifyListeners();

      // Send dummy invites
      for (var personId in personIds) {
        final person = getPersonById(personId);
        if (person != null) {
          _sendSpaceInvite(_spaces[spaceIndex], person);
        }
      }
    }
  }

  void _sendSpaceInvite(Space space, Person person) {
    // This is a dummy - in real app this would send to the other user
    // For demo, we just add to our own notifications
    final notification = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.spaceInvite,
      title: 'Space Invite',
      message: '${person.name} invited you to "${space.name}"',
      personId: person.id,
      personName: person.name,
      spaceId: space.id,
      spaceName: space.name,
    );
    addNotification(notification);
  }

  // Dummy data generators for testing
  Person _generateDummyPerson(String code) {
    final names = ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank'];
    final colors = [
      '#FF6B6B',
      '#4ECDC4',
      '#45B7D1',
      '#FFA07A',
      '#98D8C8',
      '#F7DC6F'
    ];
    final random = Random();

    return Person(
      id: 'person_${DateTime.now().millisecondsSinceEpoch}',
      name: names[random.nextInt(names.length)],
      uniqueCode: code.toUpperCase(),
      avatarColor: colors[random.nextInt(colors.length)],
    );
  }

  void generateDummyPeople() {
    if (_people.isNotEmpty) return; // Don't generate if already have people

    final dummyPeople = [
      Person(
        id: 'person_001',
        name: 'Sarah Johnson',
        uniqueCode: 'ABC123',
        avatarColor: '#FF6B6B',
      ),
      Person(
        id: 'person_002',
        name: 'Mike Chen',
        uniqueCode: 'XYZ789',
        avatarColor: '#4ECDC4',
      ),
      Person(
        id: 'person_003',
        name: 'Emma Davis',
        uniqueCode: 'DEF456',
        avatarColor: '#45B7D1',
      ),
    ];

    _people.addAll(dummyPeople);
    notifyListeners();
  }

  void generateDummyNotifications() {
    if (_notifications.isNotEmpty) return;

    final dummyNotifications = [
      AppNotification(
        id: 'notif_001',
        type: NotificationType.spaceInvite,
        title: 'Space Invite',
        message: 'Sarah Johnson invited you to "Family Goals"',
        personId: 'person_001',
        personName: 'Sarah Johnson',
        spaceId: 'space_dummy_001',
        spaceName: 'Family Goals',
        timestamp: DateTime.now().subtract(Duration(hours: 2)),
      ),
      AppNotification(
        id: 'notif_002',
        type: NotificationType.spaceInvite,
        title: 'Space Invite',
        message: 'Mike Chen invited you to "Travel Bucket List"',
        personId: 'person_002',
        personName: 'Mike Chen',
        spaceId: 'space_dummy_002',
        spaceName: 'Travel Bucket List',
        timestamp: DateTime.now().subtract(Duration(days: 1)),
      ),
    ];

    _notifications.addAll(dummyNotifications);
    notifyListeners();
  }
}
