# Google Drive Setup Guide

## Prerequisites
- Flutter project
- Google account
- Firebase project (recommended)

## Step-by-Step Setup

### 1. Firebase Console Setup

#### Create Firebase Project:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name (e.g., "Bucket List App")
4. Follow the setup wizard

### 2. Google Cloud Console Setup

#### Enable Google Drive API:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Navigate to "APIs & Services" → "Library"
4. Search for "Google Drive API"
5. Click "Enable"

#### Configure OAuth Consent Screen:
1. Go to "APIs & Services" → "OAuth consent screen"
2. Select "External" user type
3. Fill in required fields:
   - App name: "Bucket List"
   - User support email: Your email
   - Developer contact: Your email
4. Add scopes:
   - `https://www.googleapis.com/auth/drive.appdata`
   - `email`
5. Save and continue

### 3. Android Configuration

#### Add Android App to Firebase:
1. In Firebase Console, click "Add app" → Android
2. Enter package name (from `android/app/build.gradle`)
   - Example: `com.example.flutter_application_1`
3. Download `google-services.json`
4. Place file in `android/app/` directory

#### Update android/build.gradle:
```gradle
buildscript {
    dependencies {
        // Add this line
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```

#### Update android/app/build.gradle:
```gradle
// Add at the bottom of the file
apply plugin: 'com.google.gms.google-services'

android {
    defaultConfig {
        // Ensure minSdkVersion is at least 21
        minSdkVersion 21
    }
}
```

#### Create OAuth 2.0 Client ID (Android):
1. Go to Google Cloud Console → "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth 2.0 Client ID"
3. Select "Android"
4. Enter package name
5. Get SHA-1 certificate fingerprint:
   ```bash
   # Debug certificate
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   
   # Release certificate (when ready)
   keytool -list -v -keystore /path/to/your/keystore.jks -alias your-key-alias
   ```
6. Paste SHA-1 fingerprint
7. Click "Create"

### 4. iOS Configuration

#### Add iOS App to Firebase:
1. In Firebase Console, click "Add app" → iOS
2. Enter bundle ID (from `ios/Runner.xcodeproj`)
   - Example: `com.example.flutterApplication1`
3. Download `GoogleService-Info.plist`
4. Open `ios/Runner.xcworkspace` in Xcode
5. Drag `GoogleService-Info.plist` into `Runner` folder
6. Ensure "Copy items if needed" is checked

#### Update ios/Runner/Info.plist:
Add the following inside `<dict>`:
```xml
<!-- Google Sign-In URL Scheme -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Replace with your REVERSED_CLIENT_ID from GoogleService-Info.plist -->
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
        </array>
    </dict>
</array>
```

To find `REVERSED_CLIENT_ID`:
1. Open `GoogleService-Info.plist`
2. Find `REVERSED_CLIENT_ID` key
3. Copy the value
4. Paste in the URL scheme above

#### Create OAuth 2.0 Client ID (iOS):
1. Go to Google Cloud Console → "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth 2.0 Client ID"
3. Select "iOS"
4. Enter bundle ID
5. Click "Create"

### 5. Web Configuration (Optional)

#### Create OAuth 2.0 Client ID (Web):
1. Go to Google Cloud Console → "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth 2.0 Client ID"
3. Select "Web application"
4. Add authorized JavaScript origins:
   - `http://localhost:3000` (for development)
   - Your production URL
5. Add authorized redirect URIs:
   - `http://localhost:3000/auth/callback`
   - Your production callback URL
6. Click "Create"
7. Copy the Client ID

#### Update web/index.html:
Add before `</head>`:
```html
<meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
```

### 6. Verify Setup

#### Check Files Exist:
- ✅ `android/app/google-services.json`
- ✅ `ios/Runner/GoogleService-Info.plist`
- ✅ `pubspec.yaml` has Google packages

#### Test Commands:
```bash
# Clean and get dependencies
flutter clean
flutter pub get

# Run on Android
flutter run -d android

# Run on iOS
flutter run -d ios
```

### 7. Testing Google Sign-In

1. Run the app
2. Navigate to Settings
3. Tap "Enable Cloud Sync"
4. Tap "Sign in with Google"
5. Select Google account
6. Grant permissions
7. Verify sign-in successful

### 8. Testing Backup/Restore

#### Test Backup:
1. Sign in with Google
2. Add some items to your bucket list
3. Tap cloud icon in app bar
4. Confirm backup
5. Verify success message

#### Test Restore:
1. Delete some items locally
2. Go to Settings → "Restore Backup"
3. Confirm restore
4. Verify items are restored

#### Verify in Google Drive:
1. Go to [Google Drive](https://drive.google.com/)
2. You won't see the file (it's in appDataFolder)
3. To verify programmatically, use Google Drive API Explorer

### 9. Common Issues & Solutions

#### Issue: "Sign-in failed"
**Solution:**
- Verify SHA-1 fingerprint is correct
- Check package name matches
- Ensure OAuth consent screen is configured
- Wait 5-10 minutes after creating credentials

#### Issue: "API not enabled"
**Solution:**
- Enable Google Drive API in Cloud Console
- Enable Google Sign-In in Firebase Console

#### Issue: "Invalid client ID"
**Solution:**
- Verify `google-services.json` is in correct location
- Check `GoogleService-Info.plist` is added to Xcode project
- Ensure bundle ID matches

#### Issue: "Permission denied"
**Solution:**
- Check OAuth scopes include `drive.appdata`
- Verify user granted permissions
- Try signing out and signing in again

### 10. Production Checklist

Before releasing to production:

- [ ] Create release OAuth 2.0 credentials
- [ ] Update SHA-1 with release keystore fingerprint
- [ ] Configure OAuth consent screen for production
- [ ] Test on physical devices
- [ ] Test backup/restore flow
- [ ] Verify error handling
- [ ] Add privacy policy URL
- [ ] Add terms of service URL
- [ ] Submit OAuth consent screen for verification (if needed)

### 11. Security Best Practices

1. **Never commit credentials:**
   - Add `google-services.json` to `.gitignore`
   - Add `GoogleService-Info.plist` to `.gitignore`

2. **Use different projects for dev/prod:**
   - Development Firebase project
   - Production Firebase project

3. **Restrict API keys:**
   - Set application restrictions
   - Set API restrictions
   - Limit to specific APIs

4. **Monitor usage:**
   - Check Google Cloud Console for unusual activity
   - Set up billing alerts
   - Review OAuth consent screen regularly

## Additional Resources

- [Google Sign-In Flutter Plugin](https://pub.dev/packages/google_sign_in)
- [Google APIs Flutter Plugin](https://pub.dev/packages/googleapis)
- [Firebase Console](https://console.firebase.google.com/)
- [Google Cloud Console](https://console.cloud.google.com/)
- [OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)

## Support

If you encounter issues:
1. Check the [troubleshooting section](#9-common-issues--solutions)
2. Review Firebase and Google Cloud Console logs
3. Check Flutter and plugin documentation
4. Search for similar issues on GitHub/Stack Overflow

---

**Note:** This setup is required only once per project. After initial configuration, the app will work seamlessly across all devices.
