// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
//
// This source file is part of the JetLeaf Framework and is protected
// under copyright law. You may not copy, modify, or distribute this file
// except in compliance with the JetLeaf license.
//
// For licensing terms, see the LICENSE file in the root of this project.
// ---------------------------------------------------------------------------
// 
// 🔧 Powered by Hapnium — the Dart backend engine 🍃

import 'dart:async';

import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_core/intercept.dart';
import 'package:jetleaf_lang/lang.dart';

import '../exceptions.dart';
import '../resource.dart';
import 'annotations.dart';

/// {@template rate_limit_entry}
/// Represents a single tracked rate limit record within a [RateLimitStorage].
///
/// A [RateLimitEntry] encapsulates the state of a rate-limited identifier
/// (such as a user ID, IP address, or client token) within a specific
/// rate limit window. It tracks request counts, timestamps, and window keys
/// used to group and identify rate-limited entities.
///
/// ### Overview
///
/// Each [RateLimitEntry] is uniquely associated with a rate limit “window,”
/// identified by [getWindowKey]. Within this window, it keeps track of:
///
/// - **Request Count** – how many requests have been made ([getCount])
/// - **Timestamps** – when the entry was created ([getTimeStamp])
/// - **Reset Time** – when the window will expire ([getResetTime])
///
/// Once the reset time is reached or the window is deemed expired
/// ([isExpired]), the entry can be cleared or reinitialized via [reset].
///
/// ### Typical Lifecycle
///
/// 1. **Creation:** The [RateLimitStorage] creates a new entry for a new
///    identifier (e.g., `"user:123"`) when the first request occurs.
/// 2. **Tracking:** Each incoming request increments the internal count.
/// 3. **Expiration Check:** The system periodically checks whether the
///    entry has expired using [isExpired].
/// 4. **Reset:** When expired, the counter resets, timestamps are refreshed,
///    and the new window begins.
///
/// ### Example
///
/// ```dart
/// final entry = DefaultRateLimitEntry(
///   windowKey: 'user:123|60s',
///   count: 10,
///   timeStamp: ZonedDateTime.now(),
///   resetTime: ZonedDateTime.now().plusSeconds(60),
/// );
///
/// if (entry.isExpired()) {
///   entry.reset();
/// } else {
///   print('Remaining time: ${entry.getResetTime().difference(ZonedDateTime.now())}');
/// }
/// ```
///
/// ### Integration
///
/// - Managed by [RateLimitStorage] for persistence and retrieval.
/// - Queried by [RateLimitManager] during rate enforcement.
/// - Used by [RateLimitResolver] to resolve applicable storage backends.
/// - Interacts with [RateLimitErrorHandler] during failure handling.
///
/// ### Thread Safety
///
/// Implementations **must be concurrency-safe** in multi-threaded or
/// asynchronous environments to prevent inconsistent state.
///
/// {@endtemplate}
abstract interface class RateLimitEntry {
  /// Returns a unique key representing this rate limit window.
  ///
  /// The window key uniquely identifies a rate-limited entity within
  /// a specific time window. It is typically a composition of the identifier
  /// (e.g., user ID or API key) and window duration.
  ///
  /// Example format:
  /// ```
  /// user:123|60s
  /// api-key:abc123|1m
  /// ```
  ///
  /// **Returns:**
  /// - A [String] uniquely identifying this rate limit window.
  ///
  /// ### Usage Example
  /// ```dart
  /// print('Window key: ${entry.getWindowKey()}');
  /// ```
  String getWindowKey();

  /// Determines whether the rate limit entry has expired.
  ///
  /// Implementations should compare the current system time with
  /// [getResetTime] to decide if this entry has exceeded its lifespan.
  /// When expired, a reset is typically triggered by [RateLimitStorage].
  ///
  /// **Returns:**
  /// - `true` if the entry has expired and should be reset.
  /// - `false` if the entry is still active.
  ///
  /// ### Example
  /// ```dart
  /// if (entry.isExpired()) {
  ///   entry.reset();
  /// }
  /// ```
  bool isExpired();

  /// Returns the current request count within the active rate limit window.
  ///
  /// This count increments as requests are recorded for the identifier.
  /// Once the rate limit [RateLimit.limit] is reached, further requests
  /// may be rejected until [getResetTime] passes.
  ///
  /// **Returns:**
  /// - The total number of recorded requests as an [int].
  ///
  /// ### Example
  /// ```dart
  /// final count = entry.getCount();
  /// print('Requests so far: $count');
  /// ```
  int getCount();

  /// Returns the timestamp when this rate limit entry was created or last updated.
  ///
  /// This timestamp marks the beginning of the current rate limit window
  /// and is used to compute expiration relative to [getResetTime].
  ///
  /// **Returns:**
  /// - The [ZonedDateTime] of creation or last update.
  ///
  /// ### Example
  /// ```dart
  /// print('Window started at: ${entry.getTimeStamp()}');
  /// ```
  ZonedDateTime getTimeStamp();

  /// Returns the exact time when the rate limit window will reset.
  ///
  /// After this timestamp, the entry is considered expired and can be reset
  /// or replaced with a new window.
  ///
  /// **Returns:**
  /// - The [ZonedDateTime] representing the end of the window.
  ///
  /// ### Example
  /// ```dart
  /// print('Resets at: ${entry.getResetTime()}');
  /// ```
  ZonedDateTime getResetTime();

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
  ZonedDateTime getRetryAfter();

  /// {@template rate_limit_storage_get_window_duration}
  /// Returns the configured rate limit window for this storage.
  ///
  /// The window defines the period in which the [limit] applies. For example,
  /// a window of 1 minute means that up to `limit` requests are allowed per minute.
  ///
  /// ### Behavior
  /// - Used by [tryConsume], [getRemainingRequests], and [getResetTime].
  /// - Should reflect the actual duration applied to all identifiers in this storage.
  ///
  /// ### Example
  /// ```dart
  /// final window = storage.getWindowDuration();
  /// print('Rate limit window: ${window.inSeconds} seconds');
  /// ```
  /// {@endtemplate}
  Duration getWindowDuration();

  /// Resets all entry data to zero, clearing the historical statistics.
  ///
  /// This is useful for monitoring windows or when starting a new
  /// measurement interval.
  void reset();
}

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

/// {@template rate_limit_event}
/// Base class for all **rate limit events** in JetLeaf.
///
/// Rate limit events capture occurrences related to the enforcement of
/// rate limiting on resources, APIs, or operations. These events are
/// dispatched through the JetLeaf application event system and allow
/// developers to observe, monitor, and react to rate limit activity.
///
/// This base class is extended by specific event types such as:
/// - [RateLimitAllowedEvent]: Triggered when a request is allowed.
/// - [RateLimitDeniedEvent]: Triggered when a request is blocked due to
///   exceeding rate limits.
/// - [RateLimitResetEvent]: Triggered when a rate limit counter is reset.
///
/// ### Purpose
///
/// The purpose of this class is to provide a structured representation of
/// rate limit activity. Each event carries metadata about:
/// 1. The entity being rate-limited (`source`),
/// 2. The rate-limited resource or bucket (`limitName`),
/// 3. The timestamp of the event (`timestamp`), which defaults to the
///    creation time if not explicitly set.
///
/// Observers can subscribe to these events to implement:
/// - Custom logging of allowed and blocked requests
/// - Real-time monitoring dashboards
/// - Alerts for excessive request patterns
/// - Metrics aggregation for reporting
///
/// ### Properties
///
/// - [limitName]: The name of the rate-limited resource, such as `"login_attempts"`
///   or `"api_requests"`.
/// - [source]: The identifier for the entity being rate-limited. Typically
///   this is a user ID, API key, or IP address.
/// - [timestamp]: Optional event timestamp. Defaults to the current
///   time if not specified.
///
/// ### Example
///
/// ```dart
/// final event = RateLimitAllowedEvent('user:42', 'login_attempts');
/// eventPublisher.publish(event);
///
/// final blockedEvent = RateLimitDeniedEvent('user:42', 'login_attempts');
/// eventPublisher.publish(blockedEvent);
/// ```
///
/// ### Related Components
///
/// - [RateLimit]: The annotation defining rate-limited methods or endpoints.
/// - [RateLimitStorage]: Stores the counters and state for rate-limited resources.
/// - [RateLimitManager]: Manages multiple [RateLimitStorage] instances.
/// - [RateLimitMetrics]: Provides aggregated statistics for monitoring.
/// - [RateLimitResolver]: Determines which storage(s) should be used for a given operation.
///
/// By extending [RateLimitEvent], developers can create **custom events**
/// with additional metadata or behavior for specialized monitoring
/// or alerting requirements.
///
/// {@endtemplate}
abstract class RateLimitEvent extends ApplicationEvent {
  /// The name of the rate-limited resource or bucket.
  final String limitName;

  /// Creates a new rate limit event.
  ///
  /// [source] is typically the identifier for the rate-limited entity.
  /// [limitName] identifies the specific rate limit bucket or resource.
  /// [timestamp] optionally overrides the default event timestamp.
  /// 
  /// {@macro rate_limit_event}
  const RateLimitEvent(super.source, this.limitName, [super.timestamp]);

  @override
  String getPackageName() => PackageNames.RESOURCE;
}

/// {@template rate_limit_allowed_event}
/// Event published when a request is **allowed** under the configured rate limit.
///
/// Observers can use this event to:
/// - Track successful, allowed requests.
/// - Update monitoring metrics (e.g., allowed request counters).
/// - Trigger auditing or logging of usage patterns.
/// - Implement dynamic behavior based on allowed requests (e.g., adaptive throttling).
///
/// This event is a subclass of [RateLimitEvent] and carries:
/// - [source]: The identifier of the entity making the request (e.g., user ID, IP address, API key).
/// - [limitName]: The name of the rate-limited resource or bucket (e.g., `"login_attempts"`).
/// - [timestamp]: Optional time at which the event occurred; defaults to the current time.
///
/// ### Example
///
/// ```dart
/// // Create an event for an allowed request
/// final allowedEvent = RateLimitAllowedEvent('user:42', 'login_attempts');
///
/// // Publish the event to the application event system
/// eventPublisher.publish(allowedEvent);
///
/// // Observer can handle this event to increment metrics
/// allowedEventListener.onEvent(allowedEvent);
/// ```
///
/// ### Related Components
///
/// - [RateLimitDeniedEvent]: Counterpart event published when a request is blocked.
/// - [RateLimitMetrics]: Can be updated in response to allowed events.
/// - [RateLimitStorage]: Maintains counters that result in allowed events.
/// - [RateLimitManager]: Aggregates multiple storages and triggers allowed/blocked events.
///
/// {@endtemplate}
final class RateLimitAllowedEvent extends RateLimitEvent {
  /// Creates a new event indicating that a request was allowed by the rate limiter.
  ///
  /// [source] identifies the entity making the request.
  /// [limitName] identifies the specific rate-limited resource.
  /// [timestamp] optionally sets the time the event occurred.
  /// 
  /// {@macro rate_limit_allowed_event}
  const RateLimitAllowedEvent(super.source, super.limitName, [super.timestamp]);

  @override
  String toString() => 'RateLimitAllowedEvent(limit: $limitName, identifier: ${getSource()})';
}

/// {@template rate_limit_denied_event}
/// Event published when a request is **denied** due to exceeding the configured rate limit.
///
/// Observers can use this event to:
/// - Track blocked requests for monitoring or alerting.
/// - Inform clients about retry windows (via [retryAfter]).
/// - Update rate limit metrics (e.g., blocked request counters).
/// - Implement throttling or backoff strategies.
///
/// This event is a subclass of [RateLimitEvent] and carries:
/// - [source]: The identifier of the entity making the request (e.g., user ID, IP address, API key).
/// - [limitName]: The name of the rate-limited resource or bucket (e.g., `"login_attempts"`).
/// - [retryAfter]: The remaining duration until the next allowed request for this entity.
/// - [timestamp]: Optional time at which the event occurred; defaults to the current time.
///
/// ### Example
///
/// ```dart
/// // Create a denied event for a request exceeding rate limit
/// final deniedEvent = RateLimitDeniedEvent('user:42', 'login_attempts', DateTime(minutes: 5));
///
/// // Publish the event to the application event system
/// eventPublisher.publish(deniedEvent);
///
/// // Observer can handle this event to notify the user or update metrics
/// deniedEventListener.onEvent(deniedEvent);
/// ```
///
/// ### Related Components
///
/// - [RateLimitAllowedEvent]: Counterpart event published when a request is allowed.
/// - [RateLimitMetrics]: Can be updated in response to denied events.
/// - [RateLimitStorage]: Maintains counters that result in denied events.
/// - [RateLimitManager]: Aggregates multiple storages and triggers allowed/denied events.
/// {@endtemplate}
final class RateLimitDeniedEvent extends RateLimitEvent {
  /// The remaining time until the request may be retried.
  final DateTime retryAfter;

  /// Creates a new event indicating the request was denied due to exceeding the rate limit.
  ///
  /// [source] identifies the entity making the request.
  /// [limitName] identifies the specific rate-limited resource.
  /// [retryAfter] specifies how long the client must wait before retrying.
  /// [timestamp] optionally sets the time the event occurred.
  /// 
  /// {@macro rate_limit_denied_event}
  const RateLimitDeniedEvent(super.source, super.limitName, this.retryAfter, [super.timestamp]);

  @override
  String toString() => 'RateLimitDeniedEvent(limit: $limitName, identifier: ${getSource()}, retryAfter: $retryAfter)';
}

/// {@template rate_limit_reset_event}
/// Event published when a rate limit window has been **reset** for a particular entity.
///
/// Observers can use this event to:
/// - Track resets for monitoring or alerting.
/// - Reset related metrics counters.
/// - Inform clients that they can resume requests without hitting the limit.
///
/// This event is a subclass of [RateLimitEvent] and carries:
/// - [source]: The identifier of the entity affected by the reset (e.g., user ID, IP address, API key).
/// - [limitName]: The name of the rate-limited resource or bucket (e.g., `"login_attempts"`).
/// - [resetTime]: The timestamp at which the rate limit window was reset.
/// - [timestamp]: Optional time at which the event occurred; defaults to the current time.
///
/// ### Example
///
/// ```dart
/// final resetEvent = RateLimitResetEvent('user:42', 'login_attempts', DateTime.now());
/// eventPublisher.publish(resetEvent);
/// ```
///
/// ### Related Components
///
/// - [RateLimitAllowedEvent]: Indicates a request was allowed.
/// - [RateLimitDeniedEvent]: Indicates a request was denied due to rate limiting.
/// - [RateLimitMetrics]: Can be updated when a reset occurs.
/// {@endtemplate}
final class RateLimitResetEvent extends RateLimitEvent {
  /// The timestamp when the rate limit was reset.
  final DateTime resetTime;

  /// Creates a new event indicating the rate limit window has been reset.
  ///
  /// {@macro rate_limit_event}
  const RateLimitResetEvent(super.source, super.limitName, this.resetTime, [super.timestamp]);

  @override
  String toString() => 'RateLimitResetEvent(limit: $limitName, identifier: ${getSource()}, resetTime: $resetTime)';
}

/// {@template rate_limit_clear_event}
/// Event published when all request counters for a given rate limit bucket
/// or storage have been cleared.
///
/// This event is typically used in rate limit management systems to notify
/// observers that a reset or clearing operation has occurred. Consumers of
/// this event can use it for:
/// 
/// - Updating monitoring dashboards or metrics counters.
/// - Logging historical rate limit usage.
/// - Triggering downstream processes that depend on cleared limits.
///
/// **Properties:**
/// - [limitName]: Identifies the rate-limited bucket or resource.
/// - [totalCount]: The total number of requests that were tracked and cleared
///   during this operation.
/// - [source]: Typically the identifier of the entity (e.g., user ID, IP, API key)
///   for which the limit was applied.
/// - [timestamp]: Optional timestamp indicating when the event occurred.
///
/// **Example Usage:**
/// ```dart
/// final event = RateLimitClearEvent('user:123', 'apiRequests', 50);
/// print(event);
/// // Output: RateLimitClearEvent(limit: apiRequests, identifier: user:123, totalCount: 50)
/// ```
/// 
/// **Related Components:**
/// - [RateLimitEvent]: Base class for all rate limit events.
/// - [RateLimitAllowedEvent]: Published when a request is allowed.
/// - [RateLimitDeniedEvent]: Published when a request is denied.
/// - [RateLimitResetEvent]: Published when a rate limit window resets.
/// - [RateLimitManager]: Manages multiple [RateLimitStorage] instances and emits events.
/// {@endtemplate}
final class RateLimitClearEvent extends RateLimitEvent {
  /// The total number of requests that were cleared from the rate limit storage.
  final int totalCount;

  /// Creates a new event indicating that a rate limit storage or bucket has been cleared.
  ///
  /// {@macro rate_limit_clear_event}
  const RateLimitClearEvent(super.source, super.limitName, this.totalCount, [super.timestamp]);

  @override
  String toString() => 'RateLimitClearEvent(limit: $limitName, identifier: ${getSource()}, totalCount: $totalCount)';
}

// =============================================================================
// RATE LIMIT STORAGE
// =============================================================================

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

/// {@template configurable_rate_limit_storage}
/// Represents a configurable rate-limit storage that allows runtime tuning
/// of critical operational parameters, primarily the time zone used for
/// window tracking and expiration calculations.
///
/// Implementations of this interface can be backed by in-memory maps,
/// distributed caches, or persistent databases. The storage is responsible
/// for tracking request counts, reset times, and TTL windows for each
/// identifier being rate-limited.
///
/// By configuring parameters like the time zone, developers ensure that
/// rate-limit calculations remain consistent across distributed systems,
/// scheduled tasks, and monitoring operations.
///
/// Typical use cases include:
/// - Rate-limiting API requests per user, IP, or client key
/// - Implementing rolling windows for burst control
/// - Synchronizing expiration logic across multiple instances
/// - Supporting multiple geographic regions with different time zones
///
/// {@endtemplate}
abstract interface class ConfigurableRateLimitStorage {
  /// {@macro configurable_rate_limit_storage}
  ///
  /// Sets the time zone used by the storage for all time-based computations,
  /// including creation timestamps, reset times, and TTL-based expirations.
  ///
  /// Changing the zone affects:
  /// - Determining when a rate-limit window expires
  /// - Computing the remaining time for requests
  /// - Eviction or reset scheduling for expired entries
  ///
  /// **Parameters:**
  /// - [zone]: The canonical identifier of the time zone (e.g., `"UTC"`, `"Europe/Berlin"`, `"Asia/Seoul"`).
  ///
  /// **Throws:**
  /// - [IllegalArgumentException] if the provided zone is invalid, unrecognized, or unsupported.
  ///
  /// **Example:**
  /// ```dart
  /// final storage = MyRateLimitStorage();
  /// storage.setZoneId('UTC'); // Use UTC for consistent cross-region limits
  /// ```
  void setZoneId(String zone);
}

// =============================================================================
// RATE LIMIT MANAGER
// =============================================================================

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

// =============================================================================
// RATE LIMIT RESOLVER
// =============================================================================

/// {@template rate_limit_resolver}
/// The [RateLimitResolver] defines the strategy contract for resolving one or more
/// [RateLimitStorage] instances for a specific [RateLimit] operation.
///
/// It acts as the bridge between annotation-level configuration ([RateLimit])
/// and runtime rate-limiting infrastructure ([RateLimitStorage] and [RateLimitManager]).
///
/// ### Purpose
///
/// In a multi-storage environment, different rate limits may apply to different
/// tiers, domains, or regions of the system.  
/// The [RateLimitResolver] encapsulates the decision logic for mapping a rate limit
/// declaration to the correct storage(s).
///
/// For instance, a global API rate limit might use a distributed Redis storage,
/// while a user-specific limit could rely on a local in-memory backend.
///
/// ### Behavior
///
/// - Given a [RateLimit] annotation, the resolver selects one or more storages
///   where the rate-limit state should be read and updated.
/// - The resolution may depend on:
///   - Explicit storage names declared in the annotation.
///   - Default storage selection rules.
///   - Contextual information (such as tenant, environment, or endpoint).
///
/// ### Example
///
/// ```dart
/// @RateLimit(['redis-rate-limit', 'local-cache'], limit: 100, window: Duration(seconds: 30))
/// Future<Response> getUserData(Request req) async {
///   ...
/// }
///
/// // During runtime
/// final resolver = DefaultRateLimitResolver(manager);
/// final storages = await resolver.resolveStorages(rateLimitAnnotation);
/// for (final storage in storages) {
///   final allowed = await storage.tryConsume('user:42', limit: rateLimit.limit, window: rateLimit.window);
///   if (!allowed) throw TooManyRequestsException();
/// }
/// ```
///
/// ### Implementation Notes
///
/// - Implementations may use priority rules, profile-based resolution,
///   or caching mechanisms to optimize lookups.
/// - The resolver should be stateless or thread-safe if shared globally.
///
/// ### Related Components
///
/// - [RateLimit]: Annotation defining the rate-limiting metadata.
/// - [RateLimitManager]: Provides access to available storages.
/// - [RateLimitStorage]: The backend persistence mechanism.
/// - [RateLimiter]: Uses this resolver during evaluation.
/// {@endtemplate}
abstract interface class RateLimitResolver {
  /// {@template rate_limit_resolver_resolve_storages}
  /// Resolves the appropriate [RateLimitStorage] instances for a given
  /// [RateLimit] operation.
  ///
  /// ### Parameters
  /// - [rateLimit]: The rate-limit metadata annotation specifying the
  ///   configuration for the current operation.
  ///
  /// ### Returns
  /// - A collection of [RateLimitStorage] instances that should participate
  ///   in the evaluation and enforcement of the given rate limit.
  ///
  /// ### Behavior
  ///
  /// - If multiple storages are declared, the returned collection must preserve
  ///   their configured order of precedence.
  /// - If no storages are explicitly defined, the resolver may fall back to
  ///   a default storage policy (e.g., a globally configured primary storage).
  ///
  /// ### Example
  /// ```dart
  /// final storages = await resolver.resolveStorages(rateLimitAnnotation);
  /// for (final storage in storages) {
  ///   await storage.recordRequest('client:abc', window: rateLimitAnnotation.window);
  /// }
  /// ```
  ///
  /// ### Related
  /// - [RateLimitStorage]
  /// - [RateLimitManager]
  /// {@endtemplate}
  FutureOr<Iterable<RateLimitStorage>> resolveStorages(RateLimit rateLimit);
}

// =============================================================================
// RATE LIMIT REGISTRIES
// =============================================================================

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
}

/// {@template rate_limit_manager_registry}
/// Registry for managing and exposing [RateLimitManager] instances.
///
/// The [RateLimitManagerRegistry] coordinates multiple rate limit managers
/// that may each govern their own scope of responsibility — such as
/// different application domains, service layers, or logical partitions.
///
/// ### Purpose
///
/// This registry allows the system to support **multi-manager** setups where
/// each manager might handle a unique set of [RateLimitStorage] instances.
/// It also enables hierarchical configurations or fallback policies.
///
/// ### Use Cases
///
/// - Registering global and tenant-specific rate limit managers.
/// - Supporting composite management strategies across distributed systems.
/// - Providing an extensible registry layer for framework-level plugins.
///
/// ### Example
/// ```dart
/// final manager = DefaultRateLimitManager('core');
/// registry.addManager(manager);
///
/// final names = await manager.getStorageNames();
/// print('Registered storages: $names');
/// ```
///
/// ### Related Components
/// - [RateLimitManager] – The managed entity.
/// - [RateLimitStorage] – Underlying storage used by the manager.
/// - [RateLimitStorageRegistry] – Lower-level registry referenced by managers.
/// {@endtemplate}
abstract interface class RateLimitManagerRegistry {
  /// Adds a new [RateLimitManager] to the registry.
  ///
  /// ### Parameters
  /// - [manager]: The [RateLimitManager] instance to register.
  ///
  /// ### Behavior
  /// - Implementations may reject duplicate names or replace existing entries.
  /// - This method should be idempotent if called multiple times with the same manager.
  ///
  /// ### Example
  /// ```dart
  /// registry.addManager(MyCustomRateLimitManager('tenant-manager'));
  /// ```
  void addManager(RateLimitManager manager);
}

/// {@template rate_limit_resolver_registry}
/// Registry for managing [RateLimitResolver] instances.
///
/// The [RateLimitResolverRegistry] acts as the discovery and orchestration
/// point for resolver components that determine how rate limit annotations
/// map to actual storage providers at runtime.
///
/// ### Purpose
///
/// It allows different [RateLimitResolver] implementations to coexist,
/// enabling layered or composite resolution strategies.
/// For instance, one resolver may interpret annotation metadata,
/// while another might apply contextual filtering based on environment
/// or runtime configuration.
///
/// ### Typical Use Cases
///
/// - Registering multiple resolver strategies (annotation-based, rule-based, etc.)
/// - Enabling pluggable extensions for custom rate-limiting resolution.
/// - Supporting environment-specific resolution logic.
///
/// ### Example
/// ```dart
/// registry.addResolver(DefaultRateLimitResolver());
///
/// final storages = await registry.resolveStorages(
///   RateLimit(limit: 100, window: Duration(minutes: 1))
/// );
/// ```
///
/// ### Related Components
/// - [RateLimitResolver] – The entities managed by this registry.
/// - [RateLimitStorage] – The resolved output target.
/// - [RateLimitManager] – Coordinates resolution results into the limiter chain.
/// {@endtemplate}
abstract interface class RateLimitResolverRegistry {
  /// Adds a [RateLimitResolver] to the registry.
  ///
  /// ### Parameters
  /// - [resolver]: The resolver to register for later use.
  ///
  /// ### Behavior
  /// - Multiple resolvers can coexist and may be chained depending
  ///   on the implementation strategy.
  /// - Implementations should ensure thread-safe registration if used
  ///   in concurrent environments.
  ///
  /// ### Example
  /// ```dart
  /// registry.addResolver(EnvironmentAwareRateLimitResolver());
  /// ```
  void addResolver(RateLimitResolver resolver);
}

// =============================================================================
// RATE LIMIT CONFIGURATION
// =============================================================================

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

/// {@template rate_limit_operation_context}
/// Context object representing the state and behavior of a rate-limited
/// method invocation or resource access.
///
/// This interface encapsulates the current request, its identifier, the
/// applicable rate limit configuration, and supports recording results
/// (allowed, denied) as well as computing retry times.
///
/// Implementations should provide mechanisms for:
/// - Generating a unique key for the rate-limited entity.
/// - Checking and recording whether the request is allowed.
/// - Accessing or updating rate limit metadata.
/// {@endtemplate}
abstract interface class RateLimitOperationContext<T> implements OperationContext, RateLimitResolver {
  /// Generates a unique key for the current rate-limited entity.
  ///
  /// This is typically based on the target object, method signature,
  /// and arguments (or custom key generator if applicable).
  /// 
  /// [preferredKeyGeneratorName] can be used to select a custom key generator.
  FutureOr<Object> generateKey([String? preferredKeyGeneratorName]);

  /// Returns the underlying method invocation metadata (target, arguments, etc.).
  MethodInvocation<T> getMethodInvocation();
}