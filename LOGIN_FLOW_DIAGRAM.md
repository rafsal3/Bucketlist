# Login Flow Diagram - Updated Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    EXISTING USER LOGIN FLOW                      │
└─────────────────────────────────────────────────────────────────┘

Step 1: User Action
┌──────────────────┐
│  User clicks     │
│  "Login" or      │
│  "Restore from   │
│  Cloud"          │
└────────┬─────────┘
         │
         ▼
Step 2: Authentication
┌──────────────────┐
│  Enter email &   │
│  password        │
│  Click "Login"   │
└────────┬─────────┘
         │
         ▼
Step 3: Login Success
┌──────────────────┐
│  ✅ Login        │
│  successful      │
│  (no auto-pull)  │
└────────┬─────────┘
         │
         ▼
Step 4: 🆕 IMMEDIATE RESTORE PROMPT (300ms delay)
┌─────────────────────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════════════════════╗  │
│  ║  🔽 Restore Backup?                                   ║  │
│  ╠═══════════════════════════════════════════════════════╣  │
│  ║                                                       ║  │
│  ║  Would you like to restore your data from the        ║  │
│  ║  cloud backup?                                       ║  │
│  ║                                                       ║  │
│  ║  ⚠️ This will replace your local data with the       ║  │
│  ║     backup                                           ║  │
│  ║                                                       ║  │
│  ║  ┌──────────────────┐  ┌──────────────────┐         ║  │
│  ║  │ Keep Local Data  │  │ Restore Backup   │         ║  │
│  ║  └──────────────────┘  └──────────────────┘         ║  │
│  ╚═══════════════════════════════════════════════════════╝  │
└─────────────────────────────────────────────────────────────┘
         │                              │
         │                              │
    Option A                       Option B
         │                              │
         ▼                              ▼
┌──────────────────┐          ┌──────────────────┐
│  Keep Local      │          │  Restore Backup  │
│  Data            │          │                  │
└────────┬─────────┘          └────────┬─────────┘
         │                              │
         ▼                              ▼
┌──────────────────┐          ┌──────────────────┐
│  ✅ Success:     │          │  Loading dialog: │
│  "Login          │          │  "Restoring      │
│  successful!     │          │  backup..."      │
│  Your local      │          └────────┬─────────┘
│  data is         │                   │
│  preserved."     │                   ▼
└──────────────────┘          ┌──────────────────┐
                              │  Download backup │
                              │  from server     │
                              └────────┬─────────┘
                                       │
                                       ▼
                              ┌──────────────────┐
                              │  Clear local DB  │
                              │  Apply server    │
                              │  data            │
                              └────────┬─────────┘
                                       │
                                       ▼
                              ┌──────────────────┐
                              │  ✅ Success:     │
                              │  "Backup         │
                              │  restored        │
                              │  successfully!"  │
                              └──────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         AFTER LOGIN                              │
└─────────────────────────────────────────────────────────────────┘

User is now logged in and can:
  • Make changes locally (auto-saved to Hive)
  • Click ☁️ icon to manually sync to cloud
  • Click ⋮ menu → "Restore Backup" (with warning)
  • Click ⋮ menu → "Logout"

┌─────────────────────────────────────────────────────────────────┐
│                    WHY THIS FLOW IS BETTER                       │
└─────────────────────────────────────────────────────────────────┘

✅ Prevents accidental data loss
   - User MUST choose between local and cloud data
   - No automatic overwrites

✅ Clear user intent
   - User knows exactly what will happen
   - Warning message explains consequences

✅ Flexible workflow
   - Keep local data if working offline
   - Restore backup if switching devices

✅ Safety first
   - Confirmation required for destructive actions
   - Loading states show progress
   - Success/error messages provide feedback

┌─────────────────────────────────────────────────────────────────┐
│                    COMPARISON WITH OLD MODEL                     │
└─────────────────────────────────────────────────────────────────┘

OLD MODEL ❌:
  Login → Auto-pull if DB empty → Data might be lost

NEW MODEL ✅:
  Login → User chooses → Keep local OR restore backup
  
Result: User is ALWAYS in control of their data!
```
