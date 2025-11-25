import 'package:jetleaf_lang/lang.dart';

/// {@template jet_rate_limit_result}
/// Represents the outcome of a rate-limit check for a specific identifier.
///
/// Instances of [RateLimitResult] encapsulate all relevant information about
/// a rate-limiting evaluation, including the identifier, current request count,
/// remaining requests, window duration, reset time, and retry interval. This
/// class is typically returned by methods like [ConcurrentMapRateLimitStorage.tryConsume]
/// or [ConcurrentMapRateLimitStorage.getRemainingRequests].
///
/// ### Purpose
///
/// Provides a structured, immutable summary of the rate-limit state for an
/// identifier. Consumers can inspect this object to:
/// - Determine if a request is allowed or denied.
/// - Know how many requests remain in the current window.
/// - Determine when the window will reset and when the next allowed request can be made.
/// - Track the zone used for temporal calculations.
///
/// ### Key Properties
///
/// | Property | Description |
/// |----------|-------------|
/// | `identifier` | The entity (user, IP, or key) subject to rate limiting. |
/// | `limitName` | The canonical name of the rate-limit bucket or rule. |
/// | `currentCount` | Number of requests already made in the current window. |
/// | `remainingCount` | Number of requests remaining before hitting the limit. |
/// | `limit` | Maximum allowed requests in the window. |
/// | `window` | Duration of the rate-limit window. |
/// | `resetTime` | Exact time when the rate limit will reset. |
/// | `retryAfter` | Duration to wait before retrying if the limit is exceeded. |
/// | `zoneId` | Time zone used for all temporal calculations. |
///
/// ### Example
///
/// ```dart
/// final result = RateLimitResult(
///   identifier: 'user:42',
///   limitName: 'default',
///   currentCount: 5,
///   limit: 10,
///   window: Duration(minutes: 1),
///   resetTime: ZonedDateTime.now(ZoneId.UTC).plus(Duration(minutes: 1)),
///   retryAfter: Duration(seconds: 12),
///   zoneId: ZoneId.UTC,
/// );
///
/// if (result.remainingCount > 0) {
///   print('Request allowed. ${result.remainingCount} remaining.');
/// } else {
///   print('Rate limit exceeded. Retry after ${result.retryAfter.inSeconds}s.');
/// }
/// ```
///
/// {@endtemplate}
base class RateLimitResult {
  /// The entity that exceeded or is subject to the rate limit.
  final Object identifier;

  /// The name of the rate limit bucket or rule.
  final String limitName;

  /// The current number of requests in the window.
  final int currentCount;

  /// The current number of requests remaining in the window.
  final int remainingCount;

  /// The maximum allowed requests in the window.
  final int limit;

  /// The duration of the rate limit window.
  final Duration window;

  /// When the rate limit will reset.
  final ZonedDateTime resetTime;

  /// How long to wait before retrying.
  final Duration retryAfter;

  /// The time zone used for reset calculations.
  final ZoneId zoneId;

  /// Creates a new [RateLimitResult] instance.
  ///
  /// The [remainingCount] is computed automatically as `limit - currentCount`.
  RateLimitResult({
    required this.identifier,
    required this.limitName,
    required this.currentCount,
    required this.limit,
    required this.window,
    required this.resetTime,
    required this.retryAfter,
    required this.zoneId,
  }) : remainingCount = limit - currentCount;

  /// {@template rate_limit_entry_allowed}
  /// Indicates whether the current request is allowed under the rate limit.
  ///
  /// Returns `true` if the number of requests recorded for the associated
  /// identifier is less than the configured [limit]. Otherwise, returns `false`,
  /// indicating that the rate limit has been exceeded.
  ///
  /// ### Usage Example
  /// ```dart
  /// final entry = await storage.get('user:42');
  /// if (entry?.allowed ?? false) {
  ///   print('Request is allowed');
  /// } else {
  ///   print('Rate limit exceeded');
  /// }
  /// ```
  ///
  /// ### Notes
  /// - This property is **derived** from [currentCount] and [limit].
  /// - It does **not** increment the counter; use [recordRequest] to update counts.
  /// {@endtemplate}
  bool get allowed => currentCount < limit;
}