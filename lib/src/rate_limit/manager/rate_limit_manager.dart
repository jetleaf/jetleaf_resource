import 'dart:async';

import '../storage/rate_limit_storage.dart';

/// {@template rate_limit_manager}
/// The [RateLimitManager] interface defines the orchestration layer for managing
/// multiple [RateLimitStorage] instances within JetLeaf’s traffic control
/// subsystem.
///
/// It acts as a coordination facade, allowing higher-level components like
/// [RateLimiter], [RateLimitAdvisor], or [RequestThrottleInterceptor] to access,
/// manage, and aggregate quota data across multiple storage backends.
///
/// ### Purpose
///
/// A single JetLeaf application may use multiple [RateLimitStorage]s — e.g.,
/// a distributed Redis-backed store for global quotas, an in-memory store for
/// ephemeral user sessions, and a database-backed store for analytics.  
/// [RateLimitManager] provides a unified abstraction to discover, interact with,
/// and maintain all such storages in a consistent and ordered fashion.
///
/// ### Responsibilities
///
/// - Register and expose all configured [RateLimitStorage] implementations.
/// - Resolve storages dynamically by name or type.
/// - Support clearing and destruction of all storages during shutdown or reload.
/// - Act as a dependency target for [RateLimiter] and configuration pods.
///
/// ### Typical Implementations
///
/// | Implementation | Description |
/// |----------------|--------------|
/// | DefaultRateLimitManager | Manages a local or distributed set of storages |
/// | CompositeRateLimitManager | Aggregates multiple managers for multi-cluster control |
///
/// ### Related Components
/// - [RateLimitStorage] — The individual persistence units managed by this interface.
/// - [RateLimiter] — Consumes the manager to perform quota checks.
/// - [Environment] — May define which storages are activated via profiles.
/// {@endtemplate}
abstract interface class RateLimitManager {
  /// {@template rate_limit_manager_get_storage}
  /// Retrieves a [RateLimitStorage] instance by its unique [name].
  ///
  /// This method provides direct access to a registered rate-limit backend, 
  /// allowing targeted quota operations or manual inspection.
  ///
  /// ### Behavior
  ///
  /// - Returns `null` if no storage with the specified [name] exists.  
  /// - Implementations should support lazy initialization if storage creation
  ///   is deferred.  
  /// - Name matching is typically case-sensitive unless overridden.
  ///
  /// ### Example
  /// ```dart
  /// final redisStorage = await manager.getStorage('redis-rate-limit');
  /// if (redisStorage != null) {
  ///   final remaining = await redisStorage.getRemainingRequests(
  ///     'user:42', 
  ///     limit: 100, 
  ///     window: Duration(minutes: 1),
  ///   );
  ///   print('Remaining: $remaining');
  /// }
  /// ```
  ///
  /// ### Related
  /// - [getStorageNames]
  /// - [RateLimitStorage.getName]
  /// {@endtemplate}
  FutureOr<RateLimitStorage?> getStorage(String name);

  /// {@template rate_limit_manager_get_storage_names}
  /// Returns the names of all currently managed [RateLimitStorage] instances.
  ///
  /// ### Behavior
  ///
  /// - Always returns a deterministic, ordered collection for predictable
  ///   diagnostics and monitoring.  
  /// - The names reflect the identifiers returned by each storage’s
  ///   [RateLimitStorage.getName] implementation.
  ///
  /// ### Example
  /// ```dart
  /// final names = await manager.getStorageNames();
  /// print('Registered storages: ${names.join(', ')}');
  /// ```
  ///
  /// ### Use Cases
  /// - For diagnostics dashboards and CLI tools.
  /// - Useful for validation of configuration completeness.
  ///
  /// ### Related
  /// - [getStorage]
  /// {@endtemplate}
  FutureOr<Iterable<String>> getStorageNames();

  /// {@template rate_limit_manager_clear_all}
  /// Clears all rate-limit data across every managed [RateLimitStorage].
  ///
  /// ### Behavior
  ///
  /// - Invokes [RateLimitStorage.clear] on each registered storage.
  /// - Removes all request counters, timestamps, and quota data globally.
  /// - May trigger rebalancing or cleanup events for distributed backends.
  ///
  /// ### Example
  /// ```dart
  /// await manager.clearAll();
  /// print('All rate-limit data cleared.');
  /// ```
  ///
  /// ### Implementation Notes
  /// - Should gracefully skip over unavailable or invalid storages.
  /// - Must ensure operations are isolated and non-blocking if parallelized.
  ///
  /// ### Related
  /// - [RateLimitStorage.clear]
  /// - [destroy]
  /// {@endtemplate}
  FutureOr<void> clearAll();

  /// {@template rate_limit_manager_destroy}
  /// Destroys all managed [RateLimitStorage] instances and releases their resources.
  ///
  /// This operation is typically performed during:
  /// - Application shutdown  
  /// - Environment refresh  
  /// - Dynamic configuration reload  
  ///
  /// ### Behavior
  ///
  /// - Invokes [RateLimitStorage.invalidate] on each managed storage.
  /// - Ensures that all network connections, caches, and temporary data are
  ///   properly released.  
  /// - Implementations must guarantee idempotency to prevent double disposal.
  ///
  /// ### Example
  /// ```dart
  /// await manager.destroy();
  /// print('Rate-limit subsystem destroyed.');
  /// ```
  ///
  /// ### Implementation Notes
  /// - Should be called **after** [clearAll] when performing full system teardown.
  /// - Exceptions should be logged and suppressed to prevent cascading failures.
  ///
  /// ### Related
  /// - [RateLimitStorage.invalidate]
  /// - [clearAll]
  /// {@endtemplate}
  FutureOr<void> destroy();
}