import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Manages device identification for offline-first sync
class DeviceManager {
  static const String _deviceIdKey = 'device_id';
  static const String _lastSyncKey = 'last_sync_at';

  static DeviceManager? _instance;
  static DeviceManager get instance {
    _instance ??= DeviceManager._();
    return _instance!;
  }

  DeviceManager._();

  String? _deviceId;
  DateTime? _lastSyncAt;

  /// Get or create device ID
  Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_deviceIdKey);

    if (_deviceId == null) {
      // Generate new device ID
      _deviceId = 'device_${const Uuid().v4()}';
      await prefs.setString(_deviceIdKey, _deviceId!);
    }

    return _deviceId!;
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncAt() async {
    if (_lastSyncAt != null) return _lastSyncAt;

    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_lastSyncKey);

    if (timestamp != null) {
      _lastSyncAt = DateTime.parse(timestamp);
    }

    return _lastSyncAt;
  }

  /// Update last sync timestamp
  Future<void> updateLastSyncAt(DateTime timestamp) async {
    _lastSyncAt = timestamp;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, timestamp.toIso8601String());
  }

  /// Clear sync data (for logout or reset)
  Future<void> clearSyncData() async {
    _lastSyncAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncKey);
  }

  /// Reset device ID (use with caution - will create sync conflicts)
  Future<void> resetDeviceId() async {
    _deviceId = null;
    _lastSyncAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    await prefs.remove(_lastSyncKey);
  }
}
