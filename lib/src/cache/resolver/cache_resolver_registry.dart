import 'cache_resolver.dart';

/// {@template jet_cache_resolver_registry}
/// A registry contract for managing multiple [CacheResolver] pods within JetLeaf.
///
/// The [CacheResolverRegistry] defines the mechanism for registering and
/// coordinating [CacheResolver] instances. These resolvers are responsible for
/// mapping a [Cacheable] annotation (logical cache operation) to one or more
/// physical [CacheStorage] instances managed by underlying [CacheManager] pods.
///
/// ### Responsibilities
///
/// - Acts as a central registry for all cache resolvers.
/// - Ensures resolvers can be added dynamically or during initialization.
/// - Serves as the delegation point for composite resolver chains, such as
///   [CompositeCacheResolver], to maintain deterministic lookup order.
///
/// ### Usage
///
/// A typical implementation (e.g., [CompositeCacheResolver]) will:
///
/// 1. Maintain a synchronized set of resolvers.
/// 2. Support lifecycle discovery via [PodFactoryAware] and [SmartInitializingSingleton].
/// 3. Provide resolution delegation through a resolver chain.
///
/// ### Example
///
/// ```dart
/// final registry = CompositeCacheResolver();
/// registry.addResolver(myCustomResolver);
/// ```
///
/// ### Related Components
///
/// - [CacheResolver]: Resolves [Cacheable] annotations to concrete [CacheStorage] instances.
/// - [CompositeCacheResolver]: A registry implementation that manages multiple resolvers.
/// - [CacheManager]: Provides physical cache storage for resolved caches.
/// {@endtemplate}
abstract interface class CacheResolverRegistry {
  /// Adds a [CacheResolver] pod to this registry.
  ///
  /// Each resolver is responsible for resolving a [Cacheable] annotation
  /// into one or more concrete [CacheStorage] instances. This allows logical
  /// cache definitions to be mapped to physical caches in a modular,
  /// extensible manner.
  void addResolver(CacheResolver cacheResolver);
}