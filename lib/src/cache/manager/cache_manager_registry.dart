import 'cache_manager.dart';

/// {@template jet_cache_manager_registry}
/// A registry contract for managing multiple [CacheManager] pods within JetLeaf.
///
/// The [CacheManagerRegistry] defines the mechanism for registering and
/// coordinating [CacheManager] instances. Each manager represents a distinct
/// source of caches — for example, in-memory, distributed, or Redis-backed
/// caches.
///
/// ### Responsibilities
///
/// - Acts as a central registry for all cache manager pods.
/// - Supports multiple managers, which can be combined in a composite or
///   chained structure for unified cache access.
/// - Ensures deterministic registration order and safe concurrent updates.
///
/// ### Usage
///
/// A typical implementation (e.g., [CompositeCacheManager]) will:
///
/// 1. Maintain a synchronized set of registered cache managers.
/// 2. Provide unified access and delegation to underlying managers.
/// 3. Support lifecycle integration via [PodFactoryAware] and
///    [SmartInitializingSingleton].
///
/// ### Example
///
/// ```dart
/// final registry = CompositeCacheManager();
/// registry.addManager(SimpleInMemoryCacheManager());
/// registry.addManager(RedisCacheManager());
/// ```
///
/// ### Related Components
///
/// - [CacheManager]: Represents physical or logical cache stores.
/// - [CompositeCacheManager]: A registry implementation that aggregates multiple managers.
/// - [CacheResolver]: Resolves [Cacheable] annotations to caches provided by managers.
/// {@endtemplate}
abstract interface class CacheManagerRegistry {
  /// Registers a [CacheManager] pod with this registry.
  ///
  /// Each manager provides one or more caches. Multiple managers can be
  /// combined in a composite or chained structure to enable unified
  /// cache operations across heterogeneous backends.
  void addManager(CacheManager cacheManager);
}