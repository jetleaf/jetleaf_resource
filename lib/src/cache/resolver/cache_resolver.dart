import 'dart:async';

import 'package:jetleaf_core/intercept.dart';

import '../annotations.dart';
import '../storage/cache_storage.dart';

/// {@template jetleaf_cache_resolver}
/// Strategy interface for resolving one or more [CacheStorage] instances
/// associated with a particular [Cacheable] operation.
///
/// A [CacheResolver] is responsible for determining which caches should
/// participate in a given cache operation (e.g., `@Cacheable`, `@CachePut`,
/// `@CacheEvict`). Implementations can apply a wide range of strategies —
/// from simple name-based lookups to dynamic, context-aware cache routing.
///
/// ### Overview
/// The [CacheResolver] abstraction allows the JetLeaf caching framework
/// to remain decoupled from the underlying cache resolution logic.
/// Instead of binding directly to a single [CacheManager], JetLeaf can
/// delegate the resolution process to one or more resolvers that determine
/// appropriate cache instances based on annotations, environment, or runtime
/// conditions.
///
/// ### Typical Implementations
/// - **[DefaultCacheResolver]** — resolves caches by name from a
///   registered [CacheManager].
/// - **TenantCacheResolver** — routes caches dynamically per tenant.
/// - **CompositeCacheResolver** — aggregates multiple resolvers using
///   a chain-of-responsibility model (see [_CacheResolverChain]).
/// - **DynamicExpressionResolver** — evaluates expressions or conditions
///   to determine target caches at runtime.
///
/// ### Example
/// ```dart
/// class CustomCacheResolver implements CacheResolver {
///   final CacheManager manager;
///
///   CustomCacheResolver(this.manager);
///
///   @override
///   FutureOr<Iterable<Cache>> resolveCaches(Cacheable cacheable) async {
///     final caches = <Cache>[];
///     for (final name in cacheable.cacheNames) {
///       final cache = await manager.getCache('${AppEnv.prefix}::$name');
///       if (cache != null) caches.add(cache);
///     }
///     return caches;
///   }
/// }
/// ```
///
/// ### Resolution Behavior
/// - Implementations must **never return null**; return an empty collection
///   if no caches are resolved.
/// - Implementations may **cache resolved instances** for performance,
///   but must handle invalidation appropriately if the cache topology changes.
/// - The framework may invoke `resolveCaches()` multiple times for different
///   cache operations, so resolution should be efficient and idempotent.
///
/// ### Thread Safety
/// Implementations **must be thread-safe** if used in multi-isolate or
/// concurrent environments.
///
/// ### Error Handling
/// - Throwing an exception will typically abort the resolution process.
/// - When used in composite structures like [_CacheResolverChain],
///   individual resolver errors are ignored to preserve fault tolerance.
///
/// ### See Also
/// - [Cacheable]
/// - [CacheManager]
/// - [CacheStorage]
/// - [_CacheResolverChain]
///
/// {@endtemplate}
abstract interface class CacheResolver {
  /// Resolves the [CacheStorage] instances to be used for a given [Cacheable] operation.
  ///
  /// The returned collection represents all caches that will participate
  /// in the caching operation (read, write, or eviction). If no caches are
  /// applicable, return an empty collection.
  ///
  /// Implementations may inspect any metadata available in the
  /// [Cacheable] annotation, including `cacheNames`, `keyGenerator`,
  /// or `cacheManager`, to decide which caches to target.
  ///
  /// @param cacheable The [Cacheable] metadata defining the cache operation.
  /// @return A collection of resolved [CacheStorage] instances.
  FutureOr<Iterable<CacheStorage>> resolveCaches(Cacheable cacheable, MethodInvocation invocation);
}