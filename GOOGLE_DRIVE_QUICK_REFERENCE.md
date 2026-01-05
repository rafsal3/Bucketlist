# Quick Reference: Google Drive Integration

## Key Changes Summary

### What Was Removed ❌
- Custom backend API (`sync_api_service.dart`)
- Email/password authentication
- Backend token management
- Automatic sync on app start
- Conflict resolution logic
- Server version tracking

### What Was Added ✅
- Google Sign-In authentication
- Google Drive backup/restore
- Simplified manual sync
- Secure credential storage
- AppDataFolder storage (hidden from user)

## New User Flows

### First Time User (Guest Mode)
```
1. Install app
2. Use app offline (no sign-in required)
3. All data stored locally in Hive
4. Optional: Sign in later to enable backup
```

### Sign In Flow
```
1. Settings → "Enable Cloud Sync"
2. Tap "Sign in with Google"
3. Select Google account
4. Grant permissions
5. Check for existing backup
6. Choose: Restore backup OR Keep local data
```

### Backup Flow
```
1. Make changes to bucket list
2. Tap cloud icon in app bar
3. Confirm "Backup to Google Drive?"
4. Data uploaded to Google Drive
5. Success message shown
```

### Restore Flow
```
1. Settings → "Restore Backup"
2. Warning: "This will replace local data"
3. Confirm restore
4. Data downloaded from Google Drive
5. Local database cleared and replaced
6. Success message shown
```

### Sign Out Flow
```
1. Settings → "Logout"
2. Confirm logout
3. Google account disconnected
4. Local data remains intact
5. Backup/restore disabled until sign-in
```

## API Reference

### GoogleDriveService

```dart
// Authentication
await googleDriveService.signIn();
await googleDriveService.signOut();
bool isSignedIn = await googleDriveService.isSignedIn();
String? email = await googleDriveService.getCurrentUserEmail();

// Backup/Restore
await googleDriveService.backupToGoogleDrive(data);
Map<String, dynamic>? data = await googleDriveService.restoreFromGoogleDrive();
bool hasBackup = await googleDriveService.hasBackup();
await googleDriveService.deleteBackup();
```

### AppState (Google Drive Version)

```dart
// Authentication
await appState.signInWithGoogle();
await appState.signOut();

// Backup/Restore
await appState.backupToGoogleDrive();
await appState.restoreFromGoogleDrive();
bool hasBackup = await appState.hasBackupOnGoogleDrive();

// Manual Sync (calls backupToGoogleDrive internally)
await appState.manualSync();

// Getters
bool isLoggedIn = appState.isLoggedIn;
String? email = appState.userEmail;
SyncStatus status = appState.syncStatus;
```

## Data Structure

### Backup JSON Format
```json
{
  "spaces": [
    {
      "id": "personal_space",
      "name": "Personal",
      "icon": "👤",
      "categories": [...],
      "uncategorizedItems": [...]
    }
  ],
  "currentSpaceId": "personal_space",
  "themeColor": "blue",
  "isDarkMode": false,
  "lastModifiedAt": 1704484800000,
  "version": 1
}
```

### Storage Location
- **Platform:** Google Drive
- **Scope:** `drive.appdata` (hidden from user)
- **File:** `bucketlist_backup.json`
- **Format:** JSON
- **Visibility:** Not visible in Google Drive UI

## Configuration Files

### pubspec.yaml
```yaml
dependencies:
  google_sign_in: ^6.2.1
  googleapis: ^11.4.0
  googleapis_auth: ^1.4.1
  flutter_secure_storage: ^9.2.2
```

### Android
- `android/app/google-services.json` (from Firebase)
- `android/app/build.gradle` (add Google services plugin)

### iOS
- `ios/Runner/GoogleService-Info.plist` (from Firebase)
- `ios/Runner/Info.plist` (add URL scheme)

## Testing Checklist

### Manual Testing
- [ ] Sign in with Google works
- [ ] Backup creates file in Google Drive
- [ ] Restore retrieves correct data
- [ ] Sign out clears authentication
- [ ] Offline mode works without sign-in
- [ ] Multiple devices can restore same backup
- [ ] Error handling for network failures

### Edge Cases
- [ ] Sign in with no internet
- [ ] Backup with no internet
- [ ] Restore with no backup available
- [ ] Restore with corrupted backup
- [ ] Sign in on multiple devices
- [ ] Backup overwrite behavior

## Common Commands

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Run on device
flutter run

# Build release
flutter build apk --release
flutter build ios --release

# Check for issues
flutter doctor
flutter analyze

# View logs
flutter logs
```

## Troubleshooting

### Sign-In Issues
```
Problem: "Sign-in failed"
Solution: 
1. Check SHA-1 fingerprint
2. Verify OAuth consent screen
3. Wait 5-10 minutes after credential creation
4. Try different Google account
```

### Backup Issues
```
Problem: "Backup failed"
Solution:
1. Check internet connection
2. Verify Google Drive API is enabled
3. Check OAuth scopes include drive.appdata
4. Try signing out and signing in again
```

### Restore Issues
```
Problem: "No backup found"
Solution:
1. Verify backup was created successfully
2. Check using same Google account
3. Verify Google Drive API permissions
4. Try creating new backup first
```

## Migration from Old Backend

### For Developers
1. Remove old backend URL configuration
2. Delete `sync_api_service.dart` (or keep as backup)
3. Update all imports from `CloudSyncScreen` to `GoogleSignInScreen`
4. Test authentication flow thoroughly
5. Verify backup/restore functionality

### For Users
1. No automatic migration
2. Local data is preserved
3. Sign in with Google when ready
4. Create first backup manually
5. Old backend data not accessible

## Security Notes

### What's Secure ✅
- OAuth 2.0 authentication
- Credentials in secure storage
- Data in user's personal Drive
- AppDataFolder (app-specific)
- No third-party servers

### What's Not Encrypted ⚠️
- Backup data (stored as plain JSON)
- Local Hive database (not encrypted)

### Recommendations
- Use device lock screen
- Enable 2FA on Google account
- Review Google account permissions regularly
- Sign out on shared devices

## Performance

### Backup Time
- Small dataset (< 100 items): < 1 second
- Medium dataset (100-1000 items): 1-3 seconds
- Large dataset (> 1000 items): 3-10 seconds

### Restore Time
- Similar to backup time
- Depends on internet speed
- Includes local database clear and rebuild

### Storage Usage
- Typical backup: 10-100 KB
- Google Drive quota: 15 GB free
- Negligible impact on quota

## Support & Resources

- **Setup Guide:** `GOOGLE_DRIVE_SETUP.md`
- **Migration Guide:** `GOOGLE_DRIVE_MIGRATION.md`
- **Google Sign-In Docs:** https://pub.dev/packages/google_sign_in
- **Google APIs Docs:** https://pub.dev/packages/googleapis
- **Firebase Console:** https://console.firebase.google.com/

---

**Last Updated:** January 2026
**Version:** 1.0.0
