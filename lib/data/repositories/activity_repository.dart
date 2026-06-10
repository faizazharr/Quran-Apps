import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────── Model ──────────────────────────────────────────

/// Snapshot of the user's last read and last listened timestamps.
class UserActivity extends Equatable {
  final DateTime? lastReadAt;
  final DateTime? lastListenedAt;

  const UserActivity({this.lastReadAt, this.lastListenedAt});

  bool get hasActivity => lastReadAt != null || lastListenedAt != null;

  @override
  List<Object?> get props => [lastReadAt, lastListenedAt];
}

// ─────────────────────────── Interface ──────────────────────────────────────

/// Contract for persisting last-read and last-listened timestamps.
abstract class IActivityRepository {
  Future<UserActivity> load();
  Future<void> saveLastRead(DateTime at);
  Future<void> saveLastListened(DateTime at);
}

// ─────────────────────────── Implementation ─────────────────────────────────

/// [SharedPreferences]-backed implementation.
///
/// Timestamps are stored as milliseconds-since-epoch integers so they survive
/// app restarts without needing any schema migration.
class ActivityRepositoryImpl implements IActivityRepository {
  static const _kLastReadMs = 'activity_last_read_ms';
  static const _kLastListenedMs = 'activity_last_listened_ms';

  @override
  Future<UserActivity> load() async {
    final prefs = await SharedPreferences.getInstance();
    final readMs = prefs.getInt(_kLastReadMs);
    final listenMs = prefs.getInt(_kLastListenedMs);
    return UserActivity(
      lastReadAt: readMs != null
          ? DateTime.fromMillisecondsSinceEpoch(readMs)
          : null,
      lastListenedAt: listenMs != null
          ? DateTime.fromMillisecondsSinceEpoch(listenMs)
          : null,
    );
  }

  @override
  Future<void> saveLastRead(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastReadMs, at.millisecondsSinceEpoch);
  }

  @override
  Future<void> saveLastListened(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastListenedMs, at.millisecondsSinceEpoch);
  }
}
