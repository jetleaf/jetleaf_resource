import 'cache_event.dart';

/// {@template cache_expire_event}
/// Event published when a cache entry expires due to reaching its TTL (time-to-live).
///
/// This event indicates that a cached value was automatically invalidated
/// because it exceeded its defined lifespan. Observers can use this event
/// to track expiration behavior, logging, metrics collection, or
/// triggering dependent invalidations.
///
/// ## Core Properties
///
/// - [source]: The key of the cache entry that expired.
/// - [cacheName]: The name of the cache where the entry expired.
/// - [value]: The value of the entry that expired (if available).
/// - [ttl]: The time-to-live duration that caused the expiration.
/// - [timestamp]: Optional timestamp of when the event occurred.
///
/// ## Usage Example
///
/// ```dart
/// void onCacheExpire(CacheExpireEvent event) {
///   print('Cache entry ${event.source} in ${event.cacheName} expired after ${event.ttl}');
/// }
/// ```
///
/// Observers can use this information to:
/// - Track TTL-based cache expirations.
/// - Monitor cache usage patterns and TTL effectiveness.
/// - Trigger dependent actions when specific entries expire.
/// {@endtemplate}
final class CacheExpireEvent extends CacheEvent {
  /// The value of the cache entry that expired.
  final Object? value;

  /// The time-to-live (TTL) duration that caused the expiration.
  final Duration ttl;

  /// Creates a new cache expiration event.
  ///
  /// [source] is the cache key that expired.
  /// [cacheName] is the name of the cache.
  /// [ttl] is the TTL that triggered the expiration.
  /// [value] is the optional expired value.
  /// [timestamp] optionally overrides the event timestamp.
  /// 
  /// {@macro cache_expire_event}
  const CacheExpireEvent(super.source, super.cacheName, this.ttl, [this.value, super.timestamp]);

  @override
  String toString() => 'CacheExpireEvent(cache: $cacheName, key: ${getSource()}, ttl: $ttl)';
}