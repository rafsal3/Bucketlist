import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sync_models.dart';
import 'device_manager.dart';

/// Service for handling offline-first sync operations
class SyncService {
  static const String baseUrl = 'http://localhost:5000/api/v1';
  String? _authToken;

  void setToken(String? token) {
    _authToken = token;
  }

  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      final data = json.decode(response.body);
      return data['data'];
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Request failed');
    }
  }

  /// Push local changes to server
  Future<Map<String, dynamic>> pushChanges(SyncChanges changes) async {
    final deviceId = await DeviceManager.instance.getDeviceId();
    final lastSyncAt = await DeviceManager.instance.getLastSyncAt();

    final request = PushRequest(
      deviceId: deviceId,
      lastSyncAt: lastSyncAt,
      changes: changes,
    );

    final response = await http.post(
      Uri.parse('$baseUrl/sync/push'),
      headers: _getHeaders(),
      body: json.encode(request.toJson()),
    );

    final data = _handleResponse(response);

    // Update last sync timestamp
    if (data['serverTime'] != null) {
      await DeviceManager.instance.updateLastSyncAt(
        DateTime.parse(data['serverTime'] as String),
      );
    }

    return data as Map<String, dynamic>;
  }

  /// Pull changes from server
  Future<PullResponse> pullChanges({bool fullSync = false}) async {
    final deviceId = await DeviceManager.instance.getDeviceId();
    DateTime? lastSyncAt;

    if (!fullSync) {
      lastSyncAt = await DeviceManager.instance.getLastSyncAt();
    }

    final uri = Uri.parse('$baseUrl/sync/pull').replace(
      queryParameters: {
        'deviceId': deviceId,
        if (lastSyncAt != null) 'lastSyncAt': lastSyncAt.toIso8601String(),
      },
    );

    final response = await http.get(
      uri,
      headers: _getHeaders(),
    );

    final data = _handleResponse(response);
    final pullResponse = PullResponse.fromJson(data as Map<String, dynamic>);

    // Update last sync timestamp
    await DeviceManager.instance.updateLastSyncAt(pullResponse.serverTime);

    return pullResponse;
  }

  /// Create backup of all data
  Future<Map<String, dynamic>> createBackup() async {
    final response = await http.post(
      Uri.parse('$baseUrl/sync/backup'),
      headers: _getHeaders(),
    );

    return _handleResponse(response) as Map<String, dynamic>;
  }

  /// Restore from backup
  Future<Map<String, dynamic>> restoreBackup(
      Map<String, dynamic> backupData) async {
    final deviceId = await DeviceManager.instance.getDeviceId();

    final response = await http.post(
      Uri.parse('$baseUrl/sync/restore'),
      headers: _getHeaders(),
      body: json.encode({
        'deviceId': deviceId,
        'backupData': backupData,
      }),
    );

    final data = _handleResponse(response);

    // Clear local sync state after restore
    await DeviceManager.instance.clearSyncData();

    return data as Map<String, dynamic>;
  }

  /// Perform full sync (pull then push)
  Future<Map<String, dynamic>> performSync({
    SyncChanges? localChanges,
    bool fullSync = false,
  }) async {
    try {
      // First pull changes from server
      final pullResponse = await pullChanges(fullSync: fullSync);

      // If we have local changes, push them
      Map<String, dynamic>? pushResult;
      if (localChanges != null && !localChanges.isEmpty) {
        pushResult = await pushChanges(localChanges);
      }

      return {
        'success': true,
        'pulled': pullResponse.changes,
        'pushed': pushResult,
        'conflicts': pullResponse.conflicts,
        'serverTime': pullResponse.serverTime.toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
