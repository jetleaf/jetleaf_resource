import 'package:jetleaf_lang/lang.dart';

import 'rate_limit_metrics.dart';

/// {@template rate_limit_metrics_impl}
/// Concrete implementation of [RateLimitMetrics] that tracks operational
/// statistics for a specific rate-limited resource or bucket.
///
/// This class maintains:
/// - Counts of allowed requests per identifier
/// - Counts of denied requests per identifier
/// - Number of resets applied to the rate limit
/// - Timestamp of the last update
///
/// The metrics are organized per identifier, which can represent users,
/// API keys, IP addresses, or any other entity subject to rate limiting.
///
/// **Usage Example:**
/// ```dart
/// final metrics = SimpleRateLimitMetrics('apiRequests', ZoneId('UTC'));
/// metrics.recordAllowed('user:123');
/// metrics.recordDenied('user:124');
/// print(metrics.getAllowedRequests()); // 1
/// print(metrics.buildGraph());
/// ```
///
/// **Related Components:**
/// - [RateLimitStorage]: Provides the storage for the rate-limited requests.
/// - [RateLimitManager]: Uses metrics for reporting and monitoring.
/// - [RateLimitEvent]: Observers can use events to synchronize with these metrics.
/// {@endtemplate}
final class SimpleRateLimitMetrics implements RateLimitMetrics {
  /// The name of the rate-limited resource.
  final String _name;

  /// The time zone used for all timestamp computations.
  ZoneId zoneId;

  /// Map tracking allowed requests per identifier.
  final Map<Object, int> _allowed = {};

  /// Map tracking denied requests per identifier.
  final Map<Object, int> _denied = {};

  /// Counter for total resets applied.
  int _resets = 0;

  /// Timestamp of the last metrics update.
  ZonedDateTime _lastUpdated;

  /// {@macro rate_limit_metrics_impl}
  SimpleRateLimitMetrics(this._name, this.zoneId) : _lastUpdated = ZonedDateTime.now(zoneId);

  @override
  String getName() => _name;

  @override
  int getAllowedRequests() => _allowed.values.fold(0, (sum, v) => sum + v);

  @override
  int getDeniedRequests() => _denied.values.fold(0, (sum, v) => sum + v);

  @override
  int getResets() => _resets;

  @override
  ZonedDateTime getLastUpdated() => _lastUpdated;

  @override
  void recordAllowed(Object identifier) {
    _allowed.update(identifier, (v) => v + 1, ifAbsent: () => 1);
    _lastUpdated = ZonedDateTime.now(zoneId);
  }

  @override
  void recordDenied(Object identifier) {
    _denied.update(identifier, (v) => v + 1, ifAbsent: () => 1);
    _lastUpdated = ZonedDateTime.now(zoneId);
  }

  @override
  void recordReset(Object identifier) {
    _resets++;
    _lastUpdated = ZonedDateTime.now(zoneId);
  }

  @override
  void reset() {
    _allowed.clear();
    _denied.clear();
    _resets = 0;
    _lastUpdated = ZonedDateTime.now(zoneId);
  }

  @override
  int decrementAllowed(Object identifier) {
    final current = _allowed[identifier];
    if (current == null) {
      // nothing to decrement
      _lastUpdated = ZonedDateTime.now(zoneId);
      return 0;
    }

    final newVal = current > 0 ? current - 1 : 0;

    if (newVal > 0) {
      _allowed[identifier] = newVal;
    } else {
      // remove the key to avoid map growth for stale identifiers
      _allowed.remove(identifier);
    }

    _lastUpdated = ZonedDateTime.now(zoneId);
    return newVal;
  }

  @override
  int decrementDenied(Object identifier) {
    final current = _denied[identifier];
    if (current == null) {
      _lastUpdated = ZonedDateTime.now(zoneId);
      return 0;
    }

    final newVal = current > 0 ? current - 1 : 0;

    if (newVal > 0) {
      _denied[identifier] = newVal;
    } else {
      _denied.remove(identifier);
    }

    _lastUpdated = ZonedDateTime.now(zoneId);
    return newVal;
  }

  @override
  Map<String, Object> buildGraph() {
    return {
      'rate_limit_name': _name,
      'operations': {
        'allowed': Map<String, int>.from(_allowed.map((k, v) => MapEntry(k.toString(), v))),
        'denied': Map<String, int>.from(_denied.map((k, v) => MapEntry(k.toString(), v))),
        'resets': _resets,
      },
      'last_updated': _lastUpdated.toDateTime().toUtc().toIso8601String(),
    };
  }
}