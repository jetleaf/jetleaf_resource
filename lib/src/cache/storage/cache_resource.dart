import 'package:jetleaf_lang/lang.dart';

import '../../base/resource.dart';
import '../../base/when_matching.dart';
import 'cache.dart';

/// {@template concurrent_map_cache_resource}
/// A concurrent in-memory cache resource based on [HashMap], implementing
/// the [Resource] interface.
///
/// The [CacheResource] serves as the foundational in-memory
/// storage layer for JetLeaf’s caching subsystem. It maintains a thread-safe
/// mapping between keys and [Cache] instances, typically managed by
/// [CacheManager] implementations.
///
/// While it extends [HashMap], it is conceptually treated as a lightweight,
/// low-latency storage abstraction rather than a general-purpose collection.
/// The resource is ideal for small to medium-scale cache layers that require
/// predictable access times and thread-safety under concurrent read/write load.
///
/// ### Behavior
///
/// - Each entry maps an arbitrary object key to a [Cache] instance.
/// - Provides efficient `O(1)` average lookup and insertion times.
/// - Serves as a resource within JetLeaf’s cache infrastructure, often
///   referenced by higher-level managers or interceptors.
/// - Can be combined with external [CacheStorage] or [CacheManager]
///   implementations for hybrid or layered caching.
///
/// ### Example
///
/// ```dart
/// final resource = CacheResource();
///
/// // Add a cache instance
/// resource['users'] = SimpleCache('users');
///
/// // Retrieve and use the cache
/// final userCache = resource['users'];
/// userCache?.put('id:123', User('Alice'));
///
/// // Iterate through all caches
/// for (final entry in resource.entries) {
///   print('Cache ${entry.key}: ${entry.value.getSize()} entries');
/// }
/// ```
///
/// ### Thread Safety
///
/// Although [HashMap] itself is not inherently concurrent, JetLeaf’s
/// [CacheResource] is typically used within synchronized
/// regions or managed contexts to ensure atomic access. Implementations
/// should avoid performing non-atomic mutations concurrently unless
/// explicitly wrapped by synchronization primitives.
///
/// ### Related Components
///
/// - [Resource] – The abstract interface defining the resource contract.
/// - [Cache] – Represents the logical cache unit stored in this map.
/// - [CacheManager] – Higher-level coordinator that utilizes this resource.
/// - [DefaultCacheStorage] – A concrete cache storage built on this resource.
/// {@endtemplate}
final class CacheResource extends HashMap<Object, Cache> implements Resource {
  @override
  bool exists(Object key) => this[key] != null;

  @override
  bool matches(WhenMatching match, Object key) => false;
}