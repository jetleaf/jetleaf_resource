import 'cache_event.dart';

/// {@template cache_clear_event}
/// Event published when one or more entries in a cache are cleared.
///
/// This event indicates that cache entries have been removed either
/// manually or due to an administrative operation (e.g., `clear()` or
/// `clearAll()`). Observers can use this event to track cache usage,
/// logging, metrics, or trigger dependent actions when caches are cleared.
///
/// ## Core Properties
///
/// - [source]: The key that triggered the clear operation. For `clearAll`
///   operations, this may be a placeholder or null.
/// - [cacheName]: The name of the cache where the entries were cleared.
/// - [entriesCleared]: The number of cache entries that were removed.
/// - [timestamp]: Optional timestamp of when the event occurred.
///
/// ## Usage Example
///
/// ```dart
/// void onCacheClear(CacheClearEvent event) {
///   print('Cleared ${event.entriesCleared} entries from cache ${event.cacheName}');
/// }
/// ```
///
/// Observers can use this information to:
/// - Track cache size and usage over time.
/// - Detect bulk clear operations for auditing or monitoring.
/// - Trigger dependent cleanup or recalculation logic after cache clearance.
/// {@endtemplate}
final class CacheClearEvent extends CacheEvent {
  /// The number of cache entries that were cleared.
  final int entriesCleared;

  /// Creates a new cache clear event.
  ///
  /// [source] is the key or object that initiated the clear operation.
  /// [cacheName] is the name of the cache affected.
  /// [entriesCleared] is the count of entries removed from the cache.
  /// [timestamp] optionally overrides the event timestamp.
  /// 
  /// {@macro cache_clear_event}
  const CacheClearEvent(super.source, super.cacheName, this.entriesCleared, [super.timestamp]);

  @override
  String toString() => 'CacheClearEvent(cache: $cacheName, entriesCleared: $entriesCleared)';
}