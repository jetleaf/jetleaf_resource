import 'package:jetleaf_lang/lang.dart';

/// {@template rate_limit_metrics}
/// Defines the contract for recording and reporting rate limit activity metrics.
///
/// The [RateLimitMetrics] interface provides visibility into runtime behavior
/// of rate-limited operations by tracking requests, blocks, and reset events.
/// Implementations can use this interface to collect, analyze, and visualize
/// traffic control patterns across distributed systems.
///
/// ### Overview
///
/// Each rate limit configuration can be associated with a [RateLimitMetrics]
/// instance that tracks quantitative data such as:
/// - Allowed (successful) requests
/// - Denied (rate-limited) requests
/// - Reset operations (window resets or manual resets)
/// - Last update timestamp
///
/// Metrics can be consumed by monitoring tools, observability dashboards,
/// or auditing components to measure traffic distribution and rate-limit
/// efficiency over time.
///
/// ### Typical Implementations
/// - [DefaultRateLimitMetrics]
/// - [DistributedRateLimitMetrics]
/// - [InMemoryRateLimitMetrics]
///
/// ### Integration
/// - Used internally by [RateLimitManager] and [RateLimitStorage].
/// - Exposed via [RateLimitEndpoint] for operational dashboards.
/// - Can be reset periodically to align with observation windows.
/// - Serves as a data source for analytics or visualization backends.
///
/// ### Example
/// ```dart
/// final metrics = InMemoryRateLimitMetrics('auth');
///
/// metrics.recordAllowed('user:42');
/// metrics.recordDenied('user:17');
///
/// print(metrics.buildGraph());
/// ```
///
/// Example output:
/// ```dart
/// {
///   "rate_limit_name": "auth",
///   "operations": {
///     "allowed": {"user:42": 3},
///     "denied": {"user:17": 1},
///     "resets": 0
///   },
///   "last_updated": "2025-10-20T12:34:56Z"
/// }
/// ```
///
/// {@endtemplate}
abstract interface class RateLimitMetrics {
  /// Returns the logical name of the rate limit metric instance.
  ///
  /// Typically corresponds to the rate limit rule or resource name
  /// (e.g., `"login"`, `"api_v1_users"`, `"checkout_service"`).
  String getName();

  /// Returns the total number of allowed (non-denied) requests recorded.
  ///
  /// This value represents how many requests passed the rate limit check
  /// successfully during the current measurement window.
  int getAllowedRequests();

  /// Returns the total number of denied requests recorded.
  ///
  /// Denied requests are those denied access due to exceeding
  /// the configured rate limit thresholds.
  int getDeniedRequests();

  /// Returns the total number of reset events recorded.
  ///
  /// Resets may occur automatically when a rate limit window expires,
  /// or manually via administrative operations.
  int getResets();

  /// Returns the timestamp of the last metric update.
  ///
  /// This value represents the last time any of the metrics
  /// (allowed, denied, or reset) were modified.
  ZonedDateTime getLastUpdated();

  /// Records an allowed request for the specified [identifier].
  ///
  /// **Parameters:**
  /// - [identifier]: The logical entity (user, IP, token, etc.) associated with the request.
  ///
  /// This method increments the allowed request counter and updates
  /// the internal timestamp. Implementations may choose to maintain
  /// per-identifier counts for detailed analytics.
  void recordAllowed(Object identifier);

  /// Records a denied request for the specified [identifier].
  ///
  /// **Parameters:**
  /// - [identifier]: The logical entity that was rate-limited.
  ///
  /// This method increments the denied request counter and updates
  /// the internal timestamp.
  void recordDenied(Object identifier);

  /// Records a rate limit reset event for the specified [identifier].
  ///
  /// **Parameters:**
  /// - [identifier]: The logical entity whose rate limit state was reset.
  ///
  /// Implementations should increment the reset counter and update
  /// the last updated timestamp accordingly.
  void recordReset(Object identifier);

  /// Resets all metrics to zero, clearing accumulated statistics.
  ///
  /// Useful for monitoring windows or when starting a new measurement interval.
  ///
  /// This operation does not affect the underlying rate limit state —
  /// it only resets the counters maintained by this metrics tracker.
  void reset();

  /// Builds a structured, JSON-compatible representation of the rate limit metrics.
  ///
  /// The returned [Map] provides a graph-like structure showing relationships
  /// between identifiers and recorded operation types (allowed, denied, resets).
  ///
  /// Implementations may enrich this data with metadata such as timestamps,
  /// total counts, or historical trends for observability dashboards.
  ///
  /// **Returns:**
  /// - A [Map] representing the current metrics state.
  ///
  /// **Example Output:**
  /// ```dart
  /// {
  ///   "rate_limit_name": "products",
  ///   "operations": {
  ///     "allowed": {"id:100": 35},
  ///     "denied": {"id:101": 2}
  ///   },
  ///   "last_updated": "2025-10-20T15:12:00Z"
  /// }
  /// ```
  Map<String, Object> buildGraph();

  /// {@template rate_limit_decrement_allowed}
  /// Decrements the allowed request counter for the specified [identifier].
  ///
  /// This is a **best-effort** operation that reduces the number of recorded
  /// allowed requests by one. The returned value is the updated count, guaranteed
  /// to be **non-negative** (i.e., zero is the minimum).
  ///
  /// ### Parameters
  /// - [identifier]: The unique identifier (user, IP, token, etc.) whose allowed
  ///   request count should be decremented.
  ///
  /// ### Returns
  /// The updated allowed request count for [identifier], after decrementing.
  ///
  /// ### Notes
  /// - Typically used for manual adjustments, compensating for mistakenly recorded
  ///   allowed requests, or testing scenarios.
  /// - Implementations should ensure atomicity if concurrent updates are possible.
  ///
  /// ### Example
  /// ```dart
  /// final remaining = storage.decrementAllowed('user:42');
  /// print('Updated allowed count: $remaining');
  /// ```
  /// {@endtemplate}
  int decrementAllowed(Object identifier);

  /// {@template rate_limit_decrement_denied}
  /// Decrements the denied request counter for the specified [identifier].
  ///
  /// This is a **best-effort** operation that reduces the number of recorded
  /// denied requests by one. The returned value is the updated count, guaranteed
  /// to be **non-negative** (i.e., zero is the minimum).
  ///
  /// ### Parameters
  /// - [identifier]: The unique identifier (user, IP, token, etc.) whose denied
  ///   request count should be decremented.
  ///
  /// ### Returns
  /// The updated denied request count for [identifier], after decrementing.
  ///
  /// ### Notes
  /// - Typically used for manual adjustments, compensating for mistakenly recorded
  ///   denied requests, or testing scenarios.
  /// - Implementations should ensure atomicity if concurrent updates are possible.
  ///
  /// ### Example
  /// ```dart
  /// final remainingDenied = storage.decrementDenied('user:42');
  /// print('Updated denied count: $remainingDenied');
  /// ```
  /// {@endtemplate}
  int decrementDenied(Object identifier);
}