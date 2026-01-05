import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/category_model.dart' as models;
import '../models/space_model.dart';
import '../models/sync_status.dart';
import '../services/google_drive_service.dart';

class AppState extends ChangeNotifier {
  List<Space> _spaces = [];
  String _currentSpaceId = '';
  bool _isLoading = true;
  bool _isRestoring = false; // Tracks restore/backup operations
  bool _isDarkMode = false;
  String _themeColor = 'blue'; // Default theme color
  int _lastModifiedAt = 0; // Global timestamp for tracking changes

  // Sync state (UI-only, not persisted with data)
  SyncStatus _syncStatus = SyncStatus.localOnly;
  String? _syncErrorMessage;

  // Authentication state (Google Sign-In)
  bool _isLoggedIn = false;
  String? _userEmail;

  // Google Drive service
  final GoogleDriveService _driveService = GoogleDriveService();
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

  bool get isLoading => _isLoading || _isRestoring;
  bool get isDarkMode => _isDarkMode;
  String get themeColor => _themeColor;
  int get lastModifiedAt => _lastModifiedAt;

  // Sync state getters
  SyncStatus get syncStatus => _syncStatus;
  String? get syncErrorMessage => _syncErrorMessage;

  // Authentication getters
  bool get isLoggedIn => _isLoggedIn;
  String? get userEmail => _userEmail;

  int get totalCompleted {
    int categoryCompleted =
        categories.fold<int>(0, (sum, cat) => sum + cat.completedCount);
    int uncategorizedCompleted = currentSpace.uncategorizedItems
        .where((item) => item.isCompleted)
        .length;
    return categoryCompleted + uncategorizedCompleted;
  }

  int get totalItems {
    int categoryTotal =
        categories.fold<int>(0, (sum, cat) => sum + cat.totalCount);
    int uncategorizedTotal = currentSpace.uncategorizedItems.length;
    return categoryTotal + uncategorizedTotal;
  }

  double get overallProgress =>
      totalItems == 0 ? 0.0 : totalCompleted / totalItems;

  AppState() {
    _loadData();
  }

  /// Loads data from local storage ONLY
  /// Never fetches from cloud automatically - offline-first approach
  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _themeColor = prefs.getString('themeColor') ?? 'blue';
      _lastModifiedAt = prefs.getInt('lastModifiedAt') ?? 0;

      // Load authentication state
      _isLoggedIn = await _driveService.isSignedIn();
      _userEmail = await _driveService.getCurrentUserEmail();

      // Load spaces from Hive
      final box = Hive.box<Space>('spaces');

      // MIGRATION: Check if we have legacy data in SharedPreferences
      final String? legacySpacesJson = prefs.getString('spaces');

      if (box.isEmpty && legacySpacesJson != null) {
        debugPrint(
            '📦 Migrating legacy data from SharedPreferences to Hive...');
        final List<dynamic> decoded = jsonDecode(legacySpacesJson);
        final legacySpaces =
            decoded.map((json) => Space.fromJson(json)).toList();

        // Add all to Hive
        await box.addAll(legacySpaces);
        _spaces = box.values.toList();

        debugPrint(
            '✅ Migration complete: Moved ${legacySpaces.length} spaces to Hive');
      } else {
        // Normal load from Hive
        _spaces = box.values.toList();
      }

      // If still empty (fresh install), create default data
      if (_spaces.isEmpty) {
        // Fresh install: Default categories
        final initialCategories = _getDefaultCategories();

        // Create default "Personal" space
        final personalSpace = Space(
          id: 'personal_space',
          name: 'Personal',
          icon: '👤',
          categories: initialCategories,
        );

        // Add to Hive
        await box.add(personalSpace);
        _spaces = [personalSpace];
        _currentSpaceId = personalSpace.id;

        // Save initial state
        _savePreferences();
      } else {
        // Load current space ID
        _currentSpaceId = prefs.getString('currentSpaceId') ??
            (_spaces.isNotEmpty ? _spaces.first.id : '');

        // Check for orphaned items (legacy fix)
        _migrateOrphanedItems();
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

  /// Saves ONLY non-space settings (preferences, auth, metadata)
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentSpaceId', _currentSpaceId);
      await prefs.setInt('lastModifiedAt', _lastModifiedAt);
      await prefs.setBool('isDarkMode', _isDarkMode);
      await prefs.setString('themeColor', _themeColor);
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    }
  }

  /// Persists spaces to Hive
  Future<void> _persistSpaces() async {
    try {
      final box = Hive.box<Space>('spaces');
      final currentIds = <String>{};

      // Update or Add spaces
      for (var space in _spaces) {
        currentIds.add(space.id);
        if (space.isInBox) {
          await space.save();
        } else {
          await box.add(space);
        }
      }

      // Handle Deletions
      final keysToDelete = <dynamic>[];
      for (var key in box.keys) {
        final space = box.get(key);
        if (space != null && !currentIds.contains(space.id)) {
          keysToDelete.add(key);
        }
      }

      if (keysToDelete.isNotEmpty) {
        await box.deleteAll(keysToDelete);
      }
    } catch (e) {
      debugPrint('Error persisting spaces to Hive: $e');
    }
  }

  /// Migrates orphaned uncategorized items from categories to dedicated storage
  void _migrateOrphanedItems() {
    bool migrationNeeded = false;

    for (var space in _spaces) {
      for (var category in space.categories) {
        final orphanedItems =
            category.items.where((item) => item.categoryId == null).toList();

        if (orphanedItems.isNotEmpty) {
          migrationNeeded = true;
          space.uncategorizedItems.addAll(orphanedItems);
          category.items.removeWhere((item) => item.categoryId == null);
        }
      }
    }

    if (migrationNeeded) {
      _persistSpaces();
    }
  }

  /// Updates the global lastModifiedAt timestamp to current time
  void _updateLastModified() {
    _lastModifiedAt = DateTime.now().millisecondsSinceEpoch;
    if (_syncStatus == SyncStatus.synced) {
      _syncStatus = SyncStatus.localOnly;
    }
  }

  // Sync Status Management Methods

  void setSyncing() {
    _syncStatus = SyncStatus.syncing;
    _syncErrorMessage = null;
    notifyListeners();
  }

  void setSynced() {
    _syncStatus = SyncStatus.synced;
    _syncErrorMessage = null;
    notifyListeners();
  }

  void setSyncError([String? errorMessage]) {
    _syncStatus = SyncStatus.error;
    _syncErrorMessage = errorMessage;
    notifyListeners();
  }

  void setLocalOnly() {
    _syncStatus = SyncStatus.localOnly;
    _syncErrorMessage = null;
    notifyListeners();
  }

  void clearSyncError() {
    if (_syncStatus == SyncStatus.error) {
      _syncStatus = SyncStatus.localOnly;
      _syncErrorMessage = null;
      notifyListeners();
    }
  }

  // ============================================================================
  // GOOGLE AUTHENTICATION METHODS
  // ============================================================================

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      final email = await _driveService.signIn();
      if (email != null) {
        _isLoggedIn = true;
        _userEmail = email;
        notifyListeners();
        debugPrint('✅ Signed in with Google: $email');
      }
    } catch (e) {
      debugPrint('❌ Google Sign-In failed: $e');
      rethrow;
    }
  }

  /// Sign out from Google
  Future<void> signOut() async {
    try {
      await _driveService.signOut();
      _isLoggedIn = false;
      _userEmail = null;
      _syncStatus = SyncStatus.localOnly;
      _syncErrorMessage = null;
      notifyListeners();
      debugPrint('✅ Signed out from Google');
    } catch (e) {
      debugPrint('❌ Sign out failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // GOOGLE DRIVE BACKUP/RESTORE METHODS
  // ============================================================================

  /// Backup data to Google Drive
  /// Uploads all local data to user's Google Drive appDataFolder
  Future<void> backupToGoogleDrive() async {
    if (!_isLoggedIn) {
      throw Exception('Must be signed in to backup');
    }

    if (_isSyncing) {
      debugPrint('Backup already in progress, skipping...');
      return;
    }

    _isSyncing = true;
    setSyncing();

    try {
      // Prepare data payload
      final data = {
        'spaces': _spaces.map((space) => space.toJson()).toList(),
        'currentSpaceId': _currentSpaceId,
        'themeColor': _themeColor,
        'isDarkMode': _isDarkMode,
        'lastModifiedAt': _lastModifiedAt,
        'version': 1, // Simple versioning
      };

      debugPrint('📤 Backing up to Google Drive...');

      // Upload to Google Drive
      await _driveService.backupToGoogleDrive(data);

      setSynced();
      debugPrint('✅ Backup successful!');
    } catch (e) {
      debugPrint('❌ Backup failed: $e');
      setSyncError(e.toString());
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// Restore data from Google Drive
  /// Overwrites all local data with backup from Google Drive
  Future<void> restoreFromGoogleDrive() async {
    if (!_isLoggedIn) {
      throw Exception('Must be signed in to restore');
    }

    try {
      _isRestoring = true;
      notifyListeners();

      setSyncing();

      debugPrint('📥 Restoring from Google Drive...');

      // Download from Google Drive
      final backupData = await _driveService.restoreFromGoogleDrive();

      if (backupData == null) {
        throw Exception('No backup found on Google Drive');
      }

      // Apply backup data
      await _applyBackupData(backupData);

      setSynced();
      debugPrint('✅ Restore successful!');
    } catch (e) {
      debugPrint('❌ Restore failed: $e');
      setSyncError(e.toString());
      rethrow;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  /// Check if backup exists on Google Drive
  Future<bool> hasBackupOnGoogleDrive() async {
    if (!_isLoggedIn) {
      return false;
    }

    try {
      return await _driveService.hasBackup();
    } catch (e) {
      debugPrint('Error checking for backup: $e');
      return false;
    }
  }

  /// Apply backup data to local state
  Future<void> _applyBackupData(Map<String, dynamic> data) async {
    if (!data.containsKey('spaces')) {
      throw Exception('Invalid backup data');
    }

    // Create backup before clearing
    final backup = List<Space>.from(_spaces);
    final backupCurrentSpaceId = _currentSpaceId;

    try {
      // Clear local database
      _spaces.clear();
      notifyListeners();

      // Clear Hive box
      final box = Hive.box<Space>('spaces');
      await box.clear();

      // Load spaces from backup
      final List<dynamic> spacesData = data['spaces'] as List<dynamic>;
      _spaces = spacesData.map((json) => Space.fromJson(json)).toList();

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

      if (data.containsKey('lastModifiedAt')) {
        _lastModifiedAt = data['lastModifiedAt'] as int;
      }

      // Save to local storage
      await _persistSpaces();
      await _savePreferences();

      notifyListeners();
      debugPrint('✅ Backup data applied successfully!');
    } catch (e) {
      // Restore backup on error
      debugPrint('❌ Error applying backup data: $e');
      _spaces = backup;
      _currentSpaceId = backupCurrentSpaceId;
      notifyListeners();
      rethrow;
    }
  }

  /// Manual sync - same as backup for Google Drive
  Future<void> manualSync() async {
    await backupToGoogleDrive();
  }

  // ============================================================================
  // DATA MUTATION METHODS (Continue from original AppState...)
  // ============================================================================

  List<models.Category> _getDefaultCategories() {
    return [
      models.Category(
        id: 'travel',
        name: 'Travel',
        icon: '✈️',
        items: [],
      ),
      models.Category(
        id: 'experiences',
        name: 'Experiences',
        icon: '🎭',
        items: [],
      ),
      models.Category(
        id: 'skills',
        name: 'Skills',
        icon: '🎯',
        items: [],
      ),
    ];
  }

  // Theme methods
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _savePreferences();
    notifyListeners();
  }

  void setThemeColor(String color) {
    _themeColor = color;
    _savePreferences();
    notifyListeners();
  }

  // Space methods
  void addSpace(Space space) {
    _spaces.add(space);
    _updateLastModified();
    _persistSpaces();
    _savePreferences();
    notifyListeners();
  }

  void updateSpace(Space updatedSpace) {
    final index = _spaces.indexWhere((s) => s.id == updatedSpace.id);
    if (index != -1) {
      _spaces[index] = updatedSpace;
      _updateLastModified();
      _persistSpaces();
      notifyListeners();
    }
  }

  void deleteSpace(String spaceId) {
    _spaces.removeWhere((s) => s.id == spaceId);
    if (_currentSpaceId == spaceId && _spaces.isNotEmpty) {
      _currentSpaceId = _spaces.first.id;
    }
    _updateLastModified();
    _persistSpaces();
    _savePreferences();
    notifyListeners();
  }

  void switchSpace(String spaceId) {
    if (_spaces.any((s) => s.id == spaceId)) {
      _currentSpaceId = spaceId;
      _savePreferences();
      notifyListeners();
    }
  }

  void reorderSpaces(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final space = _spaces.removeAt(oldIndex);
    _spaces.insert(newIndex, space);
    _updateLastModified();
    _persistSpaces();
    notifyListeners();
  }

  // Category methods
  void addCategory(models.Category category) {
    currentSpace.categories.add(category);
    _updateLastModified();
    _persistSpaces();
    notifyListeners();
  }

  void updateCategory(models.Category updatedCategory) {
    final index =
        currentSpace.categories.indexWhere((c) => c.id == updatedCategory.id);
    if (index != -1) {
      currentSpace.categories[index] = updatedCategory;
      _updateLastModified();
      _persistSpaces();
      notifyListeners();
    }
  }

  void deleteCategory(String categoryId) {
    currentSpace.categories.removeWhere((c) => c.id == categoryId);
    _updateLastModified();
    _persistSpaces();
    notifyListeners();
  }

  void reorderCategories(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final category = currentSpace.categories.removeAt(oldIndex);
    currentSpace.categories.insert(newIndex, category);
    _updateLastModified();
    _persistSpaces();
    notifyListeners();
  }

  // Item methods
  void addItem(models.ChecklistItem item) {
    if (item.categoryId == null) {
      currentSpace.uncategorizedItems.add(item);
    } else {
      final category =
          currentSpace.categories.firstWhere((c) => c.id == item.categoryId);
      category.items.add(item);
    }
    _updateLastModified();
    _persistSpaces();
    notifyListeners();
  }

  void toggleItem(String itemId) {
    // Search in categories
    for (var category in currentSpace.categories) {
      final itemIndex = category.items.indexWhere((i) => i.id == itemId);
      if (itemIndex != -1) {
        category.items[itemIndex].isCompleted =
            !category.items[itemIndex].isCompleted;
        _updateLastModified();
        _persistSpaces();
        notifyListeners();
        return;
      }
    }

    // Search in uncategorized items
    final uncatIndex =
        currentSpace.uncategorizedItems.indexWhere((i) => i.id == itemId);
    if (uncatIndex != -1) {
      currentSpace.uncategorizedItems[uncatIndex].isCompleted =
          !currentSpace.uncategorizedItems[uncatIndex].isCompleted;
      _updateLastModified();
      _persistSpaces();
      notifyListeners();
    }
  }

  void deleteItem(String itemId) {
    // Try to delete from categories
    for (var category in currentSpace.categories) {
      category.items.removeWhere((i) => i.id == itemId);
    }

    // Try to delete from uncategorized items
    currentSpace.uncategorizedItems.removeWhere((i) => i.id == itemId);

    _updateLastModified();
    _persistSpaces();
    notifyListeners();
  }

  void updateItem(models.ChecklistItem updatedItem) {
    // Search in categories
    for (var category in currentSpace.categories) {
      final itemIndex =
          category.items.indexWhere((i) => i.id == updatedItem.id);
      if (itemIndex != -1) {
        category.items[itemIndex] = updatedItem;
        _updateLastModified();
        _persistSpaces();
        notifyListeners();
        return;
      }
    }

    // Search in uncategorized items
    final uncatIndex = currentSpace.uncategorizedItems
        .indexWhere((i) => i.id == updatedItem.id);
    if (uncatIndex != -1) {
      currentSpace.uncategorizedItems[uncatIndex] = updatedItem;
      _updateLastModified();
      _persistSpaces();
      notifyListeners();
    }
  }

  void moveItemToCategory(String itemId, String? newCategoryId) {
    models.ChecklistItem? item;

    // Find and remove item from current location
    for (var category in currentSpace.categories) {
      final itemIndex = category.items.indexWhere((i) => i.id == itemId);
      if (itemIndex != -1) {
        item = category.items.removeAt(itemIndex);
        break;
      }
    }

    if (item == null) {
      final uncatIndex =
          currentSpace.uncategorizedItems.indexWhere((i) => i.id == itemId);
      if (uncatIndex != -1) {
        item = currentSpace.uncategorizedItems.removeAt(uncatIndex);
      }
    }

    if (item != null) {
      // Update category ID
      item.categoryId = newCategoryId;

      // Add to new location
      if (newCategoryId == null) {
        currentSpace.uncategorizedItems.add(item);
      } else {
        final category =
            currentSpace.categories.firstWhere((c) => c.id == newCategoryId);
        category.items.add(item);
      }

      _updateLastModified();
      _persistSpaces();
      notifyListeners();
    }
  }

  List<models.ChecklistItem> getItemsForCategory(String categoryId) {
    final category =
        currentSpace.categories.firstWhere((c) => c.id == categoryId);
    return category.items;
  }

  List<models.ChecklistItem> getUncategorizedItems() {
    return currentSpace.uncategorizedItems;
  }

  void reorderItemsInCategory(String categoryId, int oldIndex, int newIndex) {
    final category =
        currentSpace.categories.firstWhere((c) => c.id == categoryId);

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final item = category.items.removeAt(oldIndex);
    category.items.insert(newIndex, item);

    _updateLastModified();
    _persistSpaces();
    notifyListeners();
  }

  void reorderUncategorizedItems(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final item = currentSpace.uncategorizedItems.removeAt(oldIndex);
    currentSpace.uncategorizedItems.insert(newIndex, item);

    _updateLastModified();
    _persistSpaces();
    notifyListeners();
  }
}
