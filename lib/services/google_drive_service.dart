import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Google Drive Service for authentication and backup/restore
/// Replaces the custom backend with Google Drive integration
class GoogleDriveService {
  // Google Sign-In configuration with Drive scope
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope, // Access to app-specific folder
      'email',
    ],
  );

  // Secure storage for credentials
  static const _storage = FlutterSecureStorage();
  static const String _backupFileName = 'bucketlist_backup.json';

  /// Check if user is currently signed in
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// Get current signed-in user email
  Future<String?> getCurrentUserEmail() async {
    final account = await _googleSignIn.signInSilently();
    return account?.email;
  }

  /// Sign in with Google
  /// Returns user email on success, null on failure
  Future<String?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return null; // User cancelled sign-in
      }

      // Store user email securely
      await _storage.write(key: 'user_email', value: account.email);

      return account.email;
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  /// Sign out from Google
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _storage.delete(key: 'user_email');
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  /// Get authenticated Drive API client
  Future<drive.DriveApi> _getDriveApi() async {
    final account = _googleSignIn.currentUser;
    if (account == null) {
      throw Exception('User not signed in');
    }

    final authHeaders = await account.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    return drive.DriveApi(authenticateClient);
  }

  /// Backup data to Google Drive
  /// Stores data in appDataFolder (hidden from user's main Drive)
  /// Returns true on success
  Future<bool> backupToGoogleDrive(Map<String, dynamic> data) async {
    try {
      final driveApi = await _getDriveApi();

      // Check if backup file already exists
      final existingFile = await _findBackupFile(driveApi);

      // Prepare file metadata
      final fileMetadata = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder'];

      // Convert data to JSON
      final jsonData = jsonEncode(data);
      final mediaStream = Stream.value(utf8.encode(jsonData));
      final media = drive.Media(mediaStream, jsonData.length);

      if (existingFile != null) {
        // Update existing file
        await driveApi.files.update(
          fileMetadata,
          existingFile.id!,
          uploadMedia: media,
        );
      } else {
        // Create new file
        await driveApi.files.create(
          fileMetadata,
          uploadMedia: media,
        );
      }

      return true;
    } catch (e) {
      throw Exception('Backup to Google Drive failed: $e');
    }
  }

  /// Restore data from Google Drive
  /// Returns the backup data if found, null if no backup exists
  Future<Map<String, dynamic>?> restoreFromGoogleDrive() async {
    try {
      final driveApi = await _getDriveApi();

      // Find backup file
      final backupFile = await _findBackupFile(driveApi);
      if (backupFile == null) {
        return null; // No backup found
      }

      // Download file content
      final drive.Media? fileContent = await driveApi.files.get(
        backupFile.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media?;

      if (fileContent == null) {
        return null;
      }

      // Read and parse JSON
      final List<int> dataStore = [];
      await for (var data in fileContent.stream) {
        dataStore.addAll(data);
      }

      final jsonString = utf8.decode(dataStore);
      final Map<String, dynamic> backupData = jsonDecode(jsonString);

      return backupData;
    } catch (e) {
      throw Exception('Restore from Google Drive failed: $e');
    }
  }

  /// Check if backup exists on Google Drive
  Future<bool> hasBackup() async {
    try {
      final driveApi = await _getDriveApi();
      final backupFile = await _findBackupFile(driveApi);
      return backupFile != null;
    } catch (e) {
      return false;
    }
  }

  /// Find backup file in appDataFolder
  Future<drive.File?> _findBackupFile(drive.DriveApi driveApi) async {
    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Delete backup from Google Drive
  Future<bool> deleteBackup() async {
    try {
      final driveApi = await _getDriveApi();
      final backupFile = await _findBackupFile(driveApi);

      if (backupFile != null) {
        await driveApi.files.delete(backupFile.id!);
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Delete backup failed: $e');
    }
  }
}

/// Custom HTTP client for Google API authentication
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}
