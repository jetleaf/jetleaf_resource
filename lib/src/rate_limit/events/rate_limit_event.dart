import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_lang/lang.dart';

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