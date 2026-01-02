import 'package:flutter/foundation.dart';
import '../models/category_model.dart' as models;
import '../models/space_model.dart';
import '../models/sync_models.dart';
import '../services/sync_service.dart';
import '../services/sync_helper.dart';
import '../services/device_manager.dart';

/// Example provider showing how to integrate the new sync service
/// This is a reference implementation - adapt to your needs
class SyncAppState extends ChangeNotifier {
  final SyncService _syncService = SyncService();

  List<Space> _spaces = [];
  String? _currentSpaceId;
  String? _userId;
  bool _isSyncing = false;
  DateTime? _lastSyncAt;
  List<ConflictInfo> _conflicts = [];

  // Getters
  List<Space> get spaces => SyncHelper.filterDeleted(_spaces);
  List<Space> get sortedSpaces => SyncHelper.sortByOrder(spaces);
  Space? get currentSpace => spaces.firstWhere((s) => s.id == _currentSpaceId,
      orElse: () => spaces.first);
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncAt => _lastSyncAt;
  List<ConflictInfo> get conflicts => _conflicts;

  /// Initialize sync service with auth token
  void setAuthToken(String token, String userId) {
    _syncService.setToken(token);
    _userId = userId;
    notifyListeners();
  }

  /// Perform initial sync after login
  Future<void> initialSync() async {
    try {
      _isSyncing = true;
      notifyListeners();

      // Pull all data from server
      final pullResponse = await _syncService.pullChanges(fullSync: true);

      // Parse and store spaces
      _spaces = (pullResponse.changes.spaces)
          .map((json) => Space.fromJson(json))
          .toList();

      _lastSyncAt = pullResponse.serverTime;
      _conflicts = pullResponse.conflicts;

      // Set first space as current if none selected
      if (_currentSpaceId == null && _spaces.isNotEmpty) {
        _currentSpaceId = _spaces.first.id;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Initial sync error: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Sync local changes with server
  Future<void> sync({
    List<Space>? modifiedSpaces,
    List<models.Category>? modifiedCategories,
    List<models.ChecklistItem>? modifiedItems,
  }) async {
    try {
      _isSyncing = true;
      notifyListeners();

      // Build changes to push
      SyncChanges? localChanges;
      if (modifiedSpaces != null ||
          modifiedCategories != null ||
          modifiedItems != null) {
        localChanges = SyncHelper.buildSyncChanges(
          spaces: modifiedSpaces,
          categories: modifiedCategories,
          items: modifiedItems,
        );
      }

      // Perform sync
      final result = await _syncService.performSync(
        localChanges: localChanges,
      );

      if (result['success']) {
        // Merge pulled changes
        final pulledChanges = SyncChanges.fromJson(result['pulled']);
        _mergeServerChanges(pulledChanges);

        _lastSyncAt = DateTime.parse(result['serverTime']);
        _conflicts = result['conflicts'] ?? [];
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Sync error: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Add a new space
  Future<void> addSpace(String name, String icon) async {
    if (_userId == null) throw Exception('User not logged in');

    try {
      // Create space locally
      final space = await SyncHelper.createSpace(
        name: name,
        icon: icon,
        userId: _userId!,
        order: _spaces.length,
      );

      // Add to local list
      _spaces.add(space);
      notifyListeners();

      // Sync with server
      await sync(modifiedSpaces: [space]);
    } catch (e) {
      debugPrint('Add space error: $e');
      rethrow;
    }
  }

  /// Edit a space
  Future<void> editSpace(String spaceId, String name, String icon) async {
    try {
      final space = _spaces.firstWhere((s) => s.id == spaceId);

      space.name = name;
      space.icon = icon;
      await SyncHelper.markAsUpdated(space);

      notifyListeners();

      // Sync with server
      await sync(modifiedSpaces: [space]);
    } catch (e) {
      debugPrint('Edit space error: $e');
      rethrow;
    }
  }

  /// Delete a space (soft delete)
  Future<void> deleteSpace(String spaceId) async {
    try {
      final space = _spaces.firstWhere((s) => s.id == spaceId);

      // Soft delete
      await SyncHelper.softDelete(space);

      // Also soft delete all categories and items in this space
      for (var category in space.categories) {
        await SyncHelper.softDelete(category);
        for (var item in category.items) {
          await SyncHelper.softDelete(item);
        }
      }

      notifyListeners();

      // Sync with server
      await sync(modifiedSpaces: [space]);
    } catch (e) {
      debugPrint('Delete space error: $e');
      rethrow;
    }
  }

  /// Add a category to current space
  Future<void> addCategory(String name, String icon) async {
    if (_userId == null || _currentSpaceId == null) {
      throw Exception('User not logged in or no space selected');
    }

    try {
      final space = _spaces.firstWhere((s) => s.id == _currentSpaceId);

      // Create category locally
      final category = await SyncHelper.createCategory(
        name: name,
        icon: icon,
        spaceId: space.id,
        userId: _userId!,
        order: space.categories.length,
      );

      // Add to space
      space.categories.add(category);
      await SyncHelper.markAsUpdated(space);

      notifyListeners();

      // Sync with server
      await sync(
        modifiedSpaces: [space],
        modifiedCategories: [category],
      );
    } catch (e) {
      debugPrint('Add category error: $e');
      rethrow;
    }
  }

  /// Add an item to a category
  Future<void> addItem(
    String text, {
    String? categoryId,
    String? imageUrl,
    String? description,
  }) async {
    if (_userId == null || _currentSpaceId == null) {
      throw Exception('User not logged in or no space selected');
    }

    try {
      final space = _spaces.firstWhere((s) => s.id == _currentSpaceId);

      // Find category if specified
      models.Category? category;
      if (categoryId != null) {
        category = space.categories.firstWhere((c) => c.id == categoryId);
      }

      // Create item locally
      final item = await SyncHelper.createItem(
        text: text,
        spaceId: space.id,
        userId: _userId!,
        categoryId: categoryId,
        imageUrl: imageUrl,
        description: description,
        order: category?.items.length ?? 0,
      );

      // Add to category or space
      if (category != null) {
        category.items.add(item);
        await SyncHelper.markAsUpdated(category);
      }
      await SyncHelper.markAsUpdated(space);

      notifyListeners();

      // Sync with server
      await sync(
        modifiedSpaces: [space],
        modifiedCategories: category != null ? [category] : null,
        modifiedItems: [item],
      );
    } catch (e) {
      debugPrint('Add item error: $e');
      rethrow;
    }
  }

  /// Toggle item completion
  Future<void> toggleItem(String itemId) async {
    try {
      // Find the item
      models.ChecklistItem? item;
      Space? itemSpace;
      models.Category? itemCategory;

      for (var space in _spaces) {
        for (var category in space.categories) {
          final found = category.items.firstWhere(
            (i) => i.id == itemId,
            orElse: () => models.ChecklistItem(id: '', text: ''),
          );
          if (found.id == itemId) {
            item = found;
            itemSpace = space;
            itemCategory = category;
            break;
          }
        }
        if (item != null) break;
      }

      if (item == null) throw Exception('Item not found');

      // Toggle completion
      item.isCompleted = !item.isCompleted;
      await SyncHelper.markAsUpdated(item);
      if (itemCategory != null) {
        await SyncHelper.markAsUpdated(itemCategory);
      }
      if (itemSpace != null) {
        await SyncHelper.markAsUpdated(itemSpace);
      }

      notifyListeners();

      // Sync with server
      await sync(modifiedItems: [item]);
    } catch (e) {
      debugPrint('Toggle item error: $e');
      rethrow;
    }
  }

  /// Merge server changes with local data
  void _mergeServerChanges(SyncChanges serverChanges) {
    // Merge spaces
    for (var serverSpaceJson in serverChanges.spaces) {
      final serverSpace = Space.fromJson(serverSpaceJson);
      final localIndex = _spaces.indexWhere((s) => s.id == serverSpace.id);

      if (localIndex >= 0) {
        // Merge existing space
        _spaces[localIndex] = SyncHelper.mergeEntity(
          _spaces[localIndex],
          serverSpace,
        );
      } else {
        // Add new space
        _spaces.add(serverSpace);
      }
    }

    // Merge categories
    for (var serverCategoryJson in serverChanges.categories) {
      final serverCategory = models.Category.fromJson(serverCategoryJson);

      // Find parent space
      final space = _spaces.firstWhere(
        (s) => s.id == serverCategory.spaceId,
        orElse: () => Space(id: '', name: ''),
      );

      if (space.id.isNotEmpty) {
        final localIndex = space.categories.indexWhere(
          (c) => c.id == serverCategory.id,
        );

        if (localIndex >= 0) {
          space.categories[localIndex] = SyncHelper.mergeEntity(
            space.categories[localIndex],
            serverCategory,
          );
        } else {
          space.categories.add(serverCategory);
        }
      }
    }

    // Merge items
    for (var serverItemJson in serverChanges.items) {
      final serverItem = models.ChecklistItem.fromJson(serverItemJson);

      // Find parent category
      models.Category? category;
      for (var space in _spaces) {
        category = space.categories.firstWhere(
          (c) => c.id == serverItem.categoryId,
          orElse: () => models.Category(id: '', name: '', icon: ''),
        );
        if (category.id.isNotEmpty) break;
      }

      if (category != null && category.id.isNotEmpty) {
        final localIndex = category.items.indexWhere(
          (i) => i.id == serverItem.id,
        );

        if (localIndex >= 0) {
          category.items[localIndex] = SyncHelper.mergeEntity(
            category.items[localIndex],
            serverItem,
          );
        } else {
          category.items.add(serverItem);
        }
      }
    }
  }

  /// Create a backup
  Future<Map<String, dynamic>> createBackup() async {
    try {
      return await _syncService.createBackup();
    } catch (e) {
      debugPrint('Create backup error: $e');
      rethrow;
    }
  }

  /// Restore from backup
  Future<void> restoreBackup(Map<String, dynamic> backupData) async {
    try {
      await _syncService.restoreBackup(backupData);

      // Reload data
      await initialSync();
    } catch (e) {
      debugPrint('Restore backup error: $e');
      rethrow;
    }
  }

  /// Clear all data (logout)
  Future<void> clear() async {
    _spaces = [];
    _currentSpaceId = null;
    _userId = null;
    _lastSyncAt = null;
    _conflicts = [];

    await DeviceManager.instance.clearSyncData();

    notifyListeners();
  }
}
