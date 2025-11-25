import 'cache_event.dart';

/// {@template cache_miss_event}
/// Event published when a cache lookup fails to find a value.
///
/// This event indicates that a cache lookup operation did not return a
/// stored value, and the underlying method or data source will likely
/// need to be invoked to compute or retrieve the value. Observers can
/// use this event to track cache miss rates, monitor performance,
/// or trigger logging and metrics collection.
///
/// ## Core Properties
///
/// - [source]: The key of the cache entry that was looked up.
/// - [cacheName]: The name of the cache where the lookup occurred.
/// - [timestamp]: Optional timestamp of when the event occurred.
///
/// ## Usage Example
///
/// ```dart
/// void onCacheMiss(CacheMissEvent event) {
///   print('Cache miss for key ${event.source} in cache ${event.cacheName}');
/// }
/// ```
///
/// Observers can use this information to:
/// - Track cache efficiency (hit/miss ratios).
/// - Identify frequently missed keys for potential preloading.
/// - Monitor performance of cache-backed operations.
/// {@endtemplate}
final class CacheMissEvent extends CacheEvent {
  /// Creates a new cache miss event.
  ///
  /// [source] is the key that was looked up in the cache.
  /// [cacheName] is the name of the cache where the miss occurred.
  /// [timestamp] optionally overrides the default event timestamp.
  /// 
  /// {@macro cache_miss_event}
  const CacheMissEvent(super.source, super.cacheName, [super.timestamp]);

  @override
  String toString() => 'CacheMissEvent(cache: $cacheName, key: ${getSource()})';
}