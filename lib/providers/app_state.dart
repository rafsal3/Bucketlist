import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

  // 🔒 Mutation Queue - Prevents data loss during sync
  bool _isMutating = false;
  final List<Function> _pendingMutations = [];

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

  int get totalCompleted {
    // Count completed items from categories
    int categoryCompleted =
        categories.fold<int>(0, (sum, cat) => sum + cat.completedCount);
    // Add completed uncategorized items
    int uncategorizedCompleted = currentSpace.uncategorizedItems
        .where((item) => item.isCompleted)
        .length;
    return categoryCompleted + uncategorizedCompleted;
  }

  int get totalItems {
    // Count total items from categories
    int categoryTotal =
        categories.fold<int>(0, (sum, cat) => sum + cat.totalCount);
    // Add total uncategorized items
    int uncategorizedTotal = currentSpace.uncategorizedItems.length;
    return categoryTotal + uncategorizedTotal;
  }

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

        // Clear legacy data
        // await prefs.remove('spaces'); // Optional: keep as backup for now
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

    // ❌ REMOVED: No automatic sync on app start
    // ✅ Guest mode - app works offline by default
    // User must manually click sync button to upload data
  }

  /// Saves ONLY non-space settings (preferences, auth, metadata)
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save current space selection
      await prefs.setString('currentSpaceId', _currentSpaceId);

      // Save lastModifiedAt
      await prefs.setInt('lastModifiedAt', _lastModifiedAt);
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    }
  }

  /// Persists spaces to Hive
  /// Efficiently updates modified spaces and handles deletions
  Future<void> _persistSpaces() async {
    try {
      final box = Hive.box<Space>('spaces');
      final currentIds = <String>{};

      // 1. Update or Add spaces
      for (var space in _spaces) {
        currentIds.add(space.id);
        if (space.isInBox) {
          await space.save();
        } else {
          await box.add(space);
        }
      }

      // 2. Handle Deletions (Remove spaces from Box that are not in Memory)
      final keysToDelete = <dynamic>[];
      for (var key in box.keys) {
        final space = box.get(key);
        if (space != null && !currentIds.contains(space.id)) {
          keysToDelete.add(key);
        }
      }

      if (keysToDelete.isNotEmpty) {
        debugPrint(
            '🗑️ removing ${keysToDelete.length} deleted spaces from persistent storage');
        await box.deleteAll(keysToDelete);
      }
    } catch (e) {
      debugPrint('Error persisting spaces to Hive: $e');
    }
  }

  /// Migrates orphaned uncategorized items from categories to dedicated storage
  /// This fixes the bug where uncategorized items were stored inside category objects
  void _migrateOrphanedItems() {
    bool migrationNeeded = false;

    for (var space in _spaces) {
      for (var category in space.categories) {
        // Find items with null categoryId (orphaned uncategorized items)
        final orphanedItems =
            category.items.where((item) => item.categoryId == null).toList();

        if (orphanedItems.isNotEmpty) {
          migrationNeeded = true;
          debugPrint(
              'Found ${orphanedItems.length} orphaned items in category ${category.name}');

          // Move them to the dedicated uncategorizedItems list
          space.uncategorizedItems.addAll(orphanedItems);

          // Remove them from the category
          category.items.removeWhere((item) => item.categoryId == null);
        }
      }
    }

    if (migrationNeeded) {
      debugPrint(
          'Migration completed: Moved orphaned items to uncategorizedItems');
      _persistSpaces(); // Save to Hive
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
  /// ❌ DOES NOT automatically pull from cloud
  /// ✅ User must manually restore if they want backup
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

    // ❌ REMOVED: No automatic pull
    // ✅ User must manually restore if they want backup
    debugPrint('✅ Login successful - local data preserved');
  }

  /// Backup method (called during registration)
  /// Registers user and uploads all local data as backup
  Future<void> backupOnRegistration(String email, String password) async {
    try {
      // Get all local data from Hive
      final localData = {
        'spaces': _spaces.map((space) => space.toJson()).toList(),
        'currentSpaceId': _currentSpaceId,
        'themeColor': _themeColor,
        'isDarkMode': _isDarkMode,
      };

      // Register with backup data
      final response = await _syncApi.registerWithBackup(
        email: email,
        password: password,
        data: localData,
      );

      // Save token and mark as logged in
      _isLoggedIn = true;
      _userEmail = email;
      _authToken = response.token;

      // Persist authentication state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmail', email);
      await prefs.setString('authToken', response.token);

      // User is now authenticated with backup
      notifyListeners();
      debugPrint('✅ Backup successful - data uploaded to cloud');
    } catch (e) {
      debugPrint('❌ Backup failed: $e');
      rethrow;
    }
  }

  /// OLD METHOD - kept for backward compatibility with cloud_sync_screen
  /// Register user with email and auth token
  /// CRITICAL: Pushes any existing local data to server BEFORE pulling
  /// This prevents data loss when users register after creating offline content
  Future<void> registerWithLocalData(String email, String token) async {
    _isLoggedIn = true;
    _userEmail = email;
    _authToken = token;

    // Persist authentication state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userEmail', email);
    await prefs.setString('authToken', token);

    notifyListeners();

    // Check if there's any local data to push
    final hasLocalData = _spaces.isNotEmpty;

    if (hasLocalData) {
      debugPrint(
          '📤 Registration: Found local data, pushing to server first...');

      try {
        // Push local data with version 0 (first-time sync)
        final data = {
          'spaces': _spaces.map((space) => space.toJson()).toList(),
          'currentSpaceId': _currentSpaceId,
          'themeColor': _themeColor,
          'isDarkMode': _isDarkMode,
        };

        setSyncing();

        final response = await _syncApi.pushToCloud(
          authToken: token,
          version: 0, // CRITICAL: version 0 for first-time push
          lastModifiedAt: _lastModifiedAt,
          data: data,
        );

        // Update version from server
        if (response.containsKey('version')) {
          _dataVersion = response['version'] as int;
        }

        // Mark as synced - we just pushed successfully!
        setSynced();

        debugPrint(
            '✅ Local data pushed successfully! Server version: $_dataVersion');
        debugPrint('✅ Registration complete - local data preserved!');

        // DON'T pull from cloud - we already have the data locally!
        // Pulling would clear local data first, which could cause data loss
        return; // Exit early
      } catch (e) {
        debugPrint('❌ Failed to push local data during registration: $e');
        // Don't throw - we'll try to sync later
        setSyncError('Failed to sync local data: $e');
        return; // Exit early, keep local data
      }
    } else {
      // No local data - pull from server to get any existing data
      debugPrint('📥 Registration: No local data, pulling from server...');
      await _pullFromCloud();
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

  /// Restore method (called when user wants to restore backup)
  /// ⚠️ OVERWRITES all local data with server backup
  Future<void> restoreFromBackup() async {
    if (!_isLoggedIn || _authToken == null) {
      throw Exception('User must be authenticated to restore');
    }

    try {
      setSyncing();

      // Get backup data from server
      final backupData = await _syncApi.restore(_authToken!);

      if (!backupData.hasBackup) {
        throw Exception('No backup found on server');
      }

      debugPrint('📥 Restoring backup from server...');

      // OVERWRITE local Hive with server data
      await _applySyncData(backupData.data, backupData.version);

      debugPrint('✅ Backup restored successfully!');
    } catch (e) {
      debugPrint('❌ Restore failed: $e');
      setSyncError(e.toString());
      rethrow;
    }
  }

  // ============================================================================
  // CLOUD SYNC METHODS
  // ============================================================================

  /// ❌ REMOVED: No automatic debounced sync
  /// ✅ Sync only happens when user manually clicks sync button
  void _markSyncPending() {
    // Cancel existing timer if any
    _syncDebounceTimer?.cancel();

    // ❌ REMOVED: No automatic sync
    // User must manually click sync button
    debugPrint('💾 Data saved locally - click cloud icon to sync');
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
    } on SyncConflictException catch (e) {
      // Handle Conflict: Overwrite local data with server data
      debugPrint(
          '⚠️ Conflict detected (409)! Server version: ${e.serverVersion}');
      debugPrint('📥 Overwriting local data with server data...');

      await _applySyncData(e.serverData, e.serverVersion);
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

      // 🔄 Process any pending mutations that occurred during sync
      await _processPendingMutations();
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

  /// ❌ REMOVED: No automatic retry
  /// ✅ User must manually retry sync if it fails
  void _scheduleRetry() {
    // Cancel any existing retry timer
    _syncDebounceTimer?.cancel();

    // ❌ REMOVED: No automatic retry
    // User must manually click sync button to retry
    debugPrint('❌ Sync failed - please try again manually');
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

      // Apply the data
      await _applySyncData(data, version);
    } catch (e) {
      // Handle error
      debugPrint('❌ Pull failed: $e');
      setSyncError(e.toString());
    } finally {
      // 🔄 Process any pending mutations that occurred during pull
      await _processPendingMutations();
    }
  }

  /// Apply data from server to local state (Overwrite)
  Future<void> _applySyncData(Map<String, dynamic> data, int? version) async {
    // ✅ STEP 1: Validate server data first
    if (!data.containsKey('spaces')) {
      debugPrint('⚠️ Server data missing spaces, keeping local data');
      setSyncError('Invalid server data');
      return;
    }

    // Create backup before clearing
    final backup = List<Space>.from(_spaces);

    try {
      // ⚠️ STEP 2: Clear local database
      _spaces.clear();
      debugPrint('🗑️ Local DB cleared');

      // ⚠️ STEP 3: Replace with remote data (NEVER merge)
      final List<dynamic> spacesData = data['spaces'] as List<dynamic>;
      _spaces = spacesData.map((json) => Space.fromJson(json)).toList();
      debugPrint('📥 Loaded ${_spaces.length} spaces from cloud');

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

      // Save to local storage (Hive + Prefs)
      await _persistSpaces();
      await _savePreferences();

      // Mark as synced
      setSynced();
      debugPrint(
          '✅ Data applied successfully! Version: $_dataVersion, Spaces: ${_spaces.length}');

      // Notify UI
      notifyListeners();
    } catch (e) {
      // Restore backup on error
      debugPrint('❌ Error applying sync data: $e');
      debugPrint('🔄 Restoring backup...');
      _spaces = backup;
      setSyncError('Failed to apply server data: $e');
      notifyListeners();
    }
  }

  // ============================================================================
  // UNIFIED MUTATION WRAPPER
  // ============================================================================

  /// Executes a mutation action with proper sync coordination
  /// If a sync is in progress, queues the mutation for later execution
  Future<void> mutateData(Function action) async {
    // If currently syncing, queue the mutation
    if (_isSyncing) {
      debugPrint(
          '⚠️ Sync in progress, queuing mutation (queue size: ${_pendingMutations.length + 1})');
      _pendingMutations.add(action);
      return;
    }

    // If another mutation is in progress, queue this one
    if (_isMutating) {
      debugPrint(
          '⚠️ Mutation in progress, queuing (queue size: ${_pendingMutations.length + 1})');
      _pendingMutations.add(action);
      return;
    }

    await _executeMutation(action);
  }

  /// Internal method to execute a single mutation
  Future<void> _executeMutation(Function action) async {
    _isMutating = true;

    try {
      // 1. Execute the mutation action
      action();

      // 2. Update timestamp and mark as needing sync
      _updateLastModified();

      // 3. Persist to Hive (Fast & Safe)
      await _persistSpaces();

      // 4. Save metadata (current space, etc)
      await _savePreferences();

      // 5. Notify UI listeners
      notifyListeners();

      // 6. Trigger debounced cloud sync (if logged in)
      _markSyncPending();
    } finally {
      _isMutating = false;
    }
  }

  /// Process all pending mutations that were queued during sync
  Future<void> _processPendingMutations() async {
    if (_pendingMutations.isEmpty) {
      return;
    }

    debugPrint(
        '🔄 Processing ${_pendingMutations.length} pending mutations...');

    // Create a copy of the queue and clear it
    final mutations = List<Function>.from(_pendingMutations);
    _pendingMutations.clear();

    // Execute each mutation sequentially
    for (final mutation in mutations) {
      await _executeMutation(mutation);
    }

    debugPrint('✅ All pending mutations processed!');
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
      _savePreferences();
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

  // Get all items across all visible categories AND uncategorized items
  List<models.ChecklistItem> getAllItems() {
    List<models.ChecklistItem> allItems = [];

    // Add uncategorized items first
    allItems.addAll(currentSpace.uncategorizedItems);

    // Add items from visible categories
    for (var category in categories) {
      if (!category.isHidden) {
        allItems.addAll(
            category.items.where((item) => item.categoryId == category.id));
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
        // Add to specific category
        final category = categories.firstWhere((cat) => cat.id == categoryId);
        category.items.insert(0, item);
      } else {
        // Add to dedicated uncategorized items list
        currentSpace.uncategorizedItems.insert(0, item);
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
      // Check uncategorized items first
      final uncatIndex = currentSpace.uncategorizedItems
          .indexWhere((item) => item.id == itemId);
      if (uncatIndex != -1) {
        currentSpace.uncategorizedItems[uncatIndex].isCompleted =
            !currentSpace.uncategorizedItems[uncatIndex].isCompleted;
        return;
      }

      // Check categorized items
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
      // Remove from uncategorized items
      currentSpace.uncategorizedItems.removeWhere((item) => item.id == itemId);

      // Remove from categorized items
      for (var category in categories) {
        category.items.removeWhere((item) => item.id == itemId);
      }
    });
  }

  void updateItem(models.ChecklistItem updatedItem) {
    mutateData(() {
      // Check if category changed - if so, move the item
      models.ChecklistItem? existingItem;
      String? oldCategoryId;

      // Find existing item in uncategorized items
      final uncatIndex = currentSpace.uncategorizedItems
          .indexWhere((item) => item.id == updatedItem.id);
      if (uncatIndex != -1) {
        existingItem = currentSpace.uncategorizedItems[uncatIndex];
        oldCategoryId = null;
      }

      // If not found, find in categories
      if (existingItem == null) {
        for (var category in categories) {
          final itemIndex =
              category.items.indexWhere((item) => item.id == updatedItem.id);
          if (itemIndex != -1) {
            existingItem = category.items[itemIndex];
            oldCategoryId = category.id;
            break;
          }
        }
      }

      if (existingItem == null) return; // Item not found

      // Check if category changed
      if (oldCategoryId != updatedItem.categoryId) {
        // Remove from old location
        if (oldCategoryId == null) {
          currentSpace.uncategorizedItems
              .removeWhere((item) => item.id == updatedItem.id);
        } else {
          final oldCategory =
              categories.firstWhere((cat) => cat.id == oldCategoryId);
          oldCategory.items.removeWhere((item) => item.id == updatedItem.id);
        }

        // Add to new location
        if (updatedItem.categoryId == null) {
          currentSpace.uncategorizedItems.insert(0, updatedItem);
        } else {
          final newCategory =
              categories.firstWhere((cat) => cat.id == updatedItem.categoryId);
          newCategory.items.insert(0, updatedItem);
        }
      } else {
        // Category didn't change, just update in place
        if (oldCategoryId == null) {
          final index = currentSpace.uncategorizedItems
              .indexWhere((item) => item.id == updatedItem.id);
          if (index != -1) {
            currentSpace.uncategorizedItems[index] = updatedItem;
          }
        } else {
          final category =
              categories.firstWhere((cat) => cat.id == oldCategoryId);
          final index =
              category.items.indexWhere((item) => item.id == updatedItem.id);
          if (index != -1) {
            category.items[index] = updatedItem;
          }
        }
      }
    });
  }

  void moveItemToCategory(String itemId, String? newCategoryId) {
    mutateData(() {
      models.ChecklistItem? itemToMove;

      // Find and remove from uncategorized items
      final uncatIndex = currentSpace.uncategorizedItems
          .indexWhere((item) => item.id == itemId);
      if (uncatIndex != -1) {
        itemToMove = currentSpace.uncategorizedItems.removeAt(uncatIndex);
      }

      // If not found, find and remove from categories
      if (itemToMove == null) {
        for (var category in categories) {
          final itemIndex =
              category.items.indexWhere((item) => item.id == itemId);
          if (itemIndex != -1) {
            itemToMove = category.items.removeAt(itemIndex);
            break;
          }
        }
      }

      if (itemToMove != null) {
        itemToMove.categoryId = newCategoryId;

        if (newCategoryId != null) {
          // Move to specific category
          final newCategory =
              categories.firstWhere((cat) => cat.id == newCategoryId);
          newCategory.items.insert(0, itemToMove);
        } else {
          // Move to uncategorized
          currentSpace.uncategorizedItems.insert(0, itemToMove);
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
    return currentSpace.uncategorizedItems;
  }
}
