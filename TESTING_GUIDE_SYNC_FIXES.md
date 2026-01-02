# Testing Guide - Sync Fixes

## Quick Test Checklist

### ✅ Test 1: Existing User Login (CRITICAL)
**Purpose:** Verify local data is NOT lost on login

**Steps:**
1. ✅ Register new account
2. ✅ Add 5 items (any category)
3. ✅ Logout
4. ✅ Login again with same credentials
5. ✅ **VERIFY:** All 5 items are still there
6. ✅ **VERIFY:** No "Pulling from cloud" message in logs
7. ✅ **VERIFY:** See "Existing user login - preserving local data" in logs

**Expected Result:**
```
✅ Existing user login - preserving local data
🔄 Sync will happen automatically via debounced push
```

**If Failed:**
- ❌ Items disappeared → Bug not fixed
- ❌ Seeing "Pulling from cloud" → Bug not fixed

---

### ✅ Test 2: New Device Login
**Purpose:** Verify pull from cloud works on new device

**Steps:**
1. ✅ Register account and add items on Device A
2. ✅ Clear app data on Device B (or use different device)
3. ✅ Login on Device B with same credentials
4. ✅ **VERIFY:** Items from Device A appear on Device B
5. ✅ **VERIFY:** See "New device login detected, pulling from cloud" in logs

**Expected Result:**
```
📥 New device login detected, pulling from cloud...
🗑️ Local DB cleared
📥 Loaded X spaces from cloud
✅ Data applied successfully!
```

**If Failed:**
- ❌ Items not appearing → Pull not working
- ❌ Not seeing "New device login" → Logic not working

---

### ✅ Test 3: Rapid Item Addition
**Purpose:** Verify race condition fix works

**Steps:**
1. ✅ Login to account
2. ✅ Tap "Add Item" button 10 times RAPIDLY (as fast as possible)
3. ✅ Add 10 different items with different names
4. ✅ **VERIFY:** All 10 items appear in the list
5. ✅ **VERIFY:** Check logs for "Mutation in progress, queuing..." messages
6. ✅ Wait 5 seconds for sync
7. ✅ Logout and login again
8. ✅ **VERIFY:** All 10 items are still there

**Expected Result:**
```
⚠️ Mutation in progress, queuing... (may appear multiple times)
✅ All items saved
✅ All items synced
```

**If Failed:**
- ❌ Some items missing → Race condition not fixed
- ❌ Items not syncing → Sync not working

---

### ✅ Test 4: Registration with Offline Data
**Purpose:** Verify offline data is preserved during registration

**Steps:**
1. ✅ Fresh install (or clear app data)
2. ✅ Add 5 items while NOT logged in (offline mode)
3. ✅ Register new account
4. ✅ **VERIFY:** All 5 items are still visible
5. ✅ **VERIFY:** See "Found local data, pushing to server first" in logs
6. ✅ Logout
7. ✅ Login on different device
8. ✅ **VERIFY:** All 5 items appear on new device

**Expected Result:**
```
📤 Registration: Found local data, pushing to server first...
✅ Local data pushed successfully!
✅ Registration complete - local data preserved!
```

**If Failed:**
- ❌ Items disappeared after registration → Bug in registration flow
- ❌ Items not syncing to server → Push not working

---

### ✅ Test 5: Registration without Offline Data
**Purpose:** Verify pull works when registering with no local data

**Steps:**
1. ✅ Create account on Device A and add items
2. ✅ Fresh install on Device B
3. ✅ Register NEW account on Device B (different email)
4. ✅ **VERIFY:** No items appear (new account)
5. ✅ **VERIFY:** See "No local data, pulling from server" in logs

**Expected Result:**
```
📥 Registration: No local data, pulling from server...
```

---

### ✅ Test 6: App Startup (No Auto-Pull)
**Purpose:** Verify app NEVER pulls from cloud on startup

**Steps:**
1. ✅ Login and add items
2. ✅ Close app completely
3. ✅ Reopen app
4. ✅ **VERIFY:** Items appear immediately (from local storage)
5. ✅ **VERIFY:** NO "Pulling from cloud" message in logs
6. ✅ **VERIFY:** See local data loaded from SharedPreferences

**Expected Result:**
```
(No pull messages)
✅ App loads local data only
```

**If Failed:**
- ❌ Seeing "Pulling from cloud" on startup → Bug not fixed
- ❌ Items not appearing → Local storage issue

---

### ✅ Test 7: Conflict Resolution (409)
**Purpose:** Verify server wins on conflict

**Steps:**
1. ✅ Login on Device A
2. ✅ Add item "Item A" on Device A
3. ✅ Turn off internet on Device A
4. ✅ Login on Device B
5. ✅ Add item "Item B" on Device B
6. ✅ Turn on internet on Device A
7. ✅ Wait for sync on Device A
8. ✅ **VERIFY:** Device A shows "Item B" (server wins)
9. ✅ **VERIFY:** See "Conflict detected (409)" in logs

**Expected Result:**
```
⚠️ Conflict detected (409)! Server version: X
📥 Overwriting local data with server data...
✅ Data applied successfully!
```

---

### ✅ Test 8: Invalid Server Response
**Purpose:** Verify backup/rollback works

**Steps:**
1. ✅ Login and add items
2. ✅ Mock server to return invalid data (or disconnect server)
3. ✅ Trigger sync
4. ✅ **VERIFY:** Local items are still there
5. ✅ **VERIFY:** Error message shown
6. ✅ **VERIFY:** See "Restoring backup" in logs

**Expected Result:**
```
⚠️ Server data missing spaces, keeping local data
(or)
❌ Error applying sync data: ...
🔄 Restoring backup...
✅ Local data preserved
```

---

## Debug Log Patterns

### ✅ Good Patterns (Expected)

**Existing User Login:**
```
✅ Existing user login - preserving local data
🔄 Sync will happen automatically via debounced push
```

**New Device Login:**
```
📥 New device login detected, pulling from cloud...
🗑️ Local DB cleared
📥 Loaded X spaces from cloud
✅ Data applied successfully!
```

**Registration with Data:**
```
📤 Registration: Found local data, pushing to server first...
✅ Local data pushed successfully!
✅ Registration complete - local data preserved!
```

**Mutation Queuing:**
```
⚠️ Mutation in progress, queuing...
```

**Sync Success:**
```
✅ Sync successful! New version: X
```

---

### ❌ Bad Patterns (Bugs)

**Pull on Every Login (BUG - SHOULD BE FIXED):**
```
❌ 📥 Login successful, pulling from cloud...
```
If you see this for existing users → Bug NOT fixed!

**Race Condition (BUG - SHOULD BE FIXED):**
```
❌ No queuing messages but items missing
```
If items disappear with rapid addition → Bug NOT fixed!

**Data Loss on Sync:**
```
❌ 🗑️ Local DB cleared
❌ ⚠️ Server data missing spaces, keeping local data
(but data is already cleared)
```
If you see this → Validation not working!

---

## Quick Commands

### View Logs (Flutter)
```bash
flutter logs
```

### Clear App Data (Android)
```bash
adb shell pm clear com.example.flutter_application_1
```

### Clear App Data (iOS Simulator)
```bash
xcrun simctl uninstall booted com.example.flutterApplication1
```

### Rebuild and Run
```bash
flutter clean
flutter pub get
flutter run
```

---

## Expected Behavior Summary

| Action | Local DB State | Expected Behavior |
|--------|---------------|-------------------|
| **Login** | Empty | Pull from cloud ✅ |
| **Login** | Has Data | Preserve local, push sync ✅ |
| **Register** | Empty | Pull from cloud ✅ |
| **Register** | Has Data | Push to server ✅ |
| **Startup** | Any | Load local only ✅ |
| **Add Item** | Any | Save locally, queue sync ✅ |
| **Rapid Add** | Any | Queue mutations ✅ |
| **Conflict** | Any | Server wins ✅ |
| **Invalid Data** | Any | Rollback to backup ✅ |

---

## Common Issues and Solutions

### Issue: Items disappearing on login
**Cause:** Pull from cloud happening on every login
**Solution:** Check if fix was applied correctly
**Verify:** Look for "Existing user login - preserving local data" in logs

### Issue: Items lost when adding rapidly
**Cause:** Race condition in mutateData
**Solution:** Check if mutex was added correctly
**Verify:** Look for "Mutation in progress, queuing..." in logs

### Issue: Data lost after registration
**Cause:** Not pushing local data before pulling
**Solution:** Check registerWithLocalData logic
**Verify:** Look for "Found local data, pushing to server first" in logs

### Issue: App slow or unresponsive
**Cause:** Too many queued mutations
**Solution:** Check mutation queue size
**Verify:** Look for excessive queuing messages

---

## Success Criteria

All tests must pass with these results:

- ✅ Test 1: Local data preserved on login
- ✅ Test 2: Pull works on new device
- ✅ Test 3: All 10 rapid items saved
- ✅ Test 4: Offline data preserved on registration
- ✅ Test 5: Pull works on new registration
- ✅ Test 6: No auto-pull on startup
- ✅ Test 7: Conflict resolution works
- ✅ Test 8: Backup/rollback works

**If all tests pass → All bugs are fixed! 🎉**
