# Migration Summary: Offline-First Sync Architecture

## Overview
The Flutter app has been updated to support the refactored backend's offline-first sync architecture. The backend now uses sync-based operations instead of traditional CRUD endpoints.

## What Changed

### 1. Backend Configuration
- **Base URL**: Updated from `https://backendbucket.onrender.com/api/v1` to `http://localhost:5000/api/v1`
- **Location**: `lib/services/api_service.dart` line 8

### 2. New Dependencies
Added to `pubspec.yaml`:
- `uuid: ^4.5.1` - For generating unique client-side IDs

### 3. Updated Data Models

#### Space Model (`lib/models/space_model.dart`)
**New fields:**
- `order: int` - Position in list
- `deleted: bool` - Soft delete flag
- `deviceId: String?` - Last modifying device
- `userId: String?` - Owner
- `createdAt: DateTime?` - Creation timestamp
- `updatedAt: DateTime?` - Last modification timestamp

#### Category Model (`lib/models/category_model.dart`)
**New fields:**
- `spaceId: String?` - Parent space reference
- `order: int` - Position in list
- `deleted: bool` - Soft delete flag
- `deviceId: String?` - Last modifying device
- `userId: String?` - Owner
- `createdAt: DateTime?` - Creation timestamp
- `updatedAt: DateTime?` - Last modification timestamp

#### ChecklistItem Model (`lib/models/category_model.dart`)
**New fields:**
- `spaceId: String?` - Parent space reference
- `order: int` - Position in list
- `deleted: bool` - Soft delete flag
- `deviceId: String?` - Last modifying device
- `userId: String?` - Owner
- `createdAt: DateTime?` - Creation timestamp
- `updatedAt: DateTime?` - Last modification timestamp

### 4. New Models

#### Sync Models (`lib/models/sync_models.dart`)
New models for sync operations:
- `SyncMetadata` - Device and sync timestamp info
- `SyncChanges` - Container for spaces, categories, items changes
- `PushRequest` - Request format for pushing changes
- `PullResponse` - Response format for pulling changes
- `ConflictInfo` - Information about sync conflicts

### 5. New Services

#### SyncService (`lib/services/sync_service.dart`)
Main service for sync operations:
- `pushChanges(SyncChanges)` - Push local changes to server
- `pullChanges({fullSync})` - Pull server changes
- `createBackup()` - Create full data backup
- `restoreBackup(backupData)` - Restore from backup
- `performSync({localChanges})` - Full sync operation

#### DeviceManager (`lib/services/device_manager.dart`)
Manages device identification:
- `getDeviceId()` - Get or create device ID
- `getLastSyncAt()` - Get last sync timestamp
- `updateLastSyncAt(timestamp)` - Update sync timestamp
- `clearSyncData()` - Clear sync metadata
- `resetDeviceId()` - Reset device (creates conflicts!)

#### SyncHelper (`lib/services/sync_helper.dart`)
Utility functions for sync operations:
- `generateId(prefix)` - Generate unique IDs
- `createSpace(...)` - Create sync-compatible space
- `createCategory(...)` - Create sync-compatible category
- `createItem(...)` - Create sync-compatible item
- `markAsUpdated(entity)` - Update timestamps
- `softDelete(entity)` - Soft delete entity
- `buildSyncChanges(...)` - Build sync payload
- `mergeEntity(local, server)` - Merge with LWW strategy
- `filterDeleted(entities)` - Remove deleted items
- `sortByOrder(entities)` - Sort by order field

### 6. Documentation

#### SYNC_ARCHITECTURE.md
Comprehensive documentation covering:
- Architecture overview
- Data model changes
- API endpoints
- Service usage
- Sync flow
- Conflict resolution
- Migration guide
- Best practices
- Troubleshooting

#### QUICK_START_SYNC.md
Step-by-step guide with:
- Basic setup
- Initial data load
- CRUD operations
- Periodic sync
- Conflict handling
- Common patterns
- Testing guide
- Troubleshooting

### 7. Example Implementation

#### SyncAppState (`lib/providers/sync_app_state_example.dart`)
Complete example provider showing:
- Service initialization
- Initial sync
- CRUD operations with sync
- Conflict handling
- Server change merging
- Backup/restore
- State management

## New API Endpoints

### Primary Endpoints (Use These)
```
POST   /api/v1/sync/push      - Push local changes
GET    /api/v1/sync/pull      - Pull server changes
POST   /api/v1/sync/backup    - Create backup
POST   /api/v1/sync/restore   - Restore backup
```

### Authentication (Unchanged)
```
POST   /api/v1/auth/register  - Register user
POST   /api/v1/auth/login     - Login user
GET    /api/v1/auth/profile   - Get profile
```

### Old CRUD Endpoints (Deprecated)
```
GET    /api/v1/spaces         - Still works but deprecated
POST   /api/v1/spaces         - Still works but deprecated
... (all other CRUD endpoints)
```

## Migration Checklist

### Immediate Changes Required
- [ ] Update existing code to use `SyncHelper` for creating entities
- [ ] Replace direct API calls with sync operations
- [ ] Add `userId` to all create operations
- [ ] Handle `deleted` flag when displaying data
- [ ] Sort entities by `order` field

### Recommended Changes
- [ ] Implement periodic sync (every 5 minutes)
- [ ] Add conflict notification UI
- [ ] Implement optimistic UI updates
- [ ] Add offline queue for failed syncs
- [ ] Show sync status indicator

### Optional Enhancements
- [ ] Add local SQLite database for offline storage
- [ ] Implement background sync
- [ ] Add sync conflict resolution UI
- [ ] Implement delta sync for large datasets
- [ ] Add data compression for sync payloads

## Breaking Changes

### 1. Entity Creation
**Before:**
```dart
final response = await apiService.createSpace(
  name: 'My Space',
  icon: '📝',
);
final space = Space.fromJson(response);
```

**After:**
```dart
final space = await SyncHelper.createSpace(
  name: 'My Space',
  icon: '📝',
  userId: currentUserId,
);
final changes = SyncHelper.buildSyncChanges(spaces: [space]);
await syncService.pushChanges(changes);
```

### 2. Entity Updates
**Before:**
```dart
await apiService.updateSpace(
  spaceId: space.id,
  name: newName,
  icon: newIcon,
);
```

**After:**
```dart
space.name = newName;
space.icon = newIcon;
await SyncHelper.markAsUpdated(space);
final changes = SyncHelper.buildSyncChanges(spaces: [space]);
await syncService.pushChanges(changes);
```

### 3. Entity Deletion
**Before:**
```dart
await apiService.deleteSpace(spaceId);
```

**After:**
```dart
await SyncHelper.softDelete(space);
final changes = SyncHelper.buildSyncChanges(spaces: [space]);
await syncService.pushChanges(changes);
```

### 4. Data Fetching
**Before:**
```dart
final spaces = await apiService.getSpaces();
```

**After:**
```dart
final pullResponse = await syncService.pullChanges();
final spaces = pullResponse.changes.spaces
    .map((json) => Space.fromJson(json))
    .toList();
final activeSpaces = SyncHelper.filterDeleted(spaces);
```

## Testing the Changes

### 1. Test Sync Service
```dart
// Initialize
final syncService = SyncService();
syncService.setToken(authToken);

// Test pull
final pullResponse = await syncService.pullChanges(fullSync: true);
print('Pulled ${pullResponse.changes.spaces.length} spaces');

// Test push
final space = await SyncHelper.createSpace(
  name: 'Test',
  icon: '📝',
  userId: userId,
);
final changes = SyncHelper.buildSyncChanges(spaces: [space]);
await syncService.pushChanges(changes);
```

### 2. Test Device Manager
```dart
final deviceId = await DeviceManager.instance.getDeviceId();
print('Device ID: $deviceId');

final lastSync = await DeviceManager.instance.getLastSyncAt();
print('Last sync: $lastSync');
```

### 3. Test with Postman
1. Import `postman-sync-collection.json`
2. Run authentication requests
3. Test sync endpoints
4. Verify data in responses

## Files Modified

### Updated Files
1. `lib/services/api_service.dart` - Changed base URL
2. `lib/models/space_model.dart` - Added sync fields
3. `lib/models/category_model.dart` - Added sync fields
4. `pubspec.yaml` - Added uuid dependency

### New Files
1. `lib/models/sync_models.dart` - Sync data models
2. `lib/services/sync_service.dart` - Sync operations
3. `lib/services/device_manager.dart` - Device ID management
4. `lib/services/sync_helper.dart` - Sync utilities
5. `lib/providers/sync_app_state_example.dart` - Example provider
6. `SYNC_ARCHITECTURE.md` - Full documentation
7. `QUICK_START_SYNC.md` - Quick start guide
8. `MIGRATION_SUMMARY.md` - This file

## Next Steps

1. **Review Documentation**
   - Read `SYNC_ARCHITECTURE.md` for full details
   - Follow `QUICK_START_SYNC.md` for implementation

2. **Update Your Code**
   - Start with authentication flow
   - Update data loading to use sync
   - Migrate CRUD operations
   - Add periodic sync

3. **Test Thoroughly**
   - Test on single device
   - Test multi-device sync
   - Test conflict scenarios
   - Test offline behavior

4. **Monitor and Optimize**
   - Watch for sync errors
   - Monitor conflict frequency
   - Optimize sync frequency
   - Consider local caching

## Support

For questions or issues:
1. Check `SYNC_ARCHITECTURE.md` for detailed info
2. Review `sync_app_state_example.dart` for working code
3. Test with Postman collection
4. Check backend logs at `http://localhost:5000`

## Version Info

- **Backend API Version**: v1
- **Sync Protocol**: Offline-First with Last-Write-Wins
- **Flutter SDK**: >=3.2.6 <4.0.0
- **Base URL**: http://localhost:5000/api/v1
