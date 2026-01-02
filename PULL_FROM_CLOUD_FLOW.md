# Pull from Cloud - Flow Diagram

## When Does Pull from Cloud Happen?

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER ACTIONS                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  User Action     │
                    └──────────────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
                ▼             ▼             ▼
        ┌───────────┐  ┌───────────┐  ┌──────────┐
        │  Login    │  │ Register  │  │ Startup  │
        └───────────┘  └───────────┘  └──────────┘
                │             │             │
                ▼             ▼             ▼
        ┌───────────────────────────────────────┐
        │  Check: Is Local DB Empty?            │
        └───────────────────────────────────────┘
                │
        ┌───────┴───────┐
        │               │
        ▼               ▼
    ┌─────┐         ┌─────┐
    │ YES │         │ NO  │
    └─────┘         └─────┘
        │               │
        │               │
        ▼               ▼
┌──────────────┐   ┌──────────────────┐
│ PULL FROM    │   │ PRESERVE LOCAL   │
│ CLOUD        │   │ DATA             │
└──────────────┘   └──────────────────┘
        │               │
        ▼               ▼
┌──────────────┐   ┌──────────────────┐
│ Replace      │   │ Trigger Push     │
│ Local Data   │   │ Sync (debounced) │
└──────────────┘   └──────────────────┘
```

---

## Detailed Flow Charts

### 1. Login Flow (FIXED)

```
┌─────────────────────────────────────────────────────────────────┐
│                         LOGIN FLOW                               │
└─────────────────────────────────────────────────────────────────┘

User enters email/password
         │
         ▼
API: POST /auth/login
         │
         ▼
Receive auth token
         │
         ▼
Save auth state locally
(isLoggedIn = true, token, email)
         │
         ▼
┌────────────────────────────┐
│ Is Local DB Empty?         │
│ (_spaces.isEmpty)          │
└────────────────────────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
  YES        NO
    │         │
    │         │
    ▼         ▼
┌────────┐  ┌──────────────────────────┐
│ PULL   │  │ PRESERVE LOCAL DATA      │
│ FROM   │  │                          │
│ CLOUD  │  │ ✅ Keep local changes    │
└────────┘  │ ✅ Trigger push sync     │
    │       │ ✅ No data loss          │
    │       └──────────────────────────┘
    │                 │
    ▼                 ▼
Replace          Push local
local data       changes to
with server      server
data             (debounced)
    │                 │
    └────────┬────────┘
             ▼
    ✅ Login Complete
```

**Key Points:**
- ✅ **NEW DEVICE**: Empty local DB → Pull from cloud
- ✅ **EXISTING USER**: Has local data → Preserve and push
- ❌ **NEVER**: Pull on every login (OLD BUG - FIXED!)

---

### 2. Registration Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      REGISTRATION FLOW                           │
└─────────────────────────────────────────────────────────────────┘

User enters email/password
         │
         ▼
API: POST /auth/register
         │
         ▼
Receive auth token
         │
         ▼
Save auth state locally
(isLoggedIn = true, token, email)
         │
         ▼
┌────────────────────────────┐
│ Has Local Data?            │
│ (_spaces.isNotEmpty)       │
└────────────────────────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
  YES        NO
    │         │
    │         │
    ▼         ▼
┌────────┐  ┌────────┐
│ PUSH   │  │ PULL   │
│ LOCAL  │  │ FROM   │
│ DATA   │  │ CLOUD  │
└────────┘  └────────┘
    │         │
    ▼         ▼
Push to    Get any
server     existing
first      server data
    │         │
    ▼         ▼
✅ Local   ✅ Server
data       data
preserved  loaded
    │         │
    └────┬────┘
         ▼
✅ Registration Complete
```

**Key Points:**
- ✅ **WITH LOCAL DATA**: Push to server first (preserve offline work)
- ✅ **WITHOUT LOCAL DATA**: Pull from server (get existing data)
- ✅ **NEVER LOSE**: Offline data during registration

---

### 3. App Startup Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                       APP STARTUP FLOW                           │
└─────────────────────────────────────────────────────────────────┘

App launches
     │
     ▼
Load from SharedPreferences:
- Spaces
- Categories
- Items
- Auth state
- Theme settings
     │
     ▼
┌──────────────────────────┐
│ Is User Logged In?       │
│ (isLoggedIn == true)     │
└──────────────────────────┘
     │
┌────┴────┐
│         │
▼         ▼
YES       NO
│         │
│         │
▼         ▼
┌──────────────┐  ┌──────────────┐
│ ❌ DO NOT    │  │ Show local   │
│ PULL FROM    │  │ data only    │
│ CLOUD        │  │              │
└──────────────┘  └──────────────┘
│                 │
│                 │
▼                 ▼
Show local       ✅ Offline mode
data and         
enable sync      
(debounced)      
│                 │
└────────┬────────┘
         ▼
    ✅ App Ready
```

**Key Points:**
- ❌ **NEVER PULL**: On app startup
- ✅ **ALWAYS LOAD**: Local data from SharedPreferences
- ✅ **ENABLE SYNC**: If logged in (push-only, debounced)

---

## Summary Table

| Scenario | Local DB State | Action | Pull from Cloud? |
|----------|---------------|--------|------------------|
| **Login - New Device** | Empty | Pull from cloud | ✅ YES |
| **Login - Existing User** | Has Data | Preserve local, push sync | ❌ NO |
| **Register - With Offline Data** | Has Data | Push to server first | ❌ NO |
| **Register - No Offline Data** | Empty | Pull from cloud | ✅ YES |
| **App Startup - Logged In** | Any | Load local only | ❌ NO |
| **App Startup - Not Logged In** | Any | Load local only | ❌ NO |
| **Manual Sync** | Any | Push to server | ❌ NO |
| **Conflict (409)** | Any | Server wins, pull | ✅ YES |

---

## Code Reference

### Check for Empty Local DB
```dart
bool _isLocalDatabaseEmpty() {
  return _spaces.isEmpty;
}
```

### Login Logic (FIXED)
```dart
Future<void> login(String email, String token) async {
  // ... save auth state ...
  
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

### Registration Logic
```dart
Future<void> registerWithLocalData(String email, String token) async {
  // ... save auth state ...
  
  // Check if there's any local data to push
  final hasLocalData = _spaces.isNotEmpty;

  if (hasLocalData) {
    // Push local data first
    await _pushToCloud();
  } else {
    // Pull from server
    await _pullFromCloud();
  }
}
```

---

## Before vs After

### ❌ BEFORE (BUGGY)
```dart
Future<void> login(String email, String token) async {
  // ... save auth state ...
  
  // ❌ ALWAYS Pull from cloud on login
  await _pullFromCloud(); // BUG: Overwrites local data!
}
```

**Problems:**
- Existing users lose local changes on every login
- Unnecessary network calls
- Poor offline experience

### ✅ AFTER (FIXED)
```dart
Future<void> login(String email, String token) async {
  // ... save auth state ...
  
  // ✅ ONLY Pull from cloud if local DB is empty
  if (_isLocalDatabaseEmpty()) {
    await _pullFromCloud();
  } else {
    _markSyncPending(); // Push local changes
  }
}
```

**Benefits:**
- ✅ Preserves local data for existing users
- ✅ Only pulls on new device login
- ✅ Automatic push sync for local changes
- ✅ Better offline experience
