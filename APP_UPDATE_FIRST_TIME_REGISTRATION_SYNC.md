# App Update: First-Time Registration with Pre-Existing Local Data

## ✅ SOLUTION IMPLEMENTED

**Status:** FIXED ✅

The issue where offline data was cleared during first-time registration has been resolved!

**Changes Made:**
1. **CloudSyncScreen** (`lib/screens/cloud_sync_screen.dart`): Modified to distinguish between login and registration flows
2. **AppState** (`lib/providers/app_state.dart`): Added `registerWithLocalData()` method that:
   - Saves authentication credentials
   - Checks if local data exists
   - Pushes local data to server with `version: 0` (first-time sync)
   - Then pulls from cloud to ensure sync

**How it works:**
- **Login**: Pulls from cloud (existing user, get their data)
- **Registration**: Pushes local data first (if any), then pulls (new user, preserve offline work)

---

## 📋 Scenario

When a user adds data to the app **before registering** (in offline/guest mode), that data must be pushed to the server immediately after the user completes registration for the first time.

**Previous Issue:**
- User creates spaces, categories, and items while offline (before registration)
- User then registers with email/password
- Backend creates an empty user data record
- Local data was cleared when pulling from empty server

**Fixed Behavior:**
- User creates data offline
- User registers
- All pre-existing local data is immediately pushed to the server
- Server creates user data with the client's data (not empty)


---

## ✅ Backend Status

**GOOD NEWS:** The backend already supports this scenario!

The `/api/sync/push` endpoint in `src/controllers/syncController.js` (lines 22-32) handles the case where user data doesn't exist:

```javascript
if (!userData) {
    // Create new user data if doesn't exist
    console.log(`[Sync] Creating new data for user ${userId}`);
    userData = new UserData({
        userId,
        version: 1,
        data: normalizedData
    });
}
```

**What this means:**
- You can push data immediately after registration
- The backend will create user data with your pushed content
- No backend changes are needed

---

## 🔧 Required App Changes

### Overview

You need to modify the registration flow to:
1. Register the user (POST /api/auth/register)
2. Save the token and userId
3. **Immediately push all local data** (POST /api/sync/push with version: 0)
4. Update local sync version
5. Navigate to the home screen

---

## 📝 Implementation Steps

### Step 1: Update Registration Method

**File:** `lib/services/auth_service.dart` (or wherever you handle authentication)

**Add this method:**

```dart
Future<void> register({
  required String email,
  required String password,
}) async {
  try {
    // Call registration endpoint
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      final userId = data['userId'];

      // Save credentials to local storage
      await _secureStorage.write(key: 'auth_token', value: token);
      await _secureStorage.write(key: 'user_id', value: userId);

      print('[Auth] Registration successful. Token saved.');

      // CRITICAL: Push any existing local data to server
      await _syncLocalDataAfterRegistration(token);

    } else if (response.statusCode == 409) {
      throw Exception('User already exists');
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Registration failed';
      throw Exception(error);
    }
  } catch (e) {
    print('[Auth] Registration error: $e');
    rethrow;
  }
}

// Helper method to sync local data after registration
Future<void> _syncLocalDataAfterRegistration(String token) async {
  try {
    // Get all local data from database
    final localData = await _buildLocalDataPayload();
    
    // Check if there's any data to sync
    if (_isDataEmpty(localData)) {
      print('[Auth] No local data to sync after registration');
      return;
    }

    print('[Auth] Syncing local data after registration...');

    // Push to server with version 0 (first sync)
    final response = await http.post(
      Uri.parse('$baseUrl/api/sync/push'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'data': localData,
        'version': 0,  // IMPORTANT: version 0 for first-time push
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final serverVersion = responseData['version'];
      
      // Update local sync metadata
      await _updateLocalSyncVersion(serverVersion);
      
      print('[Auth] Local data synced successfully. Server version: $serverVersion');
    } else {
      print('[Auth] Warning: Failed to sync local data (${response.statusCode})');
      // Don't throw - registration was successful, sync can happen later
    }
  } catch (e) {
    print('[Auth] Error syncing local data: $e');
    // Don't throw - registration succeeded, sync can happen later
  }
}

// Build the data payload from local database
Future<Map<String, dynamic>> _buildLocalDataPayload() async {
  final db = await DatabaseHelper.instance.database;
  
  // Get all spaces with their nested data
  final spaces = await _getAllSpacesWithData();
  
  return {
    'spaces': spaces.map((space) => space.toJson()).toList(),
  };
}

// Check if data structure is empty
bool _isDataEmpty(Map<String, dynamic> data) {
  if (data.isEmpty) return true;
  
  final spaces = data['spaces'] as List?;
  return spaces == null || spaces.isEmpty;
}

// Update local sync version
Future<void> _updateLocalSyncVersion(int version) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('sync_version', version);
  await prefs.setString('sync_status', 'synced');
}

// Get all spaces with their categories and items
Future<List<Space>> _getAllSpacesWithData() async {
  // Use your existing database helper methods
  final db = DatabaseHelper.instance;
  return await db.getAllSpaces(); // Should include nested categories and items
}
```

---

### Step 2: Alternative - Use SyncService Directly

If you have a separate `SyncService` class, you can add this method:

**File:** `lib/services/sync_service.dart`

```dart
/// Push local data to server immediately after registration
/// This should be called only once, right after registration
Future<void> pushLocalDataAfterRegistration() async {
  try {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No auth token found');
    }

    // Build data from local database
    final localData = await _buildSyncPayload();

    // Check if there's anything to sync
    if (localData['spaces'] == null || (localData['spaces'] as List).isEmpty) {
      print('[Sync] No local data to push after registration');
      return;
    }

    print('[Sync] Pushing ${(localData['spaces'] as List).length} spaces after registration...');

    // Push with version 0
    final response = await http.post(
      Uri.parse('$baseUrl/api/sync/push'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'data': localData,
        'version': 0,  // First sync after registration
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newVersion = data['version'];
      
      // Update local version
      await _saveLocalVersion(newVersion);
      await _updateSyncStatus('synced');
      
      print('[Sync] Initial push completed. Server version: $newVersion');
    } else {
      throw Exception('Failed to push: ${response.statusCode}');
    }
  } catch (e) {
    print('[Sync] Error pushing local data after registration: $e');
    // Don't throw - we'll sync later
  }
}

Future<Map<String, dynamic>> _buildSyncPayload() async {
  // Get all local data
  final spaces = await _databaseHelper.getAllSpaces();
  
  return {
    'spaces': spaces.map((s) => s.toJson()).toList(),
  };
}
```

**Then in AuthService:**

```dart
Future<void> register({
  required String email,
  required String password,
}) async {
  // ... registration code ...
  
  if (response.statusCode == 201) {
    // Save token and userId
    await _saveCredentials(token, userId);
    
    // Push local data using SyncService
    await _syncService.pushLocalDataAfterRegistration();
  }
}
```

---

### Step 3: Update Registration UI/Controller

**File:** `lib/screens/auth/register_screen.dart` or controller

```dart
Future<void> _handleRegistration() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    // Register user (this will also push local data)
    await _authService.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful! Syncing your data...'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to home screen
      Navigator.of(context).pushReplacementNamed('/home');
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
```

---

## 🧪 Testing Checklist

After implementing the changes, test the following scenarios:

### Test 1: Registration with Pre-Existing Data
- [ ] Open app (not logged in)
- [ ] Create 2-3 spaces with categories and items
- [ ] Go to registration screen
- [ ] Register with a new email/password
- [ ] **Expected:** Registration succeeds, data is pushed to server
- [ ] **Verify:** Check app logs for "Local data synced successfully"
- [ ] Logout and login again
- [ ] **Expected:** All the data you created is still there

### Test 2: Registration with No Local Data
- [ ] Uninstall and reinstall app
- [ ] Go directly to registration
- [ ] Register with a new email/password
- [ ] **Expected:** Registration succeeds, no sync errors
- [ ] **Verify:** Check logs for "No local data to sync"

### Test 3: Network Failure During Sync
- [ ] Create local data
- [ ] Turn off internet/WiFi
- [ ] Register (should fail due to no network)
- [ ] Turn on internet
- [ ] Register again
- [ ] **Expected:** Registration succeeds, data syncs

### Test 4: Data Verification
- [ ] Create data before registration
- [ ] Register
- [ ] Note the data
- [ ] Uninstall app
- [ ] Reinstall app
- [ ] Login with same credentials
- [ ] **Expected:** All the original data is pulled from server

### Test 5: Version Tracking
- [ ] Create local data
- [ ] Register
- [ ] Check local sync version (should be 1)
- [ ] Add more data and sync
- [ ] Check version (should be 2)
- [ ] **Expected:** Version increments correctly

---

## 🔍 Debugging

### Enable Detailed Logging

Add these print statements to track the flow:

```dart
// In auth_service.dart
print('[Auth] Starting registration for: $email');
print('[Auth] Registration successful. Token: ${token.substring(0, 10)}...');
print('[Auth] Found ${spaces.length} spaces to sync');
print('[Auth] Pushing to server with version: 0');
print('[Auth] Server responded with version: $serverVersion');
```

### Check Server Logs

After registration, check your backend logs:

```
[Sync] Push request for user 507f1f77bcf86cd799439011. Client v:0
[Sync] Creating new data for user 507f1f77bcf86cd799439011
[Sync] Push successful. New v:1
```

### Verify Database

You can use MongoDB Compass or similar tool to check:

```javascript
// Find the user's data
db.userdatas.findOne({ userId: ObjectId("507f1f77bcf86cd799439011") })

// Should show:
{
  userId: ObjectId("507f1f77bcf86cd799439011"),
  version: 1,
  data: {
    spaces: [/* your pushed spaces */]
  }
}
```

---

## ⚠️ Important Notes

1. **Version Must Be 0**: When pushing data right after registration, always use `version: 0`. This tells the backend it's the first sync and there's no conflict to check.

2. **Don't Block Registration**: If the sync fails after registration, don't show an error to the user or revert the registration. The sync can happen later. Only log the error.

3. **Token Timing**: Make sure to save the token BEFORE calling the sync endpoint, as it needs the Authorization header.

4. **Data Structure**: Ensure your local data format matches what the backend expects. Check `dataNormalizer.js` for the expected structure.

5. **Uncategorized Items**: The backend automatically handles the `uncategorizedItems` field via the `normalizeAndValidate()` function, so you don't need to manually add it.

---

## 📚 Related Files

- **Backend Sync Controller**: `src/controllers/syncController.js`
- **Backend Auth Controller**: `src/controllers/authController.js`
- **Data Normalizer**: `src/utils/dataNormalizer.js`
- **API Endpoints**: `API_ENDPOINTS.txt`

---

## 🚀 Quick Summary

**What you need to do:**

1. After successful registration, call `/api/sync/push` with `version: 0`
2. Include all locally stored data in the push request
3. Save the returned server version locally
4. The backend will create user data with your pushed content

**Key Points:**
- Backend already supports this ✅
- Use `version: 0` for first-time push
- Don't fail registration if sync fails
- Test thoroughly with the checklist above

---

**Questions?** Check the API_ENDPOINTS.txt file or contact the backend team.
