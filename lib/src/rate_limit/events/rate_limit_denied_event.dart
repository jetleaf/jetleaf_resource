import 'rate_limit_event.dart';

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