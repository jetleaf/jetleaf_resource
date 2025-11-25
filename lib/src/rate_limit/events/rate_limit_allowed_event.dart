import 'rate_limit_event.dart';

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