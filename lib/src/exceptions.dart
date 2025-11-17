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

import 'dart:math' as math;

import 'package:jetleaf_lang/lang.dart';

/// {@template cache_exception}
/// Represents a runtime exception that occurs during cache operations.
///
/// This exception is thrown whenever an error is encountered in cache
/// management, retrieval, insertion, eviction, or expiration processes.
///
/// Examples of scenarios that may trigger a [CacheException]:
/// - Attempting to access a cache key in a non-existent cache.
/// - Failure to put or update a value due to internal storage issues.
/// - Eviction policy conflicts or misconfigurations.
/// - TTL (time-to-live) or expiration-related errors.
///
/// This exception extends [RuntimeException], allowing it to be thrown
/// without being explicitly declared. It optionally supports:
/// - [cause]: The underlying exception that triggered this cache exception.
/// - [stackTrace]: The stack trace to aid in debugging.
/// {@endtemplate}
final class CacheException extends RuntimeException {
  /// Creates a new [CacheException].
  ///
  /// [message] describes the error in human-readable form.
  /// [cause] optionally captures the original exception that triggered this error.
  /// [stackTrace] optionally provides the stack trace for debugging purposes.
  CacheException(super.message, {super.cause, super.stackTrace});
}

/// {@template no_cache_found_exception}
/// Thrown when a requested cache entry cannot be found.
///
/// This exception extends [CacheException] and indicates that a specific
/// key was queried in the cache but no corresponding entry exists. It is
/// useful for distinguishing between general cache failures and missing
/// data scenarios.
///
/// Typical use cases include:
/// - Attempting to retrieve a value for a key that was never cached.
/// - Cache eviction or expiration removed the entry before access.
/// - Incorrect cache key or misconfigured caching strategy.
///
/// The exception provides the [key] that was not found, and optionally
/// supports a custom [message], [cause], and [stackTrace] for diagnostic
/// purposes.
///
/// {@endtemplate}
final class NoCacheFoundException extends CacheException {
  /// The cache key that was not found.
  final Object key;

  /// Creates a new [NoCacheFoundException].
  ///
  /// If [message] is not provided, a default descriptive message is generated
  /// including the missing [key]. Optionally, [cause] and [stackTrace] can be
  /// provided for full diagnostic context.
  ///
  /// Example:
  /// ```dart
  /// throw NoCacheFoundException(42);
  /// ```
  /// 
  /// {@macro no_cache_found_exception}
  NoCacheFoundException(this.key, {String? message, Object? cause, StackTrace? stackTrace}) : super(
    message ??
        'No cache entry found for key: $key. '
        'Ensure that this key was previously cached or that the caching strategy is correct.',
    cause: cause,
    stackTrace: stackTrace,
  );

  @override
  String toString() => 'NoCacheFoundException: Missing cache entry for key `$key`. Message: $message';
}

/// {@template no_rate_limit_found_exception}
/// Exception thrown when a requested rate-limit configuration or storage
/// cannot be found within the active [RateLimitManager] or resolver chain.
///
/// This typically indicates that a rate-limit rule or storage backend
/// associated with the specified [name] has not been registered or discovered
/// at runtime.
///
/// ### Typical Causes
/// - A rate-limit name requested via `RateLimitManager.getStorage()`
///   does not correspond to any known storage.
/// - The configuration provider or [RateLimitConfigurer] did not register
///   the expected rate-limit.
/// - Automatic creation is disabled via
///   `RateLimitConfiguration.AUTO_CREATE_WHEN_NOT_FOUND = false`.
///
/// ### Resolution
/// - Verify that the rate-limit name exists in your configuration.
/// - Ensure the [RateLimitConfigurer] or storage provider has registered
///   the name before `onReady()` completes.
/// - Enable automatic creation in the environment if fallback
///   in-memory storage is desired.
///
/// ### Example
/// ```dart
/// try {
///   final storage = await manager.getStorage('api-rate-limit');
///   if (storage == null) {
///     throw NoRateLimitFoundException.named('api-rate-limit');
///   }
/// } on NoRateLimitFoundException catch (e) {
///   logger.error(e.message);
/// }
/// ```
///
/// See also:
/// - [SimpleRateLimitManager.getStorage]
/// - [RateLimitConfiguration]
/// {@endtemplate}
final class NoRateLimitFoundException extends RuntimeException {
  /// The logical name or identifier of the missing rate limit.
  final String name;

  /// {@macro no_rate_limit_found_exception}
  ///
  /// Optionally includes a [cause] or [stackTrace] for deeper diagnostics.
  NoRateLimitFoundException(this.name, {Object? cause, StackTrace? stackTrace}) : super(
    'No rate limit configuration found for name: "$name". '
    'Ensure that a rate limit rule with this identifier is properly '
    'registered in your RateLimiter or configuration provider.',
    cause: cause,
    stackTrace: stackTrace,
  );

  /// Factory-style convenience constructor that creates a
  /// [NoRateLimitFoundException] using the given [name].
  ///
  /// ```dart
  /// throw NoRateLimitFoundException.named('login-attempts');
  /// ```
  factory NoRateLimitFoundException.named(String name) => NoRateLimitFoundException(name);

  @override
  String toString() => 'NoRateLimitFoundException(name: "$name", message: $message)';
}

/// {@template cache_capacity_exceeded_exception}
/// Exception thrown when a cache exceeds its configured capacity and no
/// eviction policy is available to free up space.
///
/// The [CacheCapacityExceededException] indicates that a cache implementation
/// (such as a [CacheManager] or [CacheStorage]) attempted to add a new entry
/// but reached the maximum entry limit (`maxEntries`) without an eviction
/// strategy configured to handle overflow.
///
/// ### When This Exception Occurs
///
/// - A cache entry insertion or update is attempted while the cache is already
///   full.
/// - The configured cache implementation does **not** provide an eviction
///   mechanism (e.g., LRU, LFU, FIFO) to automatically remove old entries.
/// - The cache has a strict `maxEntries` limit set by configuration or annotation.
///
/// ### Recommended Resolutions
///
/// - Configure an eviction policy via a `CacheEvictionPolicy` or `CacheManager`
///   configuration to handle overflow automatically.
/// - Increase the `maxEntries` limit in the cache configuration.
/// - Manually clear or prune the cache before inserting new data.
///
/// ### Example
///
/// ```dart
/// final cache = SimpleCache(name: 'userCache', maxEntries: 100);
///
/// try {
///   for (var i = 0; i < 200; i++) {
///     cache.put('key_$i', 'value_$i');
///   }
/// } on CacheCapacityExceededException catch (e) {
///   print('Cache "${e.cacheName}" exceeded capacity of ${e.maxEntries} entries.');
///   // → Consider freeing space or changing configuration.
/// }
/// ```
///
/// ### Related Components
///
/// - [CacheException] – Base exception for all cache-related errors.
/// - [CacheManager] – Responsible for enforcing capacity and eviction policies.
/// - [CacheStorage] – Underlying cache store that triggers this exception.
/// - [CacheEvictionPolicy] – Defines eviction strategies to prevent overflow.
///
/// {@endtemplate}
final class CacheCapacityExceededException extends CacheException {
  /// The name of the cache that exceeded its configured capacity.
  ///
  /// Used to identify which cache instance triggered the capacity error,
  /// particularly useful when multiple caches are managed under a shared
  /// [CacheManager] or distributed caching system.
  final String cacheName;

  /// The configured maximum number of entries for the cache.
  ///
  /// Represents the strict upper limit beyond which no additional cache entries
  /// can be stored without triggering eviction or this exception.
  final int maxEntries;

  /// Creates a [CacheCapacityExceededException] with detailed context.
  ///
  /// **Parameters:**
  /// - [cacheName]: The name of the cache that has exceeded its limit.
  /// - [maxEntries]: The configured maximum capacity for that cache.
  ///
  /// The message generated includes human-readable guidance for diagnosing
  /// and resolving the overflow.
  /// 
  /// {@macro cache_capacity_exceeded_exception}
  CacheCapacityExceededException(this.cacheName, this.maxEntries) : super(
    'Cache "$cacheName" exceeded its maximum capacity of $maxEntries entries '
    'and no eviction policy is configured to free space. '
    'Either define an eviction policy or increase the max entry limit.',
  );
}

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
final class RateLimitResult {
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

/// {@template rate_limit_exceeded_exception}
/// Exception thrown when a rate limit is exceeded.
///
/// This exception provides detailed information about the rate limit violation,
/// including the current count, remaining requests, reset time, and other
/// metadata that can be used by clients to handle the rate limit appropriately.
///
/// ### Properties
///
/// - [identifier]: The entity that exceeded the rate limit (user ID, IP, API key, etc.)
/// - [limitName]: The name of the rate limit bucket or rule that was violated
/// - [currentCount]: The current number of requests in the current window
/// - [limit]: The maximum allowed requests in the window
/// - [window]: The duration of the rate limit window
/// - [resetTime]: When the rate limit will reset and requests will be allowed again
/// - [retryAfter]: How long the client should wait before retrying
/// - [zoneId]: The time zone used for reset time calculations
///
/// ### Example Usage
///
/// ```dart
/// try {
///   await rateLimitStorage.recordRequest(userId, window);
/// } on RateLimitExceededException catch (e) {
///   // Return appropriate HTTP response
///   return Response(
///     statusCode: 429,
///     headers: {
///       'X-RateLimit-Limit': e.limit.toString(),
///       'X-RateLimit-Remaining': e.remaining.toString(),
///       'X-RateLimit-Reset': e.resetTime.millisecondsSinceEpoch.toString(),
///       'Retry-After': e.retryAfter.inSeconds.toString(),
///     },
///     body: jsonEncode({
///       'error': 'Rate limit exceeded',
///       'message': e.message,
///       'retry_after': e.retryAfter.inSeconds,
///     }),
///   );
/// }
/// ```
/// {@endtemplate}
final class RateLimitExceededException extends RateLimitResult with EqualsAndHashCode implements RuntimeException {
  /// {@macro rate_limit_exceeded_exception}
  RateLimitExceededException({
    required super.identifier,
    required super.limitName,
    required super.currentCount,
    required super.limit,
    required super.window,
    required super.resetTime,
    required super.retryAfter,
    required super.zoneId,
    String? message,
  });

  /// {@macro rate_limit_exceeded_exception}
  RateLimitExceededException.result(RateLimitResult result) : super(
    zoneId: result.zoneId,
    identifier: result.identifier,
    limitName: result.limitName,
    currentCount: result.currentCount,
    limit: result.limit,
    window: result.window,
    resetTime: result.resetTime,
    retryAfter: result.retryAfter,
  );

  /// The number of remaining requests in the current window.
  ///
  /// This is a calculated property: `limit - currentCount`, clamped to 0.
  int get remaining => math.max(0, limit - currentCount);

  /// The ratio of used requests to the limit (0.0 to 1.0).
  double get usageRatio => currentCount / limit;

  /// Whether the rate limit has been completely exhausted (remaining == 0).
  bool get isFullyExhausted => remaining == 0;

  /// Builds a default exception message with rate limit details.
  String _buildDefaultMessage({
    required Object identifier,
    required String limitName,
    required int currentCount,
    required int limit,
    required Duration window,
    required Duration retryAfter,
  }) {
    final windowDesc = _describeDuration(window);
    final retryDesc = _describeDuration(retryAfter);
    
    return 'Rate limit exceeded for "$identifier" on "$limitName": '
        '$currentCount/$limit requests per $windowDesc. '
        'Retry after $retryDesc.';
  }

  /// Converts a duration to a human-readable string.
  String _describeDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    } else {
      return '${duration.inSeconds} second${duration.inSeconds > 1 ? 's' : ''}';
    }
  }

  /// Converts the exception to a map for serialization.
  ///
  /// Useful for API responses or logging systems that expect structured data.
  Map<String, dynamic> toMap() {
    return {
      'type': runtimeType.toString(),
      'identifier': identifier.toString(),
      'limit_name': limitName,
      'current_count': currentCount,
      'limit': limit,
      'remaining': remaining,
      'usage_ratio': usageRatio,
      'window_seconds': window.inSeconds,
      'reset_time': resetTime.toDateTime().toIso8601String(),
      'retry_after_seconds': retryAfter.inSeconds,
      'zone_id': zoneId.id,
      'message': toString(),
      'is_fully_exhausted': isFullyExhausted,
    };
  }

  /// Creates headers for HTTP responses.
  ///
  /// Returns standard rate limit headers that can be used in HTTP 429 responses.
  Map<String, String> toHttpHeaders() {
    return {
      'X-RateLimit-Limit': limit.toString(),
      'X-RateLimit-Remaining': remaining.toString(),
      'X-RateLimit-Reset': resetTime.toDateTime().millisecondsSinceEpoch.toString(),
      'Retry-After': retryAfter.inSeconds.toString(),
      'X-RateLimit-Name': limitName,
      'X-RateLimit-Window': window.inSeconds.toString(),
    };
  }

  @override
  String toString() {
    return 'RateLimitExceededException: $message';
  }

  @override
  List<Object?> equalizedProperties() => [
    runtimeType,
    identifier,
    limitName,
    currentCount,
    limit,
    window,
    resetTime,
    retryAfter,
    zoneId,
  ];
  
  @override
  Object? get cause => getCause();
  
  @override
  Object getCause() => RuntimeException(message);
  
  @override
  String getMessage() => _buildDefaultMessage(
    identifier: identifier,
    limitName: limitName,
    currentCount: currentCount,
    limit: limit,
    window: window,
    retryAfter: retryAfter,
  );
  
  @override
  StackTrace getStackTrace() => StackTrace.current;
  
  @override
  String get message => getMessage();
  
  @override
  StackTrace get stackTrace => getStackTrace();
}