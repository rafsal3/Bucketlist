# Quick Start Guide: Offline-First Sync

This guide will help you quickly integrate the new offline-first sync architecture into your Flutter app.

## Step 1: Understanding the Architecture

The new backend uses a **sync-based approach** instead of traditional CRUD:
- **Old**: Create → Server stores → Get back ID
- **New**: Create locally with UUID → Sync to server → Merge changes

## Step 2: Basic Setup

### Import Required Services

```dart
import 'package:flutter_application_1/services/sync_service.dart';
import 'package:flutter_application_1/services/sync_helper.dart';
import 'package:flutter_application_1/services/device_manager.dart';
import 'package:flutter_application_1/models/sync_models.dart';
```

### Initialize Services

```dart
final syncService = SyncService();
final deviceId = await DeviceManager.instance.getDeviceId();

// After login
syncService.setToken(authToken);
```

## Step 3: Initial Data Load

After user logs in, pull all data from server:

```dart
Future<void> loadInitialData() async {
  try {
    // Full sync on first load
    final pullResponse = await syncService.pullChanges(fullSync: true);
    
    // Parse spaces
    final spaces = pullResponse.changes.spaces
        .map((json) => Space.fromJson(json))
        .toList();
    
    // Filter out deleted items
    final activeSpaces = SyncHelper.filterDeleted(spaces);
    
    // Sort by order
    final sortedSpaces = SyncHelper.sortByOrder(activeSpaces);
    
    // Update your state
    setState(() {
      _spaces = sortedSpaces;
    });
  } catch (e) {
    print('Error loading data: $e');
  }
}
```

## Step 4: Creating New Data

### Create a Space

```dart
Future<void> createSpace(String name, String icon) async {
  // Create locally
  final space = await SyncHelper.createSpace(
    name: name,
    icon: icon,
    userId: currentUserId,
    order: spaces.length,
  );
  
  // Add to local state
  setState(() {
    spaces.add(space);
  });
  
  // Push to server
  final changes = SyncHelper.buildSyncChanges(spaces: [space]);
  await syncService.pushChanges(changes);
}
```

### Create a Category

```dart
Future<void> createCategory(String spaceId, String name, String icon) async {
  final category = await SyncHelper.createCategory(
    name: name,
    icon: icon,
    spaceId: spaceId,
    userId: currentUserId,
    order: categories.length,
  );
  
  // Add to local state
  setState(() {
    categories.add(category);
  });
  
  // Push to server
  final changes = SyncHelper.buildSyncChanges(categories: [category]);
  await syncService.pushChanges(changes);
}
```

### Create an Item

```dart
Future<void> createItem(String text, {String? categoryId}) async {
  final item = await SyncHelper.createItem(
    text: text,
    spaceId: currentSpaceId,
    userId: currentUserId,
    categoryId: categoryId,
    order: items.length,
  );
  
  // Add to local state
  setState(() {
    items.add(item);
  });
  
  // Push to server
  final changes = SyncHelper.buildSyncChanges(items: [item]);
  await syncService.pushChanges(changes);
}
```

## Step 5: Updating Data

```dart
Future<void> updateSpace(Space space, String newName, String newIcon) async {
  // Update locally
  space.name = newName;
  space.icon = newIcon;
  await SyncHelper.markAsUpdated(space);
  
  setState(() {});
  
  // Push to server
  final changes = SyncHelper.buildSyncChanges(spaces: [space]);
  await syncService.pushChanges(changes);
}
```

## Step 6: Deleting Data (Soft Delete)

```dart
Future<void> deleteSpace(Space space) async {
  // Soft delete locally
  await SyncHelper.softDelete(space);
  
  setState(() {});
  
  // Push to server
  final changes = SyncHelper.buildSyncChanges(spaces: [space]);
  await syncService.pushChanges(changes);
}
```

## Step 7: Periodic Sync

Set up periodic syncing to keep data fresh:

```dart
Timer? _syncTimer;

void startPeriodicSync() {
  _syncTimer = Timer.periodic(Duration(minutes: 5), (_) async {
    await performSync();
  });
}

Future<void> performSync() async {
  try {
    final pullResponse = await syncService.pullChanges();
    
    // Merge server changes with local data
    mergeServerChanges(pullResponse.changes);
    
    // Handle conflicts if any
    if (pullResponse.conflicts.isNotEmpty) {
      handleConflicts(pullResponse.conflicts);
    }
  } catch (e) {
    print('Sync error: $e');
  }
}

void stopPeriodicSync() {
  _syncTimer?.cancel();
}
```

## Step 8: Handling Conflicts

```dart
void handleConflicts(List<ConflictInfo> conflicts) {
  for (var conflict in conflicts) {
    print('Conflict detected:');
    print('  Type: ${conflict.type}');
    print('  ID: ${conflict.id}');
    print('  Reason: ${conflict.reason}');
    
    // The server version is already applied (Last-Write-Wins)
    // You can show a notification to the user
    showConflictNotification(conflict);
  }
}
```

## Step 9: Merging Server Changes

```dart
void mergeServerChanges(SyncChanges serverChanges) {
  // Merge spaces
  for (var spaceJson in serverChanges.spaces) {
    final serverSpace = Space.fromJson(spaceJson);
    final existingIndex = spaces.indexWhere((s) => s.id == serverSpace.id);
    
    if (existingIndex >= 0) {
      // Update existing
      spaces[existingIndex] = SyncHelper.mergeEntity(
        spaces[existingIndex],
        serverSpace,
      );
    } else {
      // Add new
      spaces.add(serverSpace);
    }
  }
  
  // Filter deleted and sort
  spaces = SyncHelper.sortByOrder(SyncHelper.filterDeleted(spaces));
  
  setState(() {});
}
```

## Step 10: Backup & Restore

### Create Backup

```dart
Future<void> createBackup() async {
  try {
    final backup = await syncService.createBackup();
    
    // Save backup data (e.g., to file or cloud storage)
    await saveBackupToFile(backup);
    
    showSnackBar('Backup created successfully');
  } catch (e) {
    showSnackBar('Backup failed: $e');
  }
}
```

### Restore Backup

```dart
Future<void> restoreBackup(Map<String, dynamic> backupData) async {
  try {
    await syncService.restoreBackup(backupData);
    
    // Reload all data
    await loadInitialData();
    
    showSnackBar('Backup restored successfully');
  } catch (e) {
    showSnackBar('Restore failed: $e');
  }
}
```

## Common Patterns

### Pattern 1: Optimistic UI Updates

```dart
Future<void> toggleItem(ChecklistItem item) async {
  // Update UI immediately
  item.isCompleted = !item.isCompleted;
  await SyncHelper.markAsUpdated(item);
  setState(() {});
  
  // Sync in background
  syncService.pushChanges(
    SyncHelper.buildSyncChanges(items: [item]),
  ).catchError((e) {
    // Revert on error
    item.isCompleted = !item.isCompleted;
    setState(() {});
    showSnackBar('Failed to sync: $e');
  });
}
```

### Pattern 2: Batch Operations

```dart
Future<void> completeAllItems(List<ChecklistItem> items) async {
  // Update all locally
  for (var item in items) {
    item.isCompleted = true;
    await SyncHelper.markAsUpdated(item);
  }
  setState(() {});
  
  // Push all at once
  final changes = SyncHelper.buildSyncChanges(items: items);
  await syncService.pushChanges(changes);
}
```

### Pattern 3: Offline Queue

```dart
List<SyncChanges> _pendingChanges = [];

Future<void> queueChange(SyncChanges change) async {
  _pendingChanges.add(change);
  
  // Try to sync
  if (await isOnline()) {
    await flushQueue();
  }
}

Future<void> flushQueue() async {
  while (_pendingChanges.isNotEmpty) {
    final change = _pendingChanges.first;
    try {
      await syncService.pushChanges(change);
      _pendingChanges.removeAt(0);
    } catch (e) {
      print('Failed to sync queued change: $e');
      break; // Stop on error
    }
  }
}
```

## Testing

### Test with Postman

1. Import `postman-sync-collection.json`
2. Run "Register" or "Login" to get auth token
3. Test "Push Changes" with sample data
4. Test "Pull Changes" to verify sync
5. Test conflict scenarios

### Test in App

```dart
// Test creating data
await createSpace('Test Space', '📝');
await createCategory(spaceId, 'Test Category', '📌');
await createItem('Test Item', categoryId: categoryId);

// Test syncing
await performSync();

// Test conflicts (run on two devices)
// 1. Edit same item on both devices
// 2. Sync device 1
// 3. Sync device 2
// 4. Check conflict handling
```

## Troubleshooting

### Issue: "Device ID not found"
**Solution**: Device ID is auto-generated on first use. Just call:
```dart
final deviceId = await DeviceManager.instance.getDeviceId();
```

### Issue: "Sync conflicts not resolving"
**Solution**: Check that `updatedAt` timestamps are being set:
```dart
await SyncHelper.markAsUpdated(entity);
```

### Issue: "Deleted items still showing"
**Solution**: Filter deleted items:
```dart
final activeItems = SyncHelper.filterDeleted(allItems);
```

### Issue: "Items in wrong order"
**Solution**: Sort by order field:
```dart
final sortedItems = SyncHelper.sortByOrder(items);
```

## Next Steps

1. ✅ Set up sync service
2. ✅ Implement initial data load
3. ✅ Update CRUD operations to use sync
4. ✅ Add periodic sync
5. ✅ Handle conflicts
6. ✅ Test thoroughly
7. 🔄 Add offline queue (optional)
8. 🔄 Add local SQLite cache (optional)
9. 🔄 Add background sync (optional)

## Resources

- Full documentation: `SYNC_ARCHITECTURE.md`
- Example provider: `lib/providers/sync_app_state_example.dart`
- Postman collection: `postman-sync-collection.json`
- Backend API: `http://localhost:5000/api/v1`

## Need Help?

Check the example provider in `lib/providers/sync_app_state_example.dart` for a complete working implementation.
