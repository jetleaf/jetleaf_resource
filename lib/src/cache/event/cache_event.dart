import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_lang/lang.dart';

/// {@template cache_event}
/// Base class representing an event related to a cache operation.
///
/// This abstract interface class serves as the foundation for all cache-related
/// events within the Jetleaf caching system. A cache event encapsulates
/// contextual information about an operation performed on a specific cache,
/// such as additions, updates, evictions, or expirations.
///
/// Cache events can be published via the application’s event system
/// ([ApplicationEventPublisher]) to enable observers or listeners to react
/// to cache lifecycle changes. For example, you might use this mechanism to:
///
/// - Log cache access or mutation events.
/// - Trigger cache monitoring metrics.
/// - Synchronize distributed caches or propagate invalidation signals.
/// - Audit access to sensitive cached data.
///
/// ## Core Properties
///
/// - [source]: Typically the key of the cache entry involved in this event.
/// - [cacheName]: The name of the cache where the event occurred.
/// - [timestamp]: Optional event timestamp. Defaults to the current time
///   if not provided by the caller.
///
/// ## Usage Example
///
/// ```dart
/// class UserCacheEvictEvent extends CacheEvent {
///   const UserCacheEvictEvent(String key)
///       : super(key, 'userCache');
/// }
///
/// void onCacheEvict(CacheEvent event) {
///   print('Evicted key ${event.source} from cache ${event.cacheName}');
/// }
/// ```
///
/// ## Extending CacheEvent
///
/// Subclasses of [CacheEvent] should represent **specific cache operations**
/// such as:
///
/// - [CachePutEvent]: A value was added or updated in the cache.
/// - [CacheEvictEvent]: A value was removed from the cache.
/// - [CacheClearEvent]: All values in the cache were cleared.
///
/// Each subclass may extend the interface properties with additional metadata
/// relevant to the specific operation (e.g., cached value, TTL, access count).
/// {@endtemplate}
abstract class CacheEvent extends ApplicationEvent {
  /// The name of the cache where this event occurred.
  ///
  /// This identifies the logical cache container (as registered in
  /// the cache manager) affected by the event.
  final String cacheName;

  /// Creates a new cache event.
  ///
  /// [source] is typically the key of the cached entry involved in this event.
  /// [cacheName] identifies the cache where the operation occurred.
  /// [timestamp] optionally overrides the default event timestamp.
  /// 
  /// {@macro cache_event}
  const CacheEvent(super.source, this.cacheName, [super.timestamp]);

  @override
  String getPackageName() => PackageNames.RESOURCE;
}