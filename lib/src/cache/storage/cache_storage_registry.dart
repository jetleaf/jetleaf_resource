import 'dart:async';

import 'cache_storage.dart';

/// {@template jet_cache_storage_registry}
/// Defines a registry contract for managing [CacheStorage] instances.
///
/// A [CacheStorageRegistry] is responsible for registering concrete cache
/// storage implementations that back one or more [Cache] instances.
/// Each registered [CacheStorage] typically represents a physical persistence
/// or memory layer within the caching infrastructure.
///
/// ### Usage
///
/// This interface is implemented by composite or configurable cache systems
/// that manage multiple storage backends (e.g., in-memory, file-based,
/// distributed).
///
/// ### Example
///
/// ```dart
/// registry.addStorage(InMemoryCacheStorage());
/// registry.addStorage(FileCacheStorage());
/// ```
///
/// ### Related Components
///
/// - [CacheStorage]
/// - [CacheManager]
/// - [CompositeCacheManager]
///
/// {@endtemplate}
abstract interface class CacheStorageRegistry {
  /// Registers a [CacheStorage] instance within the registry.
  ///
  /// Registered storages serve as underlying physical stores for cache data.
  /// Multiple storages can coexist, providing a unified access layer through
  /// composite cache management.
  void addStorage(CacheStorage storage);

  /// Registers a fallback cache storage creator used when a requested storage
  /// name is not found in the registry.
  ///
  /// A *creator* is a user-provided factory function capable of constructing
  /// a new [CacheStorage] instance on demand. When `getStorage(name)` is
  /// invoked and no existing storage matches the given name, all registered
  /// creators are evaluated (in registration order) until one returns a
  /// non-null storage.
  ///
  /// ### Use Cases
  /// - Allowing applications to plug in dynamic storage construction
  ///   (e.g., auto-creating Redis or database-backed storages).
  /// - Supporting lazy, name-based, on-demand creation.
  /// - Enabling module-level extensibility without modifying the manager.
  ///
  /// ### Example
  /// ```dart
  /// registry.addCreator((name) async {
  ///   // Dynamically create a Redis storage for a requested name.
  ///   if (name.startsWith('redis:')) {
  ///     return RedisCacheStorage(name);
  ///   }
  ///   return null; // Not handled by this creator.
  /// });
  /// ```
  ///
  /// ### Notes
  /// - Creators may return `null` to indicate “not responsible”.
  /// - Evaluation order matters; the first non-null result wins.
  /// - Implementations may apply synchronization for thread-safe access.
  void addCreator(CacheStorageCreator createIfNotFound);
}

/// A factory function capable of creating a [CacheStorage] dynamically
/// when the registry cannot find a storage by name.
///
/// Returning:
/// - a concrete [CacheStorage] → the storage will be registered and used
/// - `null` → the creator declines responsibility
///
/// Creators may be synchronous or asynchronous.
///
/// ### Signature
/// - [name]: the storage name being requested by the caller.
///
/// ### Example
/// ```dart
/// CacheStorageCreator creator = (name) async {
///   if (name == 'local') return InMemoryCacheStorage('local');
///   return null;
/// };
/// ```
typedef CacheStorageCreator = FutureOr<CacheStorage?> Function(String name);