/// Provides a fire-and-forget helper for cache-first repositories.
///
/// Repositories that follow the cache-first pattern (return cached data
/// immediately, then refresh silently in the background) should mix this
/// in to avoid duplicating the try/catch wrapper.
mixin CacheFirstMixin {
  /// Runs [refresh] in the background, swallowing any errors.
  /// Cached data remains valid even when the refresh fails.
  Future<void> refreshSilently(Future<void> Function() refresh) async {
    try {
      await refresh();
    } catch (_) {
      // Cached data is still valid; ignore.
    }
  }
}
