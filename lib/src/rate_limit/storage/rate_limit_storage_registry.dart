import 'dart:async';

import 'rate_limit_storage.dart';

/// {@template rate_limit_storage_registry}
/// Central registry for managing [RateLimitStorage] instances.
///
/// The [RateLimitStorageRegistry] serves as the lifecycle container
/// for all rate limit storage implementations available within
/// the current runtime or application context.
///
/// ### Purpose
///
/// It provides registration and discovery capabilities for various
/// [RateLimitStorage] backends such as in-memory, Redis, or database-based
/// implementations.  
/// Storages registered here become accessible to higher-level components like
/// [RateLimitManager] or [RateLimiter], allowing dynamic composition of
/// rate-limiting strategies.
///
/// ### Typical Use Cases
///
/// - Registering a new storage during application startup.
/// - Managing multiple storage types (e.g., hybrid memory + distributed).
/// - Allowing plug-in modules to contribute additional storage providers.
///
/// ### Example
/// ```dart
/// final registry = DefaultRateLimitStorageRegistry();
/// registry.addStorage(InMemoryRateLimitStorage('local'));
///
/// final storage = registry.getStorage('local');
/// final allowed = await storage?.tryConsume('user:42',
///   limit: 10, window: Duration(minutes: 1));
/// ```
///
/// ### Related Components
/// - [RateLimitStorage] – The individual storage implementations.
/// - [RateLimitManager] – Manages and orchestrates all registered storages.
/// - [RateLimitResolver] – Resolves which storages to apply for a given annotation.
/// {@endtemplate}
abstract interface class RateLimitStorageRegistry {
  /// Registers a new [RateLimitStorage] instance into the registry.
  ///
  /// Once added, the storage becomes available for resolution
  /// through the [RateLimitManager] or related resolvers.
  ///
  /// ### Parameters
  /// - [storage]: The rate limit storage to be registered.
  ///
  /// ### Behavior
  /// - Duplicate registrations for the same name may override
  ///   the previous entry depending on the implementation.
  /// - Implementations may enforce thread-safe access if shared
  ///   across multiple isolates or async contexts.
  ///
  /// ### Example
  /// ```dart
  /// registry.addStorage(RedisRateLimitStorage('redis-primary'));
  /// ```
  void addStorage(RateLimitStorage storage);

  /// Registers a user-provided factory used to dynamically create
  /// a new [RateLimitStorage] when a requested storage name does not
  /// already exist in the registry.
  ///
  /// ### Purpose
  ///
  /// Allows applications, plug-ins, or extensions to contribute custom
  /// logic for resolving missing storages on demand.  
  /// Instead of relying solely on built-in fallback behavior
  /// (e.g., auto-creating in-memory storages), developers can supply
  /// tailored creation rules based on:
  ///
  /// - Naming conventions
  /// - Environment profiles
  /// - External configuration sources
  /// - Multi-tenant or dynamic runtime requirements
  ///
  /// ### Behavior
  ///
  /// - Creators are invoked *only* when:
  ///   1. No manager reports a matching storage, and  
  ///   2. No registered storage has the requested name.  
  ///
  /// - Creators are executed in the order they were registered.
  /// - The first creator that returns a non-null [RateLimitStorage]
  ///   produces the storage used for the operation.
  /// - The created storage is automatically registered via [addStorage].
  /// - If the storage implements lifecycle interfaces (e.g., [ApplicationContextAware],
  ///   [InitializingPod]), the registry will invoke them appropriately.
  ///
  /// ### Example
  /// ```dart
  /// registry.addCreator((name) async {
  ///   if (name.startsWith('tenant:')) {
  ///     return await TenantRateLimitStorage.loadFor(name);
  ///   }
  ///   return null;
  /// });
  /// ```
  ///
  /// ### Notes
  /// - Multiple creators may be registered.
  /// - Returning `null` simply indicates that this creator does not handle
  ///   the requested name.
  /// - This mechanism allows external modules to integrate seamlessly
  ///   with JetLeaf's rate-limit system.
  void addCreator(RateLimitStorageCreator createIfNotFound);
}

/// A factory function capable of creating a new [RateLimitStorage]
/// instance when a requested storage name is not already registered
/// in the [RateLimitStorageRegistry].
///
/// The function receives the missing storage's name and should return:
/// - A newly created [RateLimitStorage] instance, or
/// - `null` to indicate that the creator does not handle this name.
///
/// ### Purpose
///
/// This typedef enables plug-ins, modules, or application-level code
/// to provide custom dynamic storage creation logic.  
/// This is especially useful when storages depend on runtime values or
/// naming conventions—for example:
///
/// - Automatically creating Redis-backed storages for names like `redis:primary`.
/// - Creating tenant-specific storages using the name as the tenant key.
/// - Loading distributed storage adapters based on environment profiles.
///
/// ### Example
/// ```dart
/// registry.addCreator((name) {
///   if (name.startsWith('redis:')) {
///     return RedisRateLimitStorage(name);
///   }
///   return null; // Not handled by this creator.
/// });
/// ```
///
/// ### Notes
/// - The returned storage will be registered automatically by the registry.
/// - If the storage implements lifecycle interfaces (e.g., [InitializingPod]),
///   the registry will invoke them as needed.
/// - Multiple creators may be registered; each is tried in registration order.
typedef RateLimitStorageCreator = FutureOr<RateLimitStorage?> Function(String name);