import 'rate_limit_event.dart';

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