# Sync Issues Analysis

## Date: 2026-01-02

## ✅ FIXED: First-Time Sync Race Condition

**Status:** IMPLEMENTED (2026-01-02)

See detailed fix documentation: [FIRST_TIME_SYNC_RACE_CONDITION_FIX.md](./FIRST_TIME_SYNC_RACE_CONDITION_FIX.md)

**Summary:**
- Added mutation queue to prevent data loss during sync
- Mutations are queued if sync is in progress
- Queue is processed after sync completes
- **Changed trigger logic:** Sync (Push) fires immediately on App Start and Login (for existing data)
- No breaking changes to existing functionality

---

## Issues Identified

### 🔴 CRITICAL ISSUE #1: Pull from Cloud Called on Every Login
**Location:** `lib/providers/app_state.dart` - Line 287-290

**Problem:**
```dart
// ✅ ALWAYS Pull from cloud on login
// This ensures the app starts with correct server data
debugPrint('📥 Login successful, pulling from cloud...');
await _pullFromCloud();
```

The `login()` method **ALWAYS** pulls from cloud, even for existing users who already have local data. This is WRONG!

**Impact:**
- Every time an existing user logs in, their local data is replaced with server data
- This can cause data loss if the user made offline changes
- Unnecessary network calls on every login
- Poor user experience

**Expected Behavior:**
- Pull from cloud should ONLY happen for **new device login** (when local DB is empty)
- For existing users, login should just authenticate and enable sync
- Local data should be preserved

---

### 🟡 POTENTIAL ISSUE #2: Race Condition in mutateData()
**Location:** `lib/providers/app_state.dart` - Line 625-640

**Problem:**
```dart
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
```

**Potential Issues:**
1. **No async/await on action()**: If the action is async, it won't be awaited
2. **No mutex/lock**: Multiple rapid calls to `mutateData()` can cause race conditions
3. **notifyListeners() before save completes**: UI might update before data is persisted

**Impact:**
- Items might not be saved if multiple rapid additions occur
- UI might show items that aren't actually persisted yet
- Sync might trigger before data is fully saved

**Example Scenario:**
```
User taps "Add Item" button rapidly 3 times:
Call 1: action() -> _saveData() starts
Call 2: action() -> _saveData() starts (Call 1 not finished)
Call 3: action() -> _saveData() starts (Call 1, 2 not finished)
Result: Only the last item might be saved, first 2 could be lost
```

---

### 🟡 POTENTIAL ISSUE #3: _pullFromCloud() Clears Data Before Checking Response
**Location:** `lib/providers/app_state.dart` - Line 565-567

**Problem:**
```dart
Future<void> _applySyncData(Map<String, dynamic> data, int? version) async {
  // ⚠️ STEP 1: Clear local database completely
  _spaces.clear();
  debugPrint('🗑️ Local DB cleared');
  
  // ⚠️ STEP 2: Replace with remote data (NEVER merge)
  if (data.containsKey('spaces')) {
    // ...
  }
}
```

**Issue:**
- Data is cleared BEFORE verifying the server response is valid
- If the server returns empty data or an error, local data is already lost

**Impact:**
- Data loss if server returns invalid/empty data
- No rollback mechanism

---

### 🟢 MINOR ISSUE #4: Duplicate Debug Print
**Location:** `lib/providers/app_state.dart` - Line 550-552

**Problem:**
```dart
debugPrint('Received data from cloud, version: $version');

debugPrint('Received data from cloud, version: $version');
```

Same debug print appears twice.

---

## Recommended Fixes

### Fix #1: Only Pull from Cloud on New Device Login

**Change in `login()` method:**

```dart
/// Login user with email and auth token
/// ONLY pulls from cloud if local DB is empty (new device)
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

  // ✅ ONLY Pull from cloud if local DB is empty (new device login)
  if (_isLocalDatabaseEmpty()) {
    debugPrint('📥 New device login detected, pulling from cloud...');
    await _pullFromCloud();
  } else {
    debugPrint('✅ Existing user login - preserving local data');
    debugPrint('🔄 Sync will happen automatically via debounced push');
    // Trigger a sync to push any local changes
    _markSyncPending();
  }
}
```

---

### Fix #2: Add Mutex to Prevent Race Conditions

**Add at top of AppState class:**
```dart
bool _isMutating = false;
final List<Function> _mutationQueue = [];
```

**Update mutateData():**
```dart
Future<void> mutateData(Function action) async {
  // Queue mutations if one is already in progress
  if (_isMutating) {
    debugPrint('⚠️ Mutation in progress, queuing...');
    _mutationQueue.add(action);
    return;
  }

  _isMutating = true;

  try {
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
  } finally {
    _isMutating = false;

    // Process queued mutations
    if (_mutationQueue.isNotEmpty) {
      final nextAction = _mutationQueue.removeAt(0);
      await mutateData(nextAction);
    }
  }
}
```

---

### Fix #3: Validate Data Before Clearing Local DB

**Update _applySyncData():**
```dart
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

    // ⚠️ STEP 3: Replace with remote data
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

    // Save to local storage
    await _saveData();

    // Mark as synced
    setSynced();
    debugPrint('✅ Data applied successfully! Version: $_dataVersion, Spaces: ${_spaces.length}');

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
```

---

### Fix #4: Remove Duplicate Debug Print

**Line 550-552, remove one of the duplicate lines**

---

## Testing Checklist

After applying fixes, test:

1. ✅ **New User Registration**
   - Create account with offline data
   - Verify data is pushed to server
   - Verify data is NOT pulled (local data preserved)

2. ✅ **New Device Login**
   - Login on fresh device (empty local DB)
   - Verify data is pulled from server
   - Verify local data is replaced

3. ✅ **Existing User Login**
   - Login on device with existing data
   - Verify local data is NOT replaced
   - Verify sync happens automatically

4. ✅ **Rapid Item Addition**
   - Add 5 items rapidly (tap button fast)
   - Verify all 5 items are saved
   - Verify all 5 items sync to server

5. ✅ **Offline -> Online Sync**
   - Add items while offline
   - Login/go online
   - Verify items sync to server

6. ✅ **Conflict Resolution**
   - Create conflict (modify data on 2 devices)
   - Verify server data wins (409 conflict)
   - Verify local data is replaced

---

## Summary

**Critical Issues:** 1
**Potential Issues:** 2
**Minor Issues:** 1

**Total Fixes Required:** 4

**Priority:**
1. Fix #1 (Critical) - Pull only on new device login
2. Fix #2 (High) - Add mutex to prevent race conditions
3. Fix #3 (Medium) - Validate data before clearing
4. Fix #4 (Low) - Remove duplicate debug print
