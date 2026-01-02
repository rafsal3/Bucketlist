import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart' as models;
import '../models/space_model.dart';
import '../models/sync_status.dart';
import '../services/sync_api_service.dart';

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

  // Authentication state
  bool _isLoggedIn = false;
  String? _userEmail;
  String? _authToken;

  // Sync infrastructure
  final SyncApiService _syncApi = SyncApiService();
  Timer? _syncDebounceTimer;
  int _dataVersion = 0; // Server version number
  bool _isSyncing = false; // Prevent concurrent syncs

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

  // Authentication getters
  bool get isLoggedIn => _isLoggedIn;
  String? get userEmail => _userEmail;
  String? get authToken => _authToken;

  int get totalCompleted =>
      categories.fold<int>(0, (sum, cat) => sum + cat.completedCount);
  int get totalItems =>
      categories.fold<int>(0, (sum, cat) => sum + cat.totalCount);
  double get overallProgress =>
      totalItems == 0 ? 0.0 : totalCompleted / totalItems;

  AppState() {
    _loadData();
    // ❌ NEVER auto-pull from cloud on startup
    // ✅ Only loads local data from SharedPreferences
  }

  /// Loads data from local storage ONLY
  /// ❌ NEVER fetches from cloud automatically
  /// ✅ Push-only sync - no auto-pull on launch
  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _themeColor = prefs.getString('themeColor') ?? 'blue';
      _lastModifiedAt = prefs.getInt('lastModifiedAt') ?? 0;

      // Load authentication state
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      _userEmail = prefs.getString('userEmail');
      _authToken = prefs.getString('authToken');

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
  // AUTHENTICATION METHODS
  // ============================================================================

  /// Login user with email and auth token
  /// SPECIAL CASE: If local DB is empty, pulls from cloud (new device login)
  Future<void> login(String email, String token) async {
    _isLoggedIn = true;
    _userEmail = email;
    _authToken = token;

    // Persist authentication state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userEmail', email);
    await prefs.setString('authToken', token);

    notifyListeners();

    // ✅ SPECIAL CASE: Pull from cloud ONLY if local DB is empty
    // This handles new device login scenario
    if (_isLocalDatabaseEmpty()) {
      debugPrint('📥 Local DB is empty, pulling from cloud...');
      await _pullFromCloud();
    } else {
      debugPrint('📱 Local DB has data, keeping local data');
      // ❌ NEVER auto-pull if local data exists
      // ✅ User data stays local until they make changes
    }
  }

  /// Logout user and clear authentication data
  Future<void> logout() async {
    _isLoggedIn = false;
    _userEmail = null;
    _authToken = null;

    // Clear authentication state from storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('userEmail');
    await prefs.remove('authToken');

    // Reset sync status
    _syncStatus = SyncStatus.localOnly;
    _syncErrorMessage = null;

    notifyListeners();
  }

  // ============================================================================
  // CLOUD SYNC METHODS
  // ============================================================================

  /// Triggers a debounced sync to cloud
  /// Waits 2 seconds after last change before syncing
  void _markSyncPending() {
    // Cancel existing timer if any
    _syncDebounceTimer?.cancel();

    // Only sync if logged in
    if (!_isLoggedIn || _authToken == null) {
      return;
    }

    // Set up new debounced timer (2 seconds)
    _syncDebounceTimer = Timer(const Duration(seconds: 2), () {
      _pushToCloud();
    });
  }

  /// Push local data to cloud
  Future<void> _pushToCloud() async {
    // Prevent concurrent syncs
    if (_isSyncing) {
      debugPrint('Sync already in progress, skipping...');
      return;
    }

    // Must be logged in
    if (!_isLoggedIn || _authToken == null) {
      debugPrint('Not logged in, skipping sync');
      return;
    }

    _isSyncing = true;
    setSyncing(); // Update UI to show syncing status

    try {
      // Prepare data payload
      final data = {
        'spaces': _spaces.map((space) => space.toJson()).toList(),
        'currentSpaceId': _currentSpaceId,
        'themeColor': _themeColor,
        'isDarkMode': _isDarkMode,
      };

      debugPrint(
          'Pushing to cloud... version: $_dataVersion, lastModified: $_lastModifiedAt');

      // Call API
      final response = await _syncApi.pushToCloud(
        authToken: _authToken!,
        version: _dataVersion,
        lastModifiedAt: _lastModifiedAt,
        data: data,
      );

      // Update version from server
      if (response.containsKey('version')) {
        _dataVersion = response['version'] as int;
      }

      // Mark as synced
      setSynced();
      debugPrint('✅ Sync successful! New version: $_dataVersion');
    } catch (e) {
      // Handle error
      final errorMessage = e.toString();
      debugPrint('❌ Sync failed: $errorMessage');

      // Check if it's a token expiration error
      if (_isTokenExpiredError(errorMessage)) {
        debugPrint('🔑 Token expired, pausing sync');
        _handleTokenExpiration();
      } else {
        // Regular sync error - show error but keep local changes
        setSyncError(errorMessage);

        // Schedule automatic retry after 30 seconds
        _scheduleRetry();
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Check if error is due to token expiration
  bool _isTokenExpiredError(String error) {
    final lowerError = error.toLowerCase();
    return lowerError.contains('token') &&
        (lowerError.contains('expired') ||
            lowerError.contains('invalid') ||
            lowerError.contains('unauthorized') ||
            lowerError.contains('401'));
  }

  /// Handle token expiration
  void _handleTokenExpiration() {
    // Pause syncing
    _syncDebounceTimer?.cancel();

    // Set error status with specific message
    setSyncError('Session expired. Please login again.');

    // Note: User will need to re-login
    // After re-login, sync will automatically resume
    debugPrint('⏸️ Sync paused. Waiting for re-login...');
  }

  /// Schedule automatic retry for failed sync
  void _scheduleRetry() {
    // Cancel any existing retry timer
    _syncDebounceTimer?.cancel();

    // Schedule retry after 30 seconds
    debugPrint('⏰ Scheduling retry in 30 seconds...');
    _syncDebounceTimer = Timer(const Duration(seconds: 30), () {
      debugPrint('🔄 Retrying sync...');
      _pushToCloud();
    });
  }

  /// Manually trigger sync (for pull-to-refresh, etc.)
  Future<void> manualSync() async {
    await _pushToCloud();
  }

  /// Check if local database is empty
  /// Returns true if no spaces exist (fresh install or cleared data)
  bool _isLocalDatabaseEmpty() {
    return _spaces.isEmpty;
  }

  /// Pull data from cloud and replace local database completely
  /// ⚠️ ONLY called when local DB is empty (new device login)
  /// ⚠️ NEVER merges - always replaces completely
  Future<void> _pullFromCloud() async {
    // Must be logged in
    if (!_isLoggedIn || _authToken == null) {
      debugPrint('Not logged in, cannot pull from cloud');
      return;
    }

    setSyncing(); // Update UI to show syncing status

    try {
      debugPrint('Pulling from cloud...');

      // Call API
      final response = await _syncApi.pullFromCloud(
        authToken: _authToken!,
      );

      // Extract data and version
      final version = response['version'] as int?;
      final data = response['data'] as Map<String, dynamic>?;

      if (data == null) {
        throw Exception('No data received from server');
      }

      debugPrint('Received data from cloud, version: $version');

      // ⚠️ STEP 1: Clear local database completely
      _spaces.clear();
      debugPrint('🗑️ Local DB cleared');

      // ⚠️ STEP 2: Replace with remote data (NEVER merge)
      if (data.containsKey('spaces')) {
        final List<dynamic> spacesData = data['spaces'] as List<dynamic>;
        _spaces = spacesData.map((json) => Space.fromJson(json)).toList();
        debugPrint('📥 Loaded ${_spaces.length} spaces from cloud');
      }

      // Restore other settings
      if (data.containsKey('currentSpaceId')) {
        _currentSpaceId = data['currentSpaceId'] as String;
      } else if (_spaces.isNotEmpty) {
        _currentSpaceId = _spaces.first.id;
      }

      if (data.containsKey('themeColor')) {
        _themeColor = data['themeColor'] as String;
      }

      if (data.containsKey('isDarkMode')) {
        _isDarkMode = data['isDarkMode'] as bool;
      }

      // Update version from server
      if (version != null) {
        _dataVersion = version;
      }

      // Update lastModifiedAt to current time
      _lastModifiedAt = DateTime.now().millisecondsSinceEpoch;

      // Save to local storage
      await _saveData();

      // Mark as synced
      setSynced();
      debugPrint(
          '✅ Pull successful! Version: $_dataVersion, Spaces: ${_spaces.length}');

      // Notify UI
      notifyListeners();
    } catch (e) {
      // Handle error
      debugPrint('❌ Pull failed: $e');
      setSyncError(e.toString());
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
  /// 6. Cloud sync is triggered (debounced)
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

    // 5. Trigger debounced cloud sync (if logged in)
    _markSyncPending();
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
