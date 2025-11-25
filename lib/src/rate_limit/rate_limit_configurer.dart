import 'manager/rate_limit_manager_registry.dart';
import 'resolver/rate_limit_resolver_registry.dart';
import 'storage/configurable_rate_limit_storage.dart';
import 'storage/rate_limit_storage_registry.dart';

/// {@template rate_limit_configurer}
/// Defines the programmatic configuration entry point for the rate-limiting subsystem.
///
/// The [RateLimitConfigurer] interface allows developers and framework integrators
/// to register and customize various components related to rate limiting—such as
/// storages, managers, resolvers, and error handlers—during the application
/// initialization or container bootstrap phase.
///
/// ### Purpose
///
/// Implementations of this interface act as extension hooks for configuring
/// the rate-limiting infrastructure dynamically, complementing declarative
/// configuration through annotations like [RateLimit].
///
/// It enables flexible integration with external systems (e.g., Redis, databases,
/// distributed caches) and supports environment-based conditional registration.
///
/// ### Lifecycle
///
/// - The framework automatically detects and executes all [RateLimitConfigurer]
///   implementations during the startup process.
/// - The order of execution may depend on whether the configurer implements
///   ordering interfaces such as [Ordered] or [PriorityOrdered].
/// - Each configuration method receives the relevant registry, allowing modular
///   registration of components.
///
/// ### Responsibilities
///
/// - Registering one or more [RateLimitManager] instances that coordinate
///   storage backends.
/// - Adding [RateLimitStorage] implementations to handle rate tracking logic.
/// - Registering [RateLimitResolver]s that determine which storage(s)
///   a given [RateLimit] annotation should use.
///
/// ### Example
///
/// ```dart
/// class MyRateLimitConfigurer extends RateLimitConfigurer, PriorityOrdered {
///   @override
///   void configureRateLimitManager(RateLimitManagerRegistry registry) {
///     registry.addManager(DefaultRateLimitManager('primary'));
///   }
///
///   @override
///   void configureRateLimitStorage(RateLimitStorageRegistry registry) {
///     registry.addStorage(InMemoryRateLimitStorage('local'));
///     registry.addStorage(RedisRateLimitStorage('redis-main'));
///   }
///
///   @override
///   void configureRateLimitResolver(RateLimitResolverRegistry registry) {
///     registry.addResolver(DefaultRateLimitResolver());
///   }
///
///   @override
///   int getOrder() => Ordered.HIGHEST_PRECEDENCE;
/// }
/// ```
///
/// In this example:
/// - A default manager and two storage backends are registered.
/// - A resolver is added to determine which storage should handle each operation.
/// - The configurer declares high precedence to ensure it runs before others.
///
/// ### Related Components
///
/// - [RateLimitManagerRegistry] — Registry for rate limit managers.
/// - [RateLimitStorageRegistry] — Registry for rate limit storage implementations.
/// - [RateLimitResolverRegistry] — Registry for resolver components.
/// - [RateLimitManager] — Central orchestrator for rate limit storage.
/// - [RateLimitResolver] — Responsible for resolving which storage(s) to use.
/// - [RateLimitErrorHandler] — Optional component for handling runtime exceptions.
///
/// {@endtemplate}
abstract class RateLimitConfigurer {
  /// Configures and registers one or more [RateLimitManager] instances.
  ///
  /// Implementations can use the provided [RateLimitManagerRegistry] to add
  /// or modify rate limit managers that orchestrate storage-level interactions.
  ///
  /// ### Parameters
  /// - [registry]: The registry used to add or configure [RateLimitManager] instances.
  ///
  /// ### Example
  /// ```dart
  /// registry.addManager(DefaultRateLimitManager('tenant-manager'));
  /// ```
  void configureRateLimitManager(RateLimitManagerRegistry registry) {}

  /// Configures and registers [RateLimitStorage] implementations.
  ///
  /// This method allows registration of custom or environment-specific
  /// rate limit storage providers—such as in-memory, Redis-based, or database-backed
  /// implementations—using the provided [RateLimitStorageRegistry].
  ///
  /// ### Parameters
  /// - [registry]: The registry used to register storage providers.
  ///
  /// ### Example
  /// ```dart
  /// registry.addStorage(InMemoryRateLimitStorage('local'));
  /// registry.addStorage(RedisRateLimitStorage('distributed'));
  /// ```
  void configureRateLimitStorage(RateLimitStorageRegistry registry) {}

  /// Configures and registers [RateLimitResolver] implementations.
  ///
  /// The resolver defines how the framework determines which [RateLimitStorage]
  /// instances apply to a given [RateLimit] annotation.
  ///
  /// Implementations may register multiple resolvers to support advanced scenarios,
  /// such as dynamic context-based routing or composite resolution strategies.
  ///
  /// ### Parameters
  /// - [registry]: The registry used to add resolver instances.
  ///
  /// ### Example
  /// ```dart
  /// registry.addResolver(DefaultRateLimitResolver());
  /// ```
  void configureRateLimitResolver(RateLimitResolverRegistry registry) {}

  /// Configures a [ConfigurableRateLimitStorage] instance conditionally by name.
  ///
  /// Implementations should use this method to customize the behavior of
  /// a specific rate-limit identified by its logical name. The method will be
  /// called for every discovered rate-limit during initialization — and the
  /// implementation decides whether to apply configuration.
  ///
  /// This enables fine-grained control over individual caches without
  /// modifying the global configuration.
  ///
  /// Example:
  /// ```dart
  /// void configure(String name, ConfigurableRateLimitStorage storage) {
  ///   if (name == 'sessions') {
  ///     storage
  ///       ..setZoneId("UTC");
  ///   }
  /// }
  /// ```
  void configure(String name, ConfigurableRateLimitStorage storage) {}
}