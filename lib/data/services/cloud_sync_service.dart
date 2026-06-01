/// Abstract interface for cloud sync / backup.
///
/// The production implementation (Firebase / Supabase) is a Phase 3 feature.
/// This no-op stub lets the rest of the app compile and wire up cleanly today.
abstract class ICloudSyncService {
  /// True if the service is configured and a user is authenticated.
  bool get isAvailable;

  /// Push local bookmark + settings snapshot to the cloud.
  Future<void> push();

  /// Pull and merge the latest cloud snapshot into local storage.
  Future<void> pull();

  /// Signs the user out and revokes cloud access.
  Future<void> signOut();
}

/// No-op implementation shipped until a backend is chosen.
class NoOpCloudSyncService implements ICloudSyncService {
  const NoOpCloudSyncService();

  @override
  bool get isAvailable => false;

  @override
  Future<void> push() async {}

  @override
  Future<void> pull() async {}

  @override
  Future<void> signOut() async {}
}
