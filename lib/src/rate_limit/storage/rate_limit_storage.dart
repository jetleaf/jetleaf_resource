import 'dart:async';

import 'package:jetleaf_lang/lang.dart';

import '../../base/resource.dart';
import '../metrics/rate_limit_metrics.dart';
import '../rate_limit_result.dart';

/// {@template rate_limit_storage}
/// The [RateLimitStorage] interface defines the abstraction for JetLeaf’s
/// rate-limiting persistence and quota tracking mechanism.
///
/// Implementations are responsible for managing request counts, evaluating 
/// quota conditions, and tracking reset windows across potentially distributed 
/// systems. A [RateLimitStorage] can be in-memory, cache-backed, or fully 
/// distributed depending on the system configuration.
///
/// ### Purpose
///
/// The rate-limit storage forms the foundation of JetLeaf’s traffic-control 
/// subsystem. It is queried by [RateLimiter] and orchestrated by [RateLimitManager]
/// to ensure consistent and predictable throttling behavior across pods, 
/// environments, and profiles.
///
/// ### Responsibilities
///
/// - Persist request counters within defined time windows  
/// - Enforce rate limits for unique requesters (e.g., users, clients, IPs)  
/// - Report usage metrics, remaining quota, and reset times  
/// - Support safe concurrent updates in multi-threaded or multi-instance systems  
///
/// ### Typical Implementations
///
/// | Implementation | Description | Use Case |
/// |----------------|--------------|-----------|
/// | InMemoryRateLimitStorage | Uses in-memory maps | Local testing, lightweight pods |
/// | RedisRateLimitStorage | Uses Redis INCR/EXPIRE | Distributed deployments |
/// | DatabaseRateLimitStorage | Uses SQL counters | Persistent tracking or audits |
///
/// ### Related Components
/// - [RateLimiter]: Consumes this interface to decide if a request is allowed.
/// - [RateLimitManager]: Manages multiple storages with ordered precedence.
/// - [CacheStorage]: Can serve as the base persistence layer.
/// {@endtemplate}
abstract interface class RateLimitStorage with EqualsAndHashCode {
  /// {@template rate_limit_storage_get_name}
  /// Returns the canonical name of this [RateLimitStorage] instance.
  ///
  /// The name acts as a unique identifier within JetLeaf’s rate-limiting
  /// registry and is used for diagnostics, tracing, and configuration mapping.
  ///
  /// ### Behavior
  ///
  /// - Implementations should return stable, descriptive identifiers
  ///   (e.g., `"redis-rate-limit"`, `"in-memory-limit"`).
  /// - Names are used by [RateLimitManager] to group or prioritize storages.
  /// - Logging and metrics systems include this name when reporting rate-limit
  ///   evaluations and errors.
  ///
  /// ### Example
  /// ```dart
  /// final name = storage.getName(); // "redis-rate-limit"
  /// ```
  /// {@endtemplate}
  String getName();

  /// {@template rate_limit_storage_get_store}
  /// Returns the underlying native rate-limit provider object.
  ///
  /// The returned object provides direct access to the storage backend, which
  /// may be a cache client, database adapter, or in-memory map.
  ///
  /// ### Behavior
  /// - Should expose the actual runtime instance backing the rate-limit data.
  /// - Enables custom integrations, health checks, or advanced debugging.
  ///
  /// ### Notes
  /// - Avoid mutating the returned object directly.
  /// - Access should be read-only in most JetLeaf contexts.
  ///
  /// ### Example
  /// ```dart
  /// final redis = (storage as RedisRateLimitStorage).getResource();
  /// print(redis.clientName);
  /// ```
  /// {@endtemplate}
  Resource getResource();

  /// {@template rate_limit_storage_is_allowed}
  /// Determines whether a request is permitted under the defined rate limit.
  ///
  /// This method evaluates whether the given [identifier] (representing
  /// a unique requester such as a user ID, token, or IP address) has exceeded
  /// its quota within the specified [window].
  ///
  /// ### Evaluation Logic
  ///
  /// - The implementation retrieves the existing counter for [identifier].
  /// - It checks whether the number of recorded requests in the current window
  ///   exceeds the [limit].
  /// - If within limit, the request is allowed (`true`).
  /// - If the limit is exceeded, the request is denied (`false`).
  ///
  /// ### Example
  /// ```dart
  /// final allowed = await storage.tryConsume('user:123', 100, Duration(minutes: 1));
  /// if (!allowed) throw RateLimitExceededException();
  /// ```
  ///
  /// ### Implementation Notes
  ///
  /// - Implementations should ensure atomicity when evaluating and updating
  ///   counters in concurrent or distributed systems.
  /// - Redis-based stores typically use atomic `INCR` with `EXPIRE` operations.
  /// - In-memory implementations should prune expired entries regularly.
  ///
  /// ### Related
  /// - [recordRequest] — updates counters after a successful request.
  /// - [getRemainingRequests] — returns remaining quota for an identifier.
  /// {@endtemplate}
  FutureOr<RateLimitResult> tryConsume(Object identifier, int limit, Duration window);

  /// {@template rate_limit_storage_record_request}
  /// Records a successful request for the given [identifier].
  ///
  /// This method increments the counter or appends a timestamp entry associated
  /// with the [identifier] within the specified [window].  
  ///
  /// ### Behavior
  ///
  /// - Called **after** a request is processed successfully.
  /// - Updates the internal counter, ensuring the rate-limit state reflects
  ///   the most recent activity.
  /// - May create a new entry if the [identifier] is seen for the first time.
  ///
  /// ### Implementation Notes
  ///
  /// - For timestamp-based implementations, purge entries older than [window].
  /// - For counter-based implementations, reset counters after expiration.
  /// - Distributed implementations must ensure write consistency.
  ///
  /// ### Example
  /// ```dart
  /// await storage.recordRequest('client:42', Duration(seconds: 60));
  /// ```
  /// {@endtemplate}
  FutureOr<void> recordRequest(Object identifier, Duration window);

  /// {@template rate_limit_storage_get_request_count}
  /// Retrieves the current number of requests recorded for the given [identifier].
  ///
  /// ### Behavior
  ///
  /// - Returns the count of requests within the current active [window].
  /// - If no requests are recorded, returns `0`.
  /// - If the window has expired, the counter should automatically reset.
  ///
  /// ### Use Cases
  /// - Used by monitoring systems to report current rate-limit usage.
  /// - Helpful for debugging or custom dashboards.
  ///
  /// ### Example
  /// ```dart
  /// final count = await storage.getRequestCount('user:007', Duration(minutes: 1));
  /// print('Requests in window: $count');
  /// ```
  ///
  /// ### Implementation Notes
  /// - Ensure efficient lookup even in large datasets.
  /// - Expired data should not contribute to the count.
  /// {@endtemplate}
  FutureOr<int> getRequestCount(Object identifier, Duration window);

  /// {@template rate_limit_storage_get_remaining_requests}
  /// Calculates how many requests remain before the rate limit is reached.
  ///
  /// ### Behavior
  ///
  /// - Retrieves the current count for [identifier].
  /// - Computes the difference between [limit] and current count.
  /// - Returns `0` if the limit has been reached or exceeded.
  ///
  /// ### Example
  /// ```dart
  /// final remaining = await storage.getRemainingRequests('user:123', 50, Duration(minutes: 1));
  /// print('Remaining requests: $remaining');
  /// ```
  ///
  /// ### Notes
  /// - Implementations may optimize by caching recent results.
  /// - When used in distributed environments, returned values are approximate
  ///   due to eventual consistency.
  ///
  /// ### Related
  /// - [getRequestCount]
  /// - [tryConsume]
  /// {@endtemplate}
  FutureOr<int> getRemainingRequests(Object identifier, int limit, Duration window);

  /// {@template rate_limit_storage_get_reset_time}
  /// Returns the timestamp when the rate-limit window will reset for a given [identifier].
  ///
  /// ### Behavior
  ///
  /// - Indicates when the quota for [identifier] will fully replenish.
  /// - Returns `null` if no rate-limit tracking exists.
  ///
  /// ### Example
  /// ```dart
  /// final resetAt = await storage.getResetTime('ip:127.0.0.1', Duration(minutes: 1));
  /// print('Resets at: $resetAt');
  /// ```
  ///
  /// ### Implementation Notes
  /// - Redis-based implementations typically use TTL queries.
  /// - In-memory stores may derive reset time from oldest entry timestamp.
  ///
  /// ### Related
  /// - [clear]
  /// - [reset]
  /// {@endtemplate}
  FutureOr<DateTime?> getResetTime(Object identifier, Duration window);

  /// Calculates and returns the remaining duration before the current
  /// rate limit window resets for the given [identifier].
  ///
  /// This value is typically used to populate the `Retry-After` HTTP header
  /// in rate-limited responses. Implementations should ensure that the
  /// computed duration is timezone-aware and aligned with the configured
  /// [RateLimitEntry.resetTime].
  ///
  /// Returns a [ZonedDateTime] indicating when the identifier may send
  /// requests again, or `null` if the identifier is not currently limited.
  FutureOr<ZonedDateTime?> getRetryAfter(Object identifier, Duration window);

  /// {@template rate_limit_storage_reset}
  /// Resets the rate-limit state for a specific [identifier].
  ///
  /// ### Behavior
  ///
  /// - Clears all recorded request counts or timestamps for the given entity.
  /// - Effectively restarts the rate-limit window for that identifier.
  ///
  /// ### Example
  /// ```dart
  /// await storage.reset('user:blocked123');
  /// ```
  ///
  /// ### Use Cases
  /// - Administrative override to unblock users.
  /// - Reset on successful authentication or status change.
  ///
  /// ### Implementation Notes
  /// - Should ensure atomic deletion of per-identifier data.
  /// - Distributed implementations must propagate deletions consistently.
  /// {@endtemplate}
  FutureOr<void> reset(Object identifier);

  /// {@template rate_limit_storage_clear}
  /// Clears all rate-limit tracking data across all identifiers.
  ///
  /// ### Behavior
  ///
  /// - Removes **all** keys, counters, or timestamps associated with
  ///   the rate-limit storage.
  /// - Useful for testing, maintenance, or full system reset operations.
  ///
  /// ### Example
  /// ```dart
  /// await storage.clear();
  /// ```
  ///
  /// ### Notes
  /// - This operation is **destructive** and should be used cautiously.
  /// - May cause temporary throttling in distributed systems while caches rebuild.
  /// {@endtemplate}
  FutureOr<void> clear();

  /// {@template rate_limit_storage_invalidate}
  /// Invalidates the current rate-limit storage and cleans up its resources.
  ///
  /// ### Behavior
  ///
  /// - Called during shutdown, reconfiguration, or context refresh.
  /// - Closes network connections, clears in-memory structures,
  ///   and releases external handles.
  ///
  /// ### Example
  /// ```dart
  /// await storage.invalidate();
  /// ```
  ///
  /// ### Implementation Notes
  /// - Should be idempotent and safe to call multiple times.
  /// - Ensure graceful cleanup for distributed stores to prevent leaks.
  ///
  /// ### Related
  /// - [clear]
  /// {@endtemplate}
  FutureOr<void> invalidate();

  /// {@template rate_limit_storage_get_metrics}
  /// Returns the metrics associated with this rate limit storage.
  ///
  /// Metrics provide insight into the usage and performance of the rate limiter,
  /// including counts of:
  /// - Allowed requests
  /// - Denied requests
  /// - Resets
  /// - Errors or exceptions
  ///
  /// ### Example
  /// ```dart
  /// final metrics = storage.getMetrics();
  /// print('Allowed requests: ${metrics.getAllowed()}');
  /// print('Denied requests: ${metrics.deniedCount}');
  /// ```
  /// {@endtemplate}
  RateLimitMetrics getMetrics();
}