import '../key_generator/key_generator.dart';
import 'error_handler/cache_error_handler_registry.dart';
import 'manager/cache_manager_registry.dart';
import 'resolver/cache_resolver_registry.dart';
import 'storage/cache_storage_registry.dart';
import 'storage/configurable_cache_storage.dart';

/// {@template jet_cache_configurer}
/// Contract for JetLeaf cache configuration contributors.
///
/// The [CacheConfigurer] interface allows framework extensions, modules, or
/// application-level components to **programmatically register, modify, or
/// replace cache infrastructure components** during system initialization.
///
/// These configuration hooks are invoked automatically by JetLeaf’s
/// dependency injection lifecycle, typically during [SmartInitializingSingleton]
/// callbacks or at startup of the [CacheAutoConfiguration] subsystem.
///
/// ### Overview
///
/// Implementations of this interface provide centralized points for customizing
/// JetLeaf’s cache behavior — without the need for manual wiring or hardcoded
/// bindings. This includes:
///
/// - Adding or overriding [CacheManager] instances (e.g., Redis, in-memory, hybrid)
/// - Registering [CacheResolver]s for annotation-driven cache resolution
/// - Providing [KeyGenerator]s for cache key derivation
/// - Registering [CacheStorage] backends
///
/// Each configuration method receives a specialized registry that exposes
/// an additive, fluent-style API for component registration.
///
/// ### Example
///
/// ```dart
/// @Service()
/// final class CustomCacheConfigurer implements CacheConfigurer {
///   @override
///   void configure(CacheRegistry registry) {
///     // Optional: Global setup or metrics registration
///   }
///
///   @override
///   void configureCacheResolver(CacheResolverRegistry registry) {
///     registry.addResolver(SimpleCacheResolver(MyCacheManager()));
///   }
///
///   @override
///   void configureCacheManager(CacheManagerRegistry registry) {
///     registry.addManager(SimpleInMemoryCacheManager());
///   }
///
///   @override
///   void configureKeyGenerator(KeyGeneratorRegistry registry) {
///     registry.addKeyGenerator(DefaultKeyGenerator());
///   }
///
///   @override
///   void configureCacheStorage(CacheStorageRegistry registry) {
///     registry.addStorage(InMemoryCacheStorage('default'));
///   }
/// 
///   @override
///   void configureCache(String name, ConfigurableCacheStorage storage) {
///     if (name == 'users') {
///       storage
///         ..setEvictionPolicy(LruEvictionPolicy())
///         ..setDefaultTtl(Duration(minutes: 30))
///         ..setMaxEntries(500);
///     }
///   }
/// }
/// ```
///
/// ### Related Components
///
/// - [CacheResolverRegistry] — Registers and chains cache resolvers.
/// - [CacheManagerRegistry] — Manages sources of cache instances.
/// - [KeyGeneratorRegistry] — Determines cache key generation strategy.
/// - [CacheStorageRegistry] — Manages underlying cache stores.
/// - [CacheErrorHandlerRegistry] — Top-level composite registry passed during initialization.
///
/// {@endtemplate}
abstract class CacheConfigurer {
  /// Called during cache subsystem initialization to allow custom
  /// registration of cache-related components.
  ///
  /// Implementations should use the provided [registry] to add or
  /// replace cache managers, resolvers, key generators, or error handlers.
  void configureErrorHandler(CacheErrorHandlerRegistry registry) {}

  /// Registers and configures cache resolvers.
  ///
  /// Called after JetLeaf auto-discovers [CacheResolver] pods but before
  /// resolution chains are finalized. Implementations may use this hook to
  /// register additional resolvers or override existing ones.
  void configureCacheResolver(CacheResolverRegistry registry) {}

  /// Registers and configures cache managers.
  ///
  /// This method is typically used to integrate different cache management
  /// strategies, such as distributed caching or hybrid caching layers.
  void configureCacheManager(CacheManagerRegistry registry) {}

  /// Registers and configures cache key generators.
  ///
  /// This allows the system to control how cache keys are derived from
  /// method invocations or custom annotations.
  void configureKeyGenerator(KeyGeneratorRegistry registry) {}

  /// Registers and configures cache storages.
  ///
  /// Each storage corresponds to a physical or logical cache backend (e.g.,
  /// in-memory, Redis, file-based). Multiple storages may be registered
  /// under different cache managers.
  void configureCacheStorage(CacheStorageRegistry registry) {}

  /// Configures a [ConfigurableCacheStorage] instance conditionally by name.
  ///
  /// Implementations should use this method to customize the behavior of
  /// a specific cache identified by its logical name. The method will be
  /// called for every discovered cache during initialization — and the
  /// implementation decides whether to apply configuration.
  ///
  /// This enables fine-grained control over individual caches without
  /// modifying the global configuration.
  ///
  /// Example:
  /// ```dart
  /// void configure(String name, ConfigurableCacheStorage storage) {
  ///   if (name == 'sessions') {
  ///     storage
  ///       ..setEvictionPolicy(FifoEvictionPolicy())
  ///       ..setDefaultTtl(Duration(hours: 1))
  ///       ..setMaxEntries(2000);
  ///   }
  /// }
  /// ```
  void configure(String name, ConfigurableCacheStorage storage) {}
}