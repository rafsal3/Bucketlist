# First-Time Sync Race Condition Fix

## Date: 2026-01-02

## Problem Statement

**User Report:**
> "The action glitch (like marking done or undone, adding items not working properly) is happening at the initial stage that is first time. When it started to sync, the next actions don't have this problem."

## Root Cause Analysis

### The Race Condition

When a user **registers for the first time** or **logs in on a new device**, the following sequence occurs:

```
1. User registers/logs in
   ↓
2. registerWithLocalData() / login() called
   ↓
3. _pushToCloud() / _pullFromCloud() starts
   ↓
4. setSyncing() called → _isSyncing = true
   ↓
5. User tries to add/toggle/delete items (UI is responsive)
   ↓
6. mutateData() called
   ↓
7. mutateData() saves data locally ✅
   ↓
8. mutateData() calls _markSyncPending()
   ↓
9. _markSyncPending() checks: if (_isSyncing) return; ❌
   ↓
10. Mutation is NOT queued for sync!
   ↓
11. First sync completes
   ↓
12. User's changes are saved locally but NEVER synced
```

### Why This Happens

**In `_markSyncPending()`:**
```dart
void _markSyncPending() {
  // Prevent concurrent syncs
  if (_isSyncing) {
    debugPrint('Sync already in progress, skipping...');
    return; // ❌ PROBLEM: Mutation is lost!
  }
  
  // ... debounce logic
}
```

**The Issue:**
- When `_isSyncing = true`, `_markSyncPending()` returns early
- The user's mutation is saved locally but **NOT marked for sync**
- When the initial sync completes, the changes are lost

### Why It Only Happens on First Sync

- **First-time sync** takes longer (pushing/pulling all data)
- **Subsequent syncs** are faster (debounced, smaller payloads)
- Users are more likely to interact during the longer first sync
- After first sync completes, syncs are fast enough that race condition is rare

---

## Solution: Mutation Queue with Sync Lock

### Strategy

1. **Add a mutation queue** to store actions that occur during sync
2. **Process the queue** after sync completes
3. **Prevent data loss** by ensuring all mutations are eventually synced

### Implementation

#### Step 1: Add Queue Fields to AppState

**Location:** `lib/providers/app_state.dart` (top of AppState class)

```dart
class AppState extends ChangeNotifier {
  // ... existing fields ...
  
  // 🔒 Sync Lock & Mutation Queue
  bool _isSyncing = false;
  bool _isMutating = false;
  final List<Function> _pendingMutations = [];
```

#### Step 2: Update `mutateData()` with Queue Logic

**Replace existing `mutateData()` method:**

```dart
/// Executes a mutation action with proper sync coordination
/// If a sync is in progress, queues the mutation for later execution
Future<void> mutateData(Function action) async {
  // If currently syncing, queue the mutation
  if (_isSyncing) {
    debugPrint('⚠️ Sync in progress, queuing mutation...');
    _pendingMutations.add(action);
    return;
  }

  // If another mutation is in progress, queue this one
  if (_isMutating) {
    debugPrint('⚠️ Mutation in progress, queuing...');
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
```

#### Step 3: Process Queue After Sync Completes

**Update `_pushToCloud()` to process queue:**

```dart
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
    // ... existing push logic ...
    
    // Mark as synced
    setSynced();
    debugPrint('✅ Sync successful! New version: $_dataVersion');
  } catch (e) {
    // ... existing error handling ...
  } finally {
    _isSyncing = false;
    
    // 🔄 Process any pending mutations that occurred during sync
    await _processPendingMutations();
  }
}
```

**Update `_pullFromCloud()` to process queue:**

```dart
/// Pull data from cloud and replace local database completely
Future<void> _pullFromCloud() async {
  if (_isSyncing) {
    debugPrint('Sync already in progress, skipping pull');
    return;
  }

  _isSyncing = true;
  setSyncing();

  try {
    // ... existing pull logic ...
    
    debugPrint('✅ Pull successful! Version: $_dataVersion');
  } catch (e) {
    // ... existing error handling ...
  } finally {
    _isSyncing = false;
    
    // 🔄 Process any pending mutations that occurred during pull
    await _processPendingMutations();
  }
}
```

**Update `_applySyncData()` to process queue:**

```dart
/// Apply data from server to local state (Overwrite)
Future<void> _applySyncData(Map<String, dynamic> data, int? version) async {
  // ... existing validation and apply logic ...
  
  try {
    // ... existing data replacement logic ...
    
    // Mark as synced
    setSynced();
    debugPrint('✅ Data applied successfully! Version: $_dataVersion, Spaces: ${_spaces.length}');

    // Notify UI
    notifyListeners();
    
    // 🔄 Process any pending mutations that occurred during sync
    // Note: _applySyncData is called within _pushToCloud's try-catch,
    // so we don't need to process queue here (it's handled in finally block)
  } catch (e) {
    // ... existing error handling ...
  }
}
```

#### Step 4: Add Queue Processing Method

**Add new method to AppState:**

```dart
/// Process all pending mutations that were queued during sync
Future<void> _processPendingMutations() async {
  if (_pendingMutations.isEmpty) {
    return;
  }

  debugPrint('🔄 Processing ${_pendingMutations.length} pending mutations...');

  // Create a copy of the queue and clear it
  final mutations = List<Function>.from(_pendingMutations);
  _pendingMutations.clear();

  // Execute each mutation sequentially
  for (final mutation in mutations) {
    await _executeMutation(mutation);
  }

  debugPrint('✅ All pending mutations processed!');
}
```

---

## Testing Plan

### Test Case 1: First-Time Registration with Rapid Actions

**Steps:**
1. Fresh install (clear app data)
2. Create 2-3 items offline
3. Register account
4. **Immediately** start adding/toggling items (rapid taps)
5. Wait for sync to complete
6. Verify all items are present and synced

**Expected Result:**
- All items created during sync are saved locally ✅
- All items are queued and synced after initial sync completes ✅
- No data loss ✅

### Test Case 2: New Device Login with Rapid Actions

**Steps:**
1. Login on new device (empty local DB)
2. **Immediately** start adding/toggling items during pull
3. Wait for pull to complete
4. Verify all items are present and synced

**Expected Result:**
- Items added during pull are queued ✅
- After pull completes, queued mutations are executed ✅
- All items are synced to server ✅

### Test Case 3: Conflict Resolution with Pending Mutations

**Steps:**
1. Create items on Device A
2. Create different items on Device B
3. Sync Device A (triggers conflict on Device B)
4. **During conflict resolution**, add new items on Device B
5. Verify all items are preserved

**Expected Result:**
- Conflict is resolved (server data wins) ✅
- Pending mutations are executed after conflict resolution ✅
- New items are synced ✅

### Test Case 4: Multiple Rapid Mutations

**Steps:**
1. Tap "Add Item" button 10 times rapidly
2. Verify all 10 items are created
3. Verify all 10 items are synced

**Expected Result:**
- All 10 items are saved locally ✅
- All 10 items are synced to server ✅
- No race conditions ✅

---

## Implementation Checklist

- [ ] Add `_isMutating` and `_pendingMutations` fields to AppState
- [ ] Update `mutateData()` to queue mutations during sync
- [ ] Add `_executeMutation()` helper method
- [ ] Update `_pushToCloud()` to process queue in finally block
- [ ] Update `_pullFromCloud()` to process queue in finally block
- [ ] Add `_processPendingMutations()` method
- [ ] Test all 4 test cases
- [ ] Verify no regressions in existing functionality

---

## Additional Improvements

### 1. Add Debug Logging

Add comprehensive logging to track queue behavior:

```dart
Future<void> mutateData(Function action) async {
  if (_isSyncing) {
    debugPrint('⚠️ Sync in progress, queuing mutation (queue size: ${_pendingMutations.length + 1})');
    _pendingMutations.add(action);
    return;
  }

  if (_isMutating) {
    debugPrint('⚠️ Mutation in progress, queuing (queue size: ${_pendingMutations.length + 1})');
    _pendingMutations.add(action);
    return;
  }

  await _executeMutation(action);
}
```

### 2. Add Queue Size Limit (Optional)

Prevent memory issues if queue grows too large:

```dart
Future<void> mutateData(Function action) async {
  // Prevent queue from growing too large
  if (_pendingMutations.length >= 100) {
    debugPrint('❌ Mutation queue full (100 items), dropping mutation');
    return;
  }

  // ... rest of logic
}
```

### 3. Add Sync Status Indicator in UI

Show users when sync is in progress:

```dart
// In home_screen.dart or wherever sync status is shown
if (appState.isSyncing) {
  return LinearProgressIndicator();
}
```

---

## Summary

**Problem:** Race condition during first-time sync causes user actions to be lost

**Root Cause:** `_markSyncPending()` returns early when `_isSyncing = true`, preventing mutations from being synced

**Solution:** Queue mutations during sync and process them after sync completes

**Impact:** 
- ✅ No data loss during first-time sync
- ✅ All user actions are preserved and synced
- ✅ Better user experience during registration/login
- ✅ No breaking changes to existing functionality

**Files Modified:** 
- `lib/providers/app_state.dart` (only file that needs changes)

**Lines of Code:** ~50 lines added

**Risk:** Low (isolated changes, backward compatible)
