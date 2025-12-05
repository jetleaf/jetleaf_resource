import 'package:jetleaf_lang/lang.dart';

import 'rate_limit_entry.dart';

/// {@template rate_limit_entry_impl}
/// Internal implementation of [RateLimitEntry] representing a single
/// rate limit tracking window for a specific key.
///
/// This class tracks the number of allowed requests, the start timestamp,
/// the reset time for the current window, and the associated time zone.
///
/// Each entry corresponds to one unique key/window combination and is used
/// internally by rate limit storages such as [RateLimitResource].
///
/// ### Behavior
///
/// - Counts the number of requests within a defined time window.
/// - Automatically tracks expiration based on the [_windowDuration].
/// - Supports resetting the count and window timestamp when the limit window expires.
/// - Provides methods for querying current counts, timestamps, and reset times.
///
/// ### Example
///
/// ```dart
/// final entry = _RateLimitEntry('user:123', Duration(minutes: 1), ZoneId.UTC);
/// print(entry.getCount()); // 0
/// entry.reset(); // resets count and moves the reset time forward
/// ```
/// {@endtemplate}
final class SimpleRateLimitEntry with EqualsAndHashCode implements RateLimitEntry {
  /// The current count of requests within the window.
  int _count = 0;

  /// The unique key associated with this rate limit window.
  final String _windowKey;

  /// The time zone used for all timestamp calculations.
  final ZoneId _zoneId;

  /// The duration of the rate limit window.
  final Duration _windowDuration;

  /// The timestamp when this entry was created.
  ZonedDateTime _timeStamp;

  /// The timestamp when the current window will reset.
  ZonedDateTime _resetTime;

  /// {@macro rate_limit_entry_impl}
  SimpleRateLimitEntry(this._windowKey, this._windowDuration, this._zoneId)
    : _timeStamp = ZonedDateTime.now(_zoneId), _resetTime = ZonedDateTime.now(_zoneId).plus(_windowDuration);

  @override
  int getCount() => _count;

  @override
  ZonedDateTime getResetTime() => _resetTime;

  @override
  ZonedDateTime getRetryAfter() {
    final now = ZonedDateTime.now(_zoneId);

    if (now.isAfter(_resetTime)) {
      return now;
    }

    return _resetTime;
  }

  @override
  ZonedDateTime getTimeStamp() => _timeStamp;

  @override
  String getWindowKey() => _windowKey;

  @override
  bool isExpired() => ZonedDateTime.now(_zoneId).isAfter(_resetTime);

  @override
  Duration getWindowDuration() => _windowDuration;

  @override
  void reset() {
    _count = 0;

    final now = ZonedDateTime.now(_zoneId);

    _timeStamp = now;
    _resetTime = now.plus(_windowDuration);
  }

  @override
  void increment() {
    _count++;
  }

  @override
  int secondsUntilReset() {
    final diff = _resetTime.toDateTime().difference(ZonedDateTime.now(_zoneId).toDateTime()).inSeconds;
    return diff < 0 ? 0 : diff;
  }


  @override
  int decrement() {
    if (_count > 0) {
      _count--;
    }
    return _count;
  }

  @override
  List<Object?> equalizedProperties() => [_windowKey];
}