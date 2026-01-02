/// Sync-related models for offline-first architecture
class SyncMetadata {
  final String deviceId;
  final DateTime? lastSyncAt;

  SyncMetadata({
    required this.deviceId,
    this.lastSyncAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'lastSyncAt': lastSyncAt?.toIso8601String(),
    };
  }

  factory SyncMetadata.fromJson(Map<String, dynamic> json) {
    return SyncMetadata(
      deviceId: json['deviceId'] as String,
      lastSyncAt: json['lastSyncAt'] != null
          ? DateTime.parse(json['lastSyncAt'] as String)
          : null,
    );
  }
}

class SyncChanges {
  final List<Map<String, dynamic>> spaces;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? preferences;

  SyncChanges({
    this.spaces = const [],
    this.categories = const [],
    this.items = const [],
    this.preferences,
  });

  Map<String, dynamic> toJson() {
    return {
      'spaces': spaces,
      'categories': categories,
      'items': items,
      'preferences': preferences,
    };
  }

  factory SyncChanges.fromJson(Map<String, dynamic> json) {
    return SyncChanges(
      spaces: (json['spaces'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      preferences: json['preferences'] as Map<String, dynamic>?,
    );
  }

  bool get isEmpty =>
      spaces.isEmpty &&
      categories.isEmpty &&
      items.isEmpty &&
      preferences == null;
}

class PushRequest {
  final String deviceId;
  final DateTime? lastSyncAt;
  final SyncChanges changes;

  PushRequest({
    required this.deviceId,
    this.lastSyncAt,
    required this.changes,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      if (lastSyncAt != null) 'lastSyncAt': lastSyncAt!.toIso8601String(),
      'changes': changes.toJson(),
    };
  }
}

class PullResponse {
  final SyncChanges changes;
  final DateTime serverTime;
  final List<ConflictInfo> conflicts;

  PullResponse({
    required this.changes,
    required this.serverTime,
    this.conflicts = const [],
  });

  factory PullResponse.fromJson(Map<String, dynamic> json) {
    return PullResponse(
      changes: SyncChanges.fromJson(json['changes'] as Map<String, dynamic>),
      serverTime: DateTime.parse(json['serverTime'] as String),
      conflicts: (json['conflicts'] as List<dynamic>?)
              ?.map((e) => ConflictInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ConflictInfo {
  final String type; // 'space', 'category', 'item'
  final String id;
  final String reason;
  final Map<String, dynamic> serverVersion;
  final Map<String, dynamic> clientVersion;

  ConflictInfo({
    required this.type,
    required this.id,
    required this.reason,
    required this.serverVersion,
    required this.clientVersion,
  });

  factory ConflictInfo.fromJson(Map<String, dynamic> json) {
    return ConflictInfo(
      type: json['type'] as String,
      id: json['id'] as String,
      reason: json['reason'] as String,
      serverVersion: json['serverVersion'] as Map<String, dynamic>,
      clientVersion: json['clientVersion'] as Map<String, dynamic>,
    );
  }
}
