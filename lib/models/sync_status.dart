/// Sync status enum for tracking synchronization state
/// This is UI-only and not persisted with bucket list data
enum SyncStatus {
  /// Data exists only locally, not yet synced to backend
  localOnly,

  /// Currently syncing with backend
  syncing,

  /// Successfully synced with backend
  synced,

  /// Sync error occurred
  error
}

/// Extension to provide human-readable labels for sync status
extension SyncStatusExtension on SyncStatus {
  String get label {
    switch (this) {
      case SyncStatus.localOnly:
        return 'Local Only';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.error:
        return 'Sync Error';
    }
  }

  /// Returns true if sync is in progress
  bool get isSyncing => this == SyncStatus.syncing;

  /// Returns true if data is synced
  bool get isSynced => this == SyncStatus.synced;

  /// Returns true if there's an error
  bool get hasError => this == SyncStatus.error;

  /// Returns true if data is only local
  bool get isLocalOnly => this == SyncStatus.localOnly;
}
