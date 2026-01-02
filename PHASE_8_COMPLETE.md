# ✅ PHASE 8: Final Safety Rules (DO NOT BREAK THESE)

## Summary
This document outlines the **CRITICAL ARCHITECTURAL RULES** that must NEVER be violated. These rules ensure data integrity, prevent conflicts, and maintain the offline-first nature of the application.

---

## ✔ Rule 1: Client Generates IDs

### Principle
**The client ALWAYS generates IDs for all entities (spaces, categories, items).**

### Implementation
```dart
// ✅ CORRECT - Client generates ID
final item = ChecklistItem(
  id: 'item_${DateTime.now().millisecondsSinceEpoch}',
  text: text,
  categoryId: categoryId,
);

// ❌ WRONG - Never let backend generate IDs
// Backend should NEVER modify or reassign IDs
```

### Why This Matters
- **Offline-first**: Works without internet
- **No conflicts**: Each device generates unique IDs
- **Immediate feedback**: No waiting for server response
- **Deterministic**: Client controls all IDs

### Verification
✅ All IDs use timestamp-based generation  
✅ IDs created before any network call  
✅ Backend stores IDs as-is, never modifies  

---

## ✔ Rule 2: Client Owns Order

### Principle
**The client ALWAYS controls the order of items, categories, and spaces.**

### Implementation
```dart
// ✅ CORRECT - Client manages order
void reorderItems(String categoryId, int oldIndex, int newIndex) {
  mutateData(() {
    final item = category.items.removeAt(oldIndex);
    category.items.insert(newIndex, item);
    // Order is determined by array position
  });
}

// ❌ WRONG - Never let backend reorder
// Backend should NEVER change array order
```

### Why This Matters
- **User control**: User decides order, not algorithm
- **Predictable**: Order stays as user set it
- **No conflicts**: Client is source of truth
- **Instant updates**: No server round-trip

### Verification
✅ Reorder methods modify local arrays  
✅ Backend receives ordered arrays  
✅ Pull restores exact order from backend  
✅ No server-side sorting or reordering  

---

## ✔ Rule 3: Client Owns Hidden/Done State

### Principle
**The client ALWAYS controls the `isHidden` and `isCompleted` states.**

### Implementation
```dart
// ✅ CORRECT - Client toggles state
void toggleItem(String itemId) {
  mutateData(() {
    item.isCompleted = !item.isCompleted;
    // Client decides state
  });
}

void toggleCategoryVisibility(String categoryId) {
  mutateData(() {
    category.isHidden = !category.isHidden;
    // Client controls visibility
  });
}

// ❌ WRONG - Never let backend modify state
// Backend should NEVER change isHidden or isCompleted
```

### Why This Matters
- **User intent**: State reflects user actions
- **No surprises**: State never changes unexpectedly
- **Offline support**: Works without connection
- **Immediate feedback**: Instant UI updates

### Verification
✅ Toggle methods modify local state  
✅ Backend stores state as-is  
✅ Pull restores exact state  
✅ No server-side state changes  

---

## ✔ Rule 4: Backend Never Modifies Data

### Principle
**The backend is a DUMB STORAGE. It NEVER modifies, transforms, or "improves" data.**

### Implementation
```dart
// Backend behavior (conceptual):
POST /sync/push
{
  "version": 5,
  "lastModifiedAt": 1735800000000,
  "data": { ... }
}

// ✅ Backend does:
// 1. Validate auth token
// 2. Store data EXACTLY as received
// 3. Increment version number
// 4. Return new version

// ❌ Backend NEVER does:
// - Modify IDs
// - Reorder arrays
// - Change state (isHidden, isCompleted)
// - Transform data structure
// - "Fix" or "normalize" data
// - Merge with existing data
```

### Why This Matters
- **Predictable**: What you push is what you get
- **No conflicts**: No server-side changes
- **Trust**: Client is source of truth
- **Simple**: Backend is just storage

### Verification
✅ Backend stores JSON as-is  
✅ No server-side transformations  
✅ No server-side business logic  
✅ Pull returns exact pushed data  

---

## ✔ Rule 5: Backend Stores Snapshots

### Principle
**The backend stores COMPLETE SNAPSHOTS, not deltas or diffs.**

### Implementation
```dart
// ✅ CORRECT - Full snapshot
POST /sync/push
{
  "version": 5,
  "data": {
    "spaces": [
      { "id": "space1", "name": "Personal", "categories": [...] },
      { "id": "space2", "name": "Work", "categories": [...] }
    ],
    "currentSpaceId": "space1",
    "themeColor": "blue",
    "isDarkMode": false
  }
}

// ❌ WRONG - Never send deltas
// {
//   "changes": [
//     { "op": "add", "path": "/spaces/0/categories/0/items/0" }
//   ]
// }
```

### Why This Matters
- **Simple**: No complex merge logic
- **Reliable**: Complete state always available
- **No corruption**: Can't have partial state
- **Easy recovery**: Full restore always possible

### Verification
✅ Push sends complete data structure  
✅ Backend stores entire snapshot  
✅ Pull returns complete snapshot  
✅ No delta/diff logic anywhere  

---

## ✔ Rule 6: Pull Happens Once Per Device

### Principle
**Pull from cloud ONLY happens ONCE when logging in on a new device with empty local DB.**

### Implementation
```dart
// ✅ CORRECT - Pull only if empty
Future<void> login(String email, String token) async {
  // Save auth state
  _isLoggedIn = true;
  _authToken = token;

  // Pull ONLY if local DB is empty
  if (_isLocalDatabaseEmpty()) {
    await _pullFromCloud();  // ✅ One-time pull
  } else {
    // ❌ NEVER pull if data exists
  }
}

bool _isLocalDatabaseEmpty() {
  return _spaces.isEmpty;
}
```

### Why This Matters
- **No overwrites**: Existing data never replaced
- **User control**: Local changes preserved
- **Predictable**: Data doesn't change unexpectedly
- **One-time**: Only on fresh device

### Verification
✅ Pull only when `_spaces.isEmpty`  
✅ No pull on app launch  
✅ No pull on app resume  
✅ No pull on network reconnect  
✅ No pull on re-login with existing data  

---

## Complete Data Flow

### Push Flow (Normal Operation):
```
User makes change
       ↓
Client generates ID (if new entity)
       ↓
Client updates local state
       ↓
Client saves to SharedPreferences
       ↓
Wait 2 seconds (debounce)
       ↓
Push COMPLETE SNAPSHOT to backend
       ↓
Backend stores EXACTLY as received
       ↓
Backend increments version
       ↓
Client receives new version
       ↓
Mark as synced ✅
```

### Pull Flow (New Device Only):
```
User logs in on new device
       ↓
Check: Is local DB empty?
       ↓ YES (new device)
Pull COMPLETE SNAPSHOT from backend
       ↓
Clear local DB (it's empty anyway)
       ↓
Insert remote data EXACTLY as received
       ↓
Save to SharedPreferences
       ↓
Mark as synced ✅

       ↓ NO (existing device)
Keep local data
       ↓
No pull ❌
       ↓
Continue normally
```

---

## Safety Checklist

### Before Every Change, Verify:

- [ ] **IDs**: Are IDs generated on client?
- [ ] **Order**: Is order controlled by client?
- [ ] **State**: Is state (hidden/done) controlled by client?
- [ ] **Backend**: Does backend just store data as-is?
- [ ] **Snapshots**: Are we sending complete snapshots?
- [ ] **Pull**: Does pull only happen on empty DB?

### Red Flags (NEVER DO THIS):

❌ Backend generates IDs  
❌ Backend reorders arrays  
❌ Backend modifies state  
❌ Backend "normalizes" data  
❌ Backend merges data  
❌ Sending deltas/diffs  
❌ Auto-pull on app launch  
❌ Auto-pull on network reconnect  
❌ Pull overwrites existing data  

---

## Architecture Principles

### 1. **Offline-First**
- App works without internet
- All operations local-first
- Sync is background enhancement

### 2. **Client is Source of Truth**
- Client controls all data
- Client generates all IDs
- Client decides all state

### 3. **Backend is Dumb Storage**
- Backend stores snapshots
- Backend never modifies data
- Backend is just a backup

### 4. **Push-Only (Mostly)**
- Push after every change
- Pull only on new device
- No automatic pulling

### 5. **Complete Snapshots**
- No deltas or diffs
- Full state always available
- Simple and reliable

### 6. **Never Lose Data**
- Local changes always saved
- Sync failures don't block user
- Automatic retry on failure

---

## Current Implementation Verification

### ✅ Rule 1: Client Generates IDs
```dart
// All entities use client-generated IDs
id: 'item_${DateTime.now().millisecondsSinceEpoch}'
id: 'category_${DateTime.now().millisecondsSinceEpoch}'
id: 'space_${DateTime.now().millisecondsSinceEpoch}'
```
**Status**: ✅ Verified

### ✅ Rule 2: Client Owns Order
```dart
// Reorder methods modify local arrays
void reorderItems(...) { mutateData(() { ... }); }
void reorderCategories(...) { mutateData(() { ... }); }
void reorderSpaces(...) { mutateData(() { ... }); }
```
**Status**: ✅ Verified

### ✅ Rule 3: Client Owns Hidden/Done State
```dart
// Toggle methods modify local state
void toggleItem(...) { mutateData(() { ... }); }
void toggleCategoryVisibility(...) { mutateData(() { ... }); }
void toggleSpaceVisibility(...) { mutateData(() { ... }); }
```
**Status**: ✅ Verified

### ✅ Rule 4: Backend Never Modifies Data
```dart
// Backend API just stores data
POST /sync/push { "data": { ... } }
// Backend returns data as-is
GET /sync/pull → { "data": { ... } }
```
**Status**: ✅ Verified (requires backend compliance)

### ✅ Rule 5: Backend Stores Snapshots
```dart
// Push sends complete snapshot
final data = {
  'spaces': _spaces.map((space) => space.toJson()).toList(),
  'currentSpaceId': _currentSpaceId,
  'themeColor': _themeColor,
  'isDarkMode': _isDarkMode,
};
```
**Status**: ✅ Verified

### ✅ Rule 6: Pull Happens Once Per Device
```dart
// Pull only if local DB is empty
if (_isLocalDatabaseEmpty()) {
  await _pullFromCloud();
}
```
**Status**: ✅ Verified

---

## Breaking These Rules = Disaster

### What Happens If You Break These Rules:

| Rule Broken | Consequence |
|-------------|-------------|
| **Backend generates IDs** | Conflicts, data loss, offline broken |
| **Backend reorders** | User's order lost, unpredictable UI |
| **Backend modifies state** | State changes unexpectedly, user confusion |
| **Backend transforms data** | Data corruption, sync failures |
| **Use deltas instead of snapshots** | Complex merge logic, bugs, data loss |
| **Auto-pull on launch** | Local changes overwritten, data loss |

---

## Future Considerations

If you ever need to add features, ensure they follow these rules:

### ✅ Safe to Add:
- Manual sync button (triggers push)
- Conflict resolution UI (client decides)
- Data export/import (client controls)
- Backup/restore (complete snapshots)

### ❌ Dangerous to Add:
- Server-side data transformation
- Automatic pull on app launch
- Delta/diff sync
- Server-side conflict resolution
- Backend-generated IDs

---

## Documentation

All phases have been documented:
- ✅ `PHASE_0_STEP_0.2_COMPLETE.md` - Global lastModifiedAt
- ✅ `PHASE_1_STEP_1.1_COMPLETE.md` - Sync status flags
- ✅ `PHASE_1_STEP_1.2_COMPLETE.md` - Unified mutation wrapper
- ✅ `PHASE_3_STEP_3.1_COMPLETE.md` - Cloud sync screen
- ✅ `PHASE_4_COMPLETE.md` - Push-only sync
- ✅ `PHASE_4_STEP_4.3_COMPLETE.md` - Never auto-pull
- ✅ `PHASE_5_COMPLETE.md` - New device login flow
- ✅ `PHASE_7_COMPLETE.md` - Error handling
- ✅ `PHASE_8_COMPLETE.md` - **This document**

---

## Final Reminder

### **THESE RULES ARE NOT OPTIONAL**

They are the foundation of the entire architecture. Breaking them will:
- Cause data loss
- Create conflicts
- Break offline functionality
- Confuse users
- Corrupt data

### **WHEN IN DOUBT:**
1. Client controls everything
2. Backend is dumb storage
3. Push complete snapshots
4. Pull only on empty DB
5. Never auto-pull
6. Never lose local data

---

**Status**: ✅ Complete  
**Phase**: PHASE 8  
**Type**: Architecture Rules  
**Importance**: **CRITICAL - DO NOT BREAK**
