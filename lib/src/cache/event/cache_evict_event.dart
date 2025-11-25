import 'cache_event.dart';

/// {@template cache_evict_event}
/// Event published when an entry is removed (evicted) from a cache.
///
/// This event indicates that a cache eviction operation has occurred,
/// either due to explicit removal, TTL expiration, eviction policies,
/// or other cache management rules. Observers can use this event
/// to track cache invalidations, logging, or metrics collection.
///
/// ## Core Properties
///
/// - [source]: The key of the cache entry that was evicted.
/// - [cacheName]: The name of the cache from which the entry was evicted.
/// - [reason]: The reason for eviction, such as 'manual', 'policy', or 'ttl_expired'.
/// - [timestamp]: Optional timestamp of when the event occurred.
///
/// ## Usage Example
///
/// ```dart
/// void onCacheEvict(CacheEvictEvent event) {
///   print('Evicted key ${event.source} from cache ${event.cacheName} due to ${event.reason}');
/// }
/// ```
///
/// Observers can use this information to:
/// - Track cache eviction patterns.
/// - Monitor TTL or policy-driven evictions.
/// - Trigger logging, metrics collection, or dependent invalidations.
/// {@endtemplate}
final class CacheEvictEvent extends CacheEvent {
  /// The reason why the cache entry was evicted.
  ///
  /// Common examples include:
  /// - `'manual'` – explicitly removed by a user or operation.
  /// - `'policy'` – evicted due to a cache eviction policy.
  /// - `'ttl_expired'` – evicted because the time-to-live expired.
  final String reason;

  /// Creates a new cache evict event.
  ///
  /// [source] is the cache key being evicted.
  /// [cacheName] is the name of the cache.
  /// [reason] describes why the eviction occurred.
  /// [timestamp] optionally overrides the event timestamp.
  /// 
  /// {@macro cache_evict_event}
  const CacheEvictEvent(super.source, super.cacheName, this.reason, [super.timestamp]);

  @override
  String toString() => 'CacheEvictEvent(cache: $cacheName, key: ${getSource()}, reason: $reason)';
}