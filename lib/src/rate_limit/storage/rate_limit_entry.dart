import 'package:jetleaf_lang/lang.dart';

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