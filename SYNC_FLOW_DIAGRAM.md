# Offline-First Sync Flow Diagram

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐  │
│  │   UI Layer   │      │  Providers   │      │    Models    │  │
│  │              │◄────►│              │◄────►│              │  │
│  │  - Screens   │      │  - AppState  │      │  - Space     │  │
│  │  - Widgets   │      │  - Sync      │      │  - Category  │  │
│  └──────────────┘      └──────┬───────┘      │  - Item      │  │
│                                │              └──────────────┘  │
│                                ▼                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Sync Services                            │ │
│  ├────────────────────────────────────────────────────────────┤ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │ │
│  │  │ SyncService  │  │ SyncHelper   │  │DeviceManager │    │ │
│  │  │              │  │              │  │              │    │ │
│  │  │ - push()     │  │ - create*()  │  │ - getDeviceId│    │ │
│  │  │ - pull()     │  │ - merge()    │  │ - lastSync   │    │ │
│  │  │ - backup()   │  │ - filter()   │  │              │    │ │
│  │  └──────┬───────┘  └──────────────┘  └──────────────┘    │ │
│  └─────────┼────────────────────────────────────────────────┘ │
│            │                                                    │
└────────────┼────────────────────────────────────────────────────┘
             │
             │ HTTP (JSON)
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Backend Server                                │
│                  (localhost:5000/api/v1)                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Sync Endpoints                               │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  POST /sync/push    - Receive client changes             │  │
│  │  GET  /sync/pull    - Send server changes                │  │
│  │  POST /sync/backup  - Create full backup                 │  │
│  │  POST /sync/restore - Restore from backup                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │          Conflict Resolution (Last-Write-Wins)            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   MongoDB Database                        │  │
│  │  - Spaces Collection                                      │  │
│  │  - Categories Collection                                  │  │
│  │  - Items Collection                                       │  │
│  │  - Users Collection                                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Sync Flow Sequence

### 1. Initial Sync (First Time)

```
User                 App                 SyncService         Backend
 │                    │                      │                  │
 │─── Login ─────────►│                      │                  │
 │                    │                      │                  │
 │                    │─── setToken() ──────►│                  │
 │                    │                      │                  │
 │                    │─── pullChanges() ───►│                  │
 │                    │    (fullSync=true)   │                  │
 │                    │                      │                  │
 │                    │                      │─── GET /pull ───►│
 │                    │                      │   ?deviceId=xxx  │
 │                    │                      │                  │
 │                    │                      │◄── All Data ─────│
 │                    │                      │   {spaces:[...]} │
 │                    │                      │                  │
 │                    │◄── PullResponse ────│                  │
 │                    │                      │                  │
 │◄── Show Data ─────│                      │                  │
 │                    │                      │                  │
```

### 2. Creating New Data

```
User                 App                 SyncHelper          SyncService         Backend
 │                    │                      │                  │                  │
 │─── Add Space ────►│                      │                  │                  │
 │                    │                      │                  │                  │
 │                    │─── createSpace() ───►│                  │                  │
 │                    │                      │                  │                  │
 │                    │◄── Space ────────────│                  │                  │
 │                    │   (with id, deviceId,│                  │                  │
 │                    │    timestamps, etc)  │                  │                  │
 │                    │                      │                  │                  │
 │◄── Update UI ─────│                      │                  │                  │
 │                    │                      │                  │                  │
 │                    │─── buildChanges() ───►                  │                  │
 │                    │                      │                  │                  │
 │                    │─── pushChanges() ────────────────────►│                  │
 │                    │                      │                  │                  │
 │                    │                      │                  │─── POST /push ──►│
 │                    │                      │                  │   {changes:{...}}│
 │                    │                      │                  │                  │
 │                    │                      │                  │◄── Success ─────│
 │                    │                      │                  │                  │
 │                    │◄── Success ──────────────────────────────                  │
 │                    │                      │                  │                  │
```

### 3. Periodic Sync

```
Timer                App                 SyncService         Backend
 │                    │                      │                  │
 │─── 5 min ─────────►│                      │                  │
 │                    │                      │                  │
 │                    │─── pullChanges() ───►│                  │
 │                    │   (lastSyncAt=...)   │                  │
 │                    │                      │                  │
 │                    │                      │─── GET /pull ───►│
 │                    │                      │   ?lastSyncAt=.. │
 │                    │                      │   &deviceId=...  │
 │                    │                      │                  │
 │                    │                      │◄── Changes ─────│
 │                    │                      │   (only new/mod) │
 │                    │                      │                  │
 │                    │◄── PullResponse ────│                  │
 │                    │                      │                  │
 │                    │─── mergeChanges() ──►│                  │
 │                    │                      │                  │
 │                    │─── updateUI() ───────►                  │
 │                    │                      │                  │
```

### 4. Conflict Resolution

```
Device A             Backend              Device B
 │                      │                    │
 │─── Edit Space ──────►│                    │
 │   (updatedAt: T1)    │                    │
 │                      │                    │
 │                      │◄── Edit Space ─────│
 │                      │   (updatedAt: T2)  │
 │                      │                    │
 │                      │─── Compare ────────►
 │                      │   T1 vs T2         │
 │                      │                    │
 │                      │   T2 > T1          │
 │                      │   Use Device B     │
 │                      │                    │
 │◄── Pull Changes ────│                    │
 │   (Device B wins)    │                    │
 │                      │                    │
 │─── Conflict Info ───►│                    │
 │   (notify user)      │                    │
 │                      │                    │
```

## Data Flow

### Entity Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                    Entity Creation                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  SyncHelper      │
                    │  .createSpace()  │
                    │                  │
                    │  Generates:      │
                    │  - id (UUID)     │
                    │  - deviceId      │
                    │  - userId        │
                    │  - createdAt     │
                    │  - updatedAt     │
                    │  - order         │
                    │  - deleted=false │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Local Storage   │
                    │  (In Memory)     │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  SyncService     │
                    │  .pushChanges()  │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Backend Server  │
                    │  (MongoDB)       │
                    └──────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Entity Update                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  Modify Entity   │
                    │  space.name = ..│
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  SyncHelper      │
                    │  .markAsUpdated()│
                    │                  │
                    │  Updates:        │
                    │  - updatedAt     │
                    │  - deviceId      │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  SyncService     │
                    │  .pushChanges()  │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Backend Server  │
                    │  (Merge LWW)     │
                    └──────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Entity Deletion                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  SyncHelper      │
                    │  .softDelete()   │
                    │                  │
                    │  Sets:           │
                    │  - deleted=true  │
                    │  - updatedAt     │
                    │  - deviceId      │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Filter Deleted  │
                    │  (UI Layer)      │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  SyncService     │
                    │  .pushChanges()  │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Backend Server  │
                    │  (Keeps Record)  │
                    └──────────────────┘
```

## Key Concepts

### 1. Last-Write-Wins (LWW)
```
if (server.updatedAt > local.updatedAt) {
    use server version
} else if (local.updatedAt > server.updatedAt) {
    use local version
} else {
    use server version (tie-breaker)
}
```

### 2. Soft Deletes
```
// Don't actually delete
deleted: true

// Filter when displaying
items.where((item) => !item.deleted)
```

### 3. Device Tracking
```
// Each device has unique ID
deviceId: "device_uuid_xxx"

// Track which device made last change
entity.deviceId = currentDeviceId
```

### 4. Timestamps
```
// Creation time (never changes)
createdAt: "2024-01-01T00:00:00.000Z"

// Last modification time (updates on every change)
updatedAt: "2024-01-02T10:30:00.000Z"
```

## State Management

```
┌─────────────────────────────────────────────────────────────┐
│                    App State Flow                            │
└─────────────────────────────────────────────────────────────┘

User Action
    │
    ▼
┌──────────────┐
│   UI Event   │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Provider    │  ◄─── State Management
│  (AppState)  │
└──────┬───────┘
       │
       ├─────► Local Update (Optimistic UI)
       │
       ▼
┌──────────────┐
│ SyncService  │  ◄─── Background Sync
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Backend    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Pull Changes │  ◄─── Periodic Sync
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Merge & UI   │  ◄─── Update UI
└──────────────┘
```

This diagram shows the complete flow of the offline-first sync architecture!
