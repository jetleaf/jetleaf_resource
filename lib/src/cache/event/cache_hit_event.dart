import 'cache_event.dart';

/// {@template cache_hit_event}
/// Event published when a cached value is successfully retrieved.
///
/// This event indicates that a cache lookup operation has succeeded and
/// returned a value without invoking the underlying method or data source.
/// Observers can use this event to track cache hit rates, monitor
/// performance, or trigger logging and metrics collection.
///
/// ## Core Properties
///
/// - [source]: The key of the cached entry that was accessed.
/// - [cacheName]: The name of the cache from which the value was retrieved.
/// - [value]: The actual value retrieved from the cache (may be `null` if
///   the cache stores `null` values explicitly).
/// - [timestamp]: Optional timestamp of the event occurrence.
///
/// ## Usage Example
///
/// ```dart
/// void onCacheHit(CacheHitEvent event) {
///   print('Cache hit for key ${event.source} in cache ${event.cacheName}');
///   print('Retrieved value: ${event.value}');
/// }
/// ```
///
/// Observers can use this information to implement:
/// - Cache hit/miss metrics.
/// - Conditional logging of frequently accessed keys.
/// - Performance monitoring or adaptive caching strategies.
/// {@endtemplate}
final class CacheHitEvent extends CacheEvent {
  /// The value that was retrieved from the cache.
  final Object? value;

  /// Creates a new cache hit event.
  ///
  /// [source] is the key of the cached entry.
  /// [cacheName] identifies the cache where the hit occurred.
  /// [value] is the retrieved value (may be `null`).
  /// [timestamp] optionally overrides the default event timestamp.
  /// 
  /// {@macro cache_hit_event}
  const CacheHitEvent(super.source, super.cacheName, [this.value, super.timestamp]);

  @override
  String toString() => 'CacheHitEvent(cache: $cacheName, key: ${getSource()}, value: $value)';
}