import 'cache_event.dart';

/// {@template cache_put_event}
/// Event published when a value is stored in a cache.
///
/// This event indicates that a cache put operation has successfully
/// stored a value in the specified cache. Observers can use this event
/// to track cache writes, monitor TTL usage, or trigger logging and metrics collection.
///
/// ## Core Properties
///
/// - [source]: The key associated with the cached value.
/// - [cacheName]: The name of the cache where the value was stored.
/// - [value]: The object that was cached.
/// - [ttl]: Optional time-to-live duration applied to the cached entry.
/// - [timestamp]: Optional timestamp of when the event occurred.
///
/// ## Usage Example
///
/// ```dart
/// void onCachePut(CachePutEvent event) {
///   print('Stored value for key ${event.source} in cache ${event.cacheName} with TTL ${event.ttl}');
/// }
/// ```
///
/// Observers can use this information to:
/// - Track cache write operations and patterns.
/// - Monitor TTL usage for cache entries.
/// - Collect metrics or trigger actions based on cached values.
/// {@endtemplate}
final class CachePutEvent extends CacheEvent {
  /// The value that was stored in the cache.
  final Object? value;

  /// The TTL (time-to-live) applied to this cached entry, if any.
  final Duration? ttl;

  /// Creates a new cache put event.
  ///
  /// [source] is the cache key.
  /// [cacheName] is the name of the cache.
  /// [value] is the object stored in the cache.
  /// [ttl] optionally specifies the time-to-live for the entry.
  /// [timestamp] optionally overrides the event timestamp.
  /// 
  /// {@macro cache_put_event}
  const CachePutEvent(super.source, super.cacheName, [this.value, this.ttl, super.timestamp]);

  @override
  String toString() => 'CachePutEvent(cache: $cacheName, key: ${getSource()}, ttl: $ttl)';
}