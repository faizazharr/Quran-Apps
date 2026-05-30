/// Base class for all application-specific exceptions.
sealed class AppException implements Exception {
  final String message;
  const AppException(this.message);

  /// Short user-facing copy. Subclasses override for context.
  String get userMessage => message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a remote source (network/API) fails.
class RemoteException extends AppException {
  const RemoteException(super.message);

  @override
  String get userMessage =>
      'We could not reach the server. Please try again in a moment.';
}

/// Thrown when the device is offline and no cached data exists.
class OfflineException extends AppException {
  const OfflineException([super.message = 'No internet connection.']);

  @override
  String get userMessage =>
      'You are offline. Connect to the internet to download the catalog.';
}

/// Thrown when a local source (database/cache) fails.
class LocalException extends AppException {
  const LocalException(super.message);

  @override
  String get userMessage => 'Local storage error. Please restart the app.';
}

/// Thrown when no data is available from any source.
class NoDataException extends AppException {
  const NoDataException(super.message);

  @override
  String get userMessage => 'No data available right now.';
}

/// Thrown when audio playback fails.
class PlaybackException extends AppException {
  const PlaybackException(super.message);

  @override
  String get userMessage => 'Playback failed. Please try another track.';
}

/// Fallback when nothing else matched.
class UnknownException extends AppException {
  const UnknownException(super.message);

  @override
  String get userMessage => 'Something went wrong. Please try again.';
}
