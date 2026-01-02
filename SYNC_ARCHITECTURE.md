# Offline-First Sync Architecture

This Flutter app has been updated to work with the refactored backend's offline-first sync architecture.

## Overview

The backend has moved from traditional CRUD operations to a **sync-based architecture** that supports:
- Offline-first data management
- Multi-device synchronization
- Conflict resolution using Last-Write-Wins (LWW)
- Soft deletes for data recovery

## Key Changes

### 1. New Data Model Fields

All entities (Spaces, Categories, Items) now include:
- `id`: Unique identifier (client-generated)
- `deleted`: Boolean flag for soft deletes
- `deviceId`: Device that last modified the entity
- `userId`: Owner of the entity
- `createdAt`: Creation timestamp
- `updatedAt`: Last modification timestamp
- `order`: Position in lists

### 2. New API Endpoints

#### Sync Endpoints (Primary)
- `POST /api/v1/sync/push` - Push local changes to server
- `GET /api/v1/sync/pull` - Pull server changes
- `POST /api/v1/sync/backup` - Create full backup
- `POST /api/v1/sync/restore` - Restore from backup

#### Old CRUD Endpoints (Deprecated)
The old endpoints still work but are marked as deprecated:
- `/api/v1/spaces/*`
- `/api/v1/categories/*`
- `/api/v1/items/*`

### 3. New Services

#### `SyncService`
Handles push/pull operations with the backend:
```dart
final syncService = SyncService();
syncService.setToken(authToken);

// Pull changes from server
final pullResponse = await syncService.pullChanges();

// Push local changes
final changes = SyncHelper.buildSyncChanges(
  spaces: modifiedSpaces,
  categories: modifiedCategories,
  items: modifiedItems,
);
await syncService.pushChanges(changes);

// Full sync
await syncService.performSync(localChanges: changes);
```

#### `DeviceManager`
Manages device identification:
```dart
// Get device ID (auto-generated on first use)
final deviceId = await DeviceManager.instance.getDeviceId();

// Get last sync timestamp
final lastSync = await DeviceManager.instance.getLastSyncAt();

// Update last sync
await DeviceManager.instance.updateLastSyncAt(DateTime.now());
```

#### `SyncHelper`
Utilities for creating and managing sync-compatible data:
```dart
// Create new space
final space = await SyncHelper.createSpace(
  name: 'My Space',
  icon: '📝',
  userId: currentUserId,
);

// Create new category
final category = await SyncHelper.createCategory(
  name: 'My Category',
  icon: '📌',
  spaceId: space.id,
  userId: currentUserId,
);

// Create new item
final item = await SyncHelper.createItem(
  text: 'My Item',
  spaceId: space.id,
  userId: currentUserId,
  categoryId: category.id,
);

// Mark as updated
await SyncHelper.markAsUpdated(space);

// Soft delete
await SyncHelper.softDelete(item);

// Filter deleted entities
final activeSpaces = SyncHelper.filterDeleted(allSpaces);

// Sort by order
final sortedSpaces = SyncHelper.sortByOrder(activeSpaces);
```

## Backend Configuration

The app is currently configured to use:
```dart
baseUrl: 'http://localhost:5000/api/v1'
```

To change this, update the `baseUrl` in:
- `lib/services/api_service.dart`
- `lib/services/sync_service.dart`

## Sync Flow

### Initial Sync (First Time)
1. User logs in
2. App calls `syncService.pullChanges(fullSync: true)`
3. Server returns all user data
4. App stores data locally

### Incremental Sync
1. App makes local changes
2. Changes are tracked in memory
3. When ready to sync:
   - Call `syncService.pushChanges(localChanges)`
   - Call `syncService.pullChanges()` to get server updates
4. Merge server changes with local data using `SyncHelper.mergeEntity()`

### Conflict Resolution
The system uses **Last-Write-Wins (LWW)** based on `updatedAt` timestamps:
- If server version is newer → use server version
- If local version is newer → use local version
- Server always wins ties

## Data Models

### Space
```dart
Space(
  id: 'space_uuid',
  name: 'Travel Goals',
  icon: '✈️',
  isHidden: false,
  order: 0,
  deleted: false,
  deviceId: 'device_uuid',
  userId: 'user_id',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
)
```

### Category
```dart
Category(
  id: 'category_uuid',
  name: 'Movies',
  icon: '🎬',
  spaceId: 'space_uuid',
  isHidden: false,
  order: 0,
  deleted: false,
  deviceId: 'device_uuid',
  userId: 'user_id',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
)
```

### ChecklistItem
```dart
ChecklistItem(
  id: 'item_uuid',
  text: 'Watch Inception',
  spaceId: 'space_uuid',
  categoryId: 'category_uuid',
  isCompleted: false,
  imageUrl: 'https://...',
  description: 'A mind-bending thriller',
  order: 0,
  deleted: false,
  deviceId: 'device_uuid',
  userId: 'user_id',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
)
```

## Migration Notes

### From Old CRUD to New Sync

If you have existing code using the old API service:

**Old Way:**
```dart
final space = await apiService.createSpace(
  name: 'My Space',
  icon: '📝',
);
```

**New Way:**
```dart
// Create locally
final space = await SyncHelper.createSpace(
  name: 'My Space',
  icon: '📝',
  userId: currentUserId,
);

// Push to server
final changes = SyncHelper.buildSyncChanges(spaces: [space]);
await syncService.pushChanges(changes);
```

### Handling Deletes

**Old Way:**
```dart
await apiService.deleteSpace(spaceId);
```

**New Way:**
```dart
// Soft delete locally
await SyncHelper.softDelete(space);

// Push to server
final changes = SyncHelper.buildSyncChanges(spaces: [space]);
await syncService.pushChanges(changes);
```

## Best Practices

1. **Always use SyncHelper** to create new entities
2. **Call markAsUpdated()** when modifying entities
3. **Use soft deletes** instead of hard deletes
4. **Sync regularly** to avoid conflicts
5. **Handle conflicts gracefully** by showing user notifications
6. **Filter deleted entities** when displaying data
7. **Sort by order field** for consistent ordering

## Testing

Use the provided Postman collection (`postman-sync-collection.json`) to test:
1. Authentication
2. Push/Pull sync
3. Conflict scenarios
4. Backup/Restore

## Troubleshooting

### Sync Conflicts
If you encounter conflicts, check:
- Device time is synchronized
- `updatedAt` timestamps are being set correctly
- Network connectivity is stable

### Missing Data
If data is missing after sync:
- Check if entities are marked as `deleted: true`
- Verify `deviceId` matches
- Check server logs for errors

### Performance Issues
For large datasets:
- Use incremental sync instead of full sync
- Implement pagination for items
- Consider local caching with SQLite

## Dependencies

New packages added:
- `uuid: ^4.5.1` - For generating unique IDs

Existing packages used:
- `shared_preferences: ^2.2.2` - For storing device ID and sync metadata
- `http: ^1.2.0` - For API communication

## Future Enhancements

Potential improvements:
- Local SQLite database for offline storage
- Background sync with WorkManager
- Optimistic UI updates
- Conflict resolution UI
- Sync status indicators
- Delta sync for large datasets
