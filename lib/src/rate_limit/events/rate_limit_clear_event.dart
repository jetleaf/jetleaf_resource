import 'rate_limit_event.dart';

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