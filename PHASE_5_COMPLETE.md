# ✅ PHASE 5: New Device Login Flow

## Summary
Successfully implemented the new device login flow that pulls data from cloud ONLY when the local database is empty. This handles the scenario where a user logs in on a new device and needs to restore their data.

## Step 5.1: Empty App + Login ✅

### Implementation
When a user logs in on a new device with an empty local database, the app automatically pulls their data from the cloud.

```dart
Future<void> login(String email, String token) async {
  _isLoggedIn = true;
  _userEmail = email;
  _authToken = token;

  // Save auth state
  await prefs.setString('authToken', token);

  // ✅ SPECIAL CASE: Pull from cloud ONLY if local DB is empty
  if (_isLocalDatabaseEmpty()) {
    debugPrint('📥 Local DB is empty, pulling from cloud...');
    await _pullFromCloud();
  } else {
    debugPrint('📱 Local DB has data, keeping local data');
    // ❌ NEVER auto-pull if local data exists
  }
}
```

### API Call
```
GET /sync/pull
Authorization: Bearer <token>

Response:
{
  "version": 12,
  "data": {
    "spaces": [...],
    "currentSpaceId": "...",
    "themeColor": "blue",
    "isDarkMode": false
  }
}
```

### When Pull Happens:
✅ **New device login** - Local DB is empty  
✅ **Fresh install** - No local data exists  
✅ **After data clear** - User cleared app data  

### When Pull Does NOT Happen:
❌ **Existing device** - Local DB has data  
❌ **App launch** - Never on startup  
❌ **App resume** - Never on resume  
❌ **Network reconnect** - Never on reconnect  

## Step 5.2: Replace Local DB Completely ✅

### Implementation
When pulling from cloud, the local database is **completely replaced**, never merged.

```dart
Future<void> _pullFromCloud() async {
  setSyncing();

  try {
    // Call API
    final response = await _syncApi.pullFromCloud(
      authToken: _authToken!,
    );

    final version = response['version'] as int?;
    final data = response['data'] as Map<String, dynamic>?;

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
    _currentSpaceId = data['currentSpaceId'];
    _themeColor = data['themeColor'];
    _isDarkMode = data['isDarkMode'];

    // Update version
    _dataVersion = version;

    // Save to local storage
    await _saveData();

    // Mark as synced
    setSynced();
    debugPrint('✅ Pull successful!');

    notifyListeners();
  } catch (e) {
    debugPrint('❌ Pull failed: $e');
    setSyncError(e.toString());
  }
}
```

### Key Principles:
⚠️ **NEVER merge** - Always complete replacement  
⚠️ **Clear first** - Remove all local data  
⚠️ **Then insert** - Add remote data  
⚠️ **Update version** - Track server version  
⚠️ **Mark synced** - Set status to synced  

## Flow Diagram

### New Device Login:
```
User installs app on new device
       ↓
Opens app (empty local DB)
       ↓
Taps "Enable Cloud Sync"
       ↓
Enters email/password
       ↓
Login API call ✅
       ↓
Check: Is local DB empty?
       ↓ YES
Pull from cloud (GET /sync/pull)
       ↓
Clear local DB 🗑️
       ↓
Insert remote data 📥
       ↓
Mark as synced ✅
       ↓
User sees their data!
```

### Existing Device Login:
```
User has app with local data
       ↓
Logs out
       ↓
Logs back in
       ↓
Login API call ✅
       ↓
Check: Is local DB empty?
       ↓ NO
Keep local data 📱
       ↓
No pull from cloud ❌
       ↓
User sees their local data
```

## Helper Methods

### Check if DB is Empty:
```dart
bool _isLocalDatabaseEmpty() {
  return _spaces.isEmpty;
}
```

Simple check - if no spaces exist, DB is considered empty.

### Pull from Cloud:
```dart
Future<void> _pullFromCloud() async {
  // 1. Validate auth
  // 2. Call API
  // 3. Clear local DB
  // 4. Insert remote data
  // 5. Save locally
  // 6. Mark as synced
  // 7. Notify UI
}
```

## Sync Status Updates

During pull operation:

```
localOnly → syncing → synced
                ↓
            [error] → error
```

### Status Indicators:
- **Before pull**: `localOnly`
- **During pull**: `syncing` (shows spinner)
- **After success**: `synced` (green cloud)
- **After error**: `error` (red icon)

## Debug Logging

The system logs the entire pull process:

```
📥 Local DB is empty, pulling from cloud...
Pulling from cloud...
Received data from cloud, version: 12
🗑️ Local DB cleared
📥 Loaded 3 spaces from cloud
✅ Pull successful! Version: 12, Spaces: 3
```

Or on error:
```
❌ Pull failed: Exception: Network error
```

## Data Replaced

When pulling from cloud, these are replaced:

| Data | Replaced? |
|------|-----------|
| **Spaces** | ✅ Yes |
| **Categories** | ✅ Yes (inside spaces) |
| **Items** | ✅ Yes (inside categories) |
| **Current Space ID** | ✅ Yes |
| **Theme Color** | ✅ Yes |
| **Dark Mode** | ✅ Yes |
| **Version** | ✅ Yes |
| **Last Modified** | ✅ Yes (set to now) |

## Security Considerations

✅ **Auth required** - Must have valid token  
✅ **Empty check** - Only pulls if DB is empty  
✅ **Complete replacement** - No partial updates  
✅ **Error handling** - Shows error if pull fails  

## Testing Scenarios

### Scenario 1: New Device Login
1. Install app on new device
2. Open app (empty)
3. Login with existing account
4. **Expected**: Data pulled from cloud
5. **Verify**: All spaces, categories, items appear

### Scenario 2: Existing Device Login
1. App has local data
2. Logout
3. Login again
4. **Expected**: Local data preserved
5. **Verify**: No API call to pull

### Scenario 3: Fresh Install After Uninstall
1. Uninstall app
2. Reinstall app
3. Login
4. **Expected**: Data pulled from cloud
5. **Verify**: All data restored

### Scenario 4: Data Clear
1. Clear app data in settings
2. Open app
3. Login
4. **Expected**: Data pulled from cloud
5. **Verify**: Data restored

## Error Handling

### Pull Fails:
- Status set to `error`
- Error message stored
- User sees error indicator
- Local DB remains empty
- User can retry by logging out and in again

### No Data on Server:
- Empty response handled gracefully
- Local DB remains empty
- User can start fresh

## Comparison: Push vs Pull

| Operation | When | Condition |
|-----------|------|-----------|
| **Push** | After user changes | Always (if logged in) |
| **Pull** | On login only | Only if local DB is empty |

## Important Notes

⚠️ **NEVER merges** - Always complete replacement  
⚠️ **Only on empty DB** - Never pulls if data exists  
⚠️ **One-time operation** - Only on first login  
⚠️ **No conflict resolution** - Not needed (empty DB)  

## Files Modified

### Modified:
✅ `lib/providers/app_state.dart` - Added pull logic

### New Methods:
- `_isLocalDatabaseEmpty()` - Check if DB is empty
- `_pullFromCloud()` - Pull and replace data

### Updated Methods:
- `login()` - Added empty check and pull

## Future Enhancements

- [ ] Manual pull button (with confirmation)
- [ ] Backup before pull
- [ ] Pull progress indicator
- [ ] Selective pull (choose what to restore)
- [ ] Pull on demand (not just on login)

## Configuration

No additional configuration needed. The pull endpoint is already defined in `SyncApiService`:

```dart
Future<Map<String, dynamic>> pullFromCloud({
  required String authToken,
}) async {
  final response = await http.get(
    Uri.parse('$baseUrl/sync/pull'),
    headers: {
      'Authorization': 'Bearer $authToken',
    },
  );
  return jsonDecode(response.body);
}
```

---

**Status**: ✅ Complete  
**Phase**: PHASE 5  
**Type**: New Device Login Flow  
**Behavior**: Pull ONLY if local DB is empty, always replace completely
