import 'package:uuid/uuid.dart';
import '../models/space_model.dart';
import '../models/category_model.dart';
import '../models/sync_models.dart';
import 'device_manager.dart';

/// Helper utilities for creating sync-compatible data
class SyncHelper {
  static const _uuid = Uuid();

  /// Generate a unique ID with prefix
  static String generateId(String prefix) {
    return '${prefix}_${_uuid.v4()}';
  }

  /// Create a sync-compatible Space
  static Future<Space> createSpace({
    required String name,
    required String icon,
    required String userId,
    int order = 0,
  }) async {
    final deviceId = await DeviceManager.instance.getDeviceId();
    final now = DateTime.now();

    return Space(
      id: generateId('space'),
      name: name,
      icon: icon,
      isHidden: false,
      order: order,
      deleted: false,
      deviceId: deviceId,
      userId: userId,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create a sync-compatible Category
  static Future<Category> createCategory({
    required String name,
    required String icon,
    required String spaceId,
    required String userId,
    int order = 0,
  }) async {
    final deviceId = await DeviceManager.instance.getDeviceId();
    final now = DateTime.now();

    return Category(
      id: generateId('category'),
      name: name,
      icon: icon,
      spaceId: spaceId,
      isHidden: false,
      order: order,
      deleted: false,
      deviceId: deviceId,
      userId: userId,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create a sync-compatible ChecklistItem
  static Future<ChecklistItem> createItem({
    required String text,
    required String spaceId,
    required String userId,
    String? categoryId,
    String? imageUrl,
    String? description,
    int order = 0,
  }) async {
    final deviceId = await DeviceManager.instance.getDeviceId();
    final now = DateTime.now();

    return ChecklistItem(
      id: generateId('item'),
      text: text,
      spaceId: spaceId,
      categoryId: categoryId,
      imageUrl: imageUrl,
      description: description,
      isCompleted: false,
      order: order,
      deleted: false,
      deviceId: deviceId,
      userId: userId,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Update an entity's timestamp
  static Future<void> markAsUpdated(dynamic entity) async {
    final deviceId = await DeviceManager.instance.getDeviceId();
    final now = DateTime.now();

    if (entity is Space) {
      entity.updatedAt = now;
      entity.deviceId = deviceId;
    } else if (entity is Category) {
      entity.updatedAt = now;
      entity.deviceId = deviceId;
    } else if (entity is ChecklistItem) {
      entity.updatedAt = now;
      entity.deviceId = deviceId;
    }
  }

  /// Soft delete an entity
  static Future<void> softDelete(dynamic entity) async {
    final deviceId = await DeviceManager.instance.getDeviceId();
    final now = DateTime.now();

    if (entity is Space) {
      entity.deleted = true;
      entity.updatedAt = now;
      entity.deviceId = deviceId;
    } else if (entity is Category) {
      entity.deleted = true;
      entity.updatedAt = now;
      entity.deviceId = deviceId;
    } else if (entity is ChecklistItem) {
      entity.deleted = true;
      entity.updatedAt = now;
      entity.deviceId = deviceId;
    }
  }

  /// Build SyncChanges from local entities
  static SyncChanges buildSyncChanges({
    List<Space>? spaces,
    List<Category>? categories,
    List<ChecklistItem>? items,
    Map<String, dynamic>? preferences,
  }) {
    return SyncChanges(
      spaces: spaces?.map((s) => s.toJson()).toList() ?? [],
      categories: categories?.map((c) => c.toJson()).toList() ?? [],
      items: items?.map((i) => i.toJson()).toList() ?? [],
      preferences: preferences,
    );
  }

  /// Merge server changes with local data
  /// Uses Last-Write-Wins strategy based on updatedAt timestamp
  static T mergeEntity<T>(T local, T server) {
    DateTime? localTime;
    DateTime? serverTime;

    if (local is Space && server is Space) {
      localTime = local.updatedAt;
      serverTime = server.updatedAt;
    } else if (local is Category && server is Category) {
      localTime = local.updatedAt;
      serverTime = server.updatedAt;
    } else if (local is ChecklistItem && server is ChecklistItem) {
      localTime = local.updatedAt;
      serverTime = server.updatedAt;
    }

    // If both have timestamps, use the newer one
    // Server wins ties (Last-Write-Wins tie-breaker)
    if (localTime != null && serverTime != null) {
      return localTime.isAfter(serverTime) ? local : server;
    }

    // If only one has a timestamp, prefer that one
    if (serverTime != null) return server;
    if (localTime != null) return local;

    // Default to server version
    return server;
  }

  /// Filter out deleted entities
  static List<T> filterDeleted<T>(List<T> entities) {
    return entities.where((entity) {
      if (entity is Space) return !entity.deleted;
      if (entity is Category) return !entity.deleted;
      if (entity is ChecklistItem) return !entity.deleted;
      return true;
    }).toList();
  }

  /// Sort entities by order field
  static List<T> sortByOrder<T>(List<T> entities) {
    final sorted = List<T>.from(entities);
    sorted.sort((a, b) {
      int orderA = 0;
      int orderB = 0;

      if (a is Space && b is Space) {
        orderA = a.order;
        orderB = b.order;
      } else if (a is Category && b is Category) {
        orderA = a.order;
        orderB = b.order;
      } else if (a is ChecklistItem && b is ChecklistItem) {
        orderA = a.order;
        orderB = b.order;
      }

      return orderA.compareTo(orderB);
    });
    return sorted;
  }
}
