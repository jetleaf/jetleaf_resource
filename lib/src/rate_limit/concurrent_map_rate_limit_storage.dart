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

import 'dart:async';
import 'dart:math' as math;

import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_core/core.dart';
import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_logging/logging.dart';
import 'package:jetleaf_pod/pod.dart';

import '../exceptions.dart';
import '../resource.dart';
import 'rate_limit.dart';
import 'rate_limit_configuration.dart';

/// {@template concurrent_map_rate_limit_resource}
/// A thread-safe in-memory resource for storing rate limit entries.
///
/// This implementation uses a `HashMap<Object, RateLimitEntry>` as the underlying
/// storage mechanism. Each key represents a unique identifier (e.g., user ID, API key),
/// and each value is a [RateLimitEntry] that tracks usage counts, timestamps,
/// and reset information.
///
/// This class implements [Resource], making it compatible with JetLeaf's
/// resource and pod management system.
///
/// ### Behavior
///
/// - Stores and retrieves [RateLimitEntry] instances in memory.
/// - Keys are arbitrary objects but typically strings or integers.
/// - Designed for fast, concurrent access within a single application instance.
/// - Not distributed; for clustered environments, a distributed rate limit storage
///   should be used instead.
///
/// ### Example
///
/// ```dart
/// final storage = ConcurrentMapRateLimitResource();
/// storage['user:123'] = RateLimitEntryImpl();
/// final entry = storage['user:123'];
/// ```
///
/// ### Related Components
///
/// - [RateLimitEntry]: Represents individual rate limit data for a key.
/// - [Resource]: Base interface for JetLeaf resources.
/// {@endtemplate}
final class ConcurrentMapRateLimitResource extends HashMap<Object, Map<String, _RateLimitEntry>> implements Resource {}

/// {@template jet_concurrent_map_rate_limit}
/// A thread-safe, in-memory rate-limit storage implementation backed by a
/// concurrent [ConcurrentMapRateLimitResource].
///
/// The [ConcurrentMapRateLimitStorage] provides a simple yet configurable
/// mechanism to enforce rate-limiting policies per identifier and window.
/// It integrates with JetLeaf's core rate-limiting infrastructure, supports
/// configurable TTLs, event emission, and runtime metrics collection.
///
/// ### Purpose
///
/// Designed as the **default in-memory rate-limit provider** within the JetLeaf
/// rate-limiting subsystem, this implementation balances concurrency and
/// observability. Applications can quickly check, record, and enforce request
/// limits while maintaining operational metrics and event hooks.
///
/// ### Key Responsibilities
///
/// - Store rate-limit entries in an in-memory [_store] keyed by identifier.
/// - Support dynamic configuration via [ApplicationContext] environment properties.
/// - Enforce request limits per time window (TTL-based sliding or fixed windows).
/// - Track request counts, allowed/denied requests, and resets via [_metrics].
/// - Optionally emit JetLeaf [RateLimitEvent]s for monitoring and auditing.
///
/// ### Configuration
///
/// The storage automatically resolves runtime configuration from
/// [RateLimitConfiguration] keys at context initialization:
///
/// | Property Key | Description | Default |
/// |---------------|--------------|---------|
/// | `RateLimitConfiguration.TIMEZONE` | Zone identifier used for temporal computations | `UTC` |
/// | `RateLimitConfiguration.ENABLE_METRICS` | Enables metrics tracking via [RateLimitMetrics] | `true` |
/// | `RateLimitConfiguration.ENABLE_EVENTS` | Enables rate-limit event emission | `true` |
///
/// ### Lifecycle
///
/// 1. Upon startup, [setApplicationContext] loads environment configuration.
/// 2. The storage becomes operational with defaults or environment overrides.
/// 3. During runtime, operations like [tryConsume], [recordRequest], and [invalidate]
///    maintain both data integrity and metrics/event synchronization.
/// 4. Calls to [clear] or [reset] safely purge entries.
///
/// ### Related Components
///
/// - [RateLimitStorage]: Base interface defining core rate-limit operations.
/// - [ConfigurableRateLimitStorage]: Supports runtime configuration hooks.
/// - [RateLimitMetrics]: Used to record operational statistics.
/// - [RateLimitEvent]: Framework-level rate-limit event abstraction.
/// - [ApplicationContext]: Provides environment and event-publishing services.
///
/// ### Example
///
/// ```dart
/// final rateLimit = ConcurrentMapRateLimitStorage();
/// rateLimit.setApplicationContext(appContext);
///
/// final allowed = await rateLimit.isAllowed('user:42', 100, Duration(minutes: 1));
/// if (allowed) {
///   await rateLimit.recordRequest('user:42', Duration(minutes: 1));
/// } else {
///   final retryAfter = await rateLimit.getRetryAfter('user:42', Duration(minutes: 1));
///   print('Rate limit exceeded, retry after $retryAfter');
/// }
///
/// print('Remaining requests: ${await rateLimit.getRemainingRequests('user:42', 100, Duration(minutes: 1))}');
/// ```
///
/// ### Notes
///
/// - This rate-limit storage is **non-distributed** and suitable for single-node deployments.
/// - All operations are asynchronous to integrate with JetLeaf’s reactive event model.
/// - Expiration and resets are evaluated lazily during [tryConsume], [recordRequest], and [invalidate] calls.
///
/// {@endtemplate}
final class ConcurrentMapRateLimitStorage implements RateLimitStorage, ConfigurableRateLimitStorage, ApplicationContextAware, SmartInitializingSingleton {
  // ---------------------------------------------------------------------------
  // Static Constants
  // ---------------------------------------------------------------------------

  /// The canonical rate-limit name associated with this implementation.
  ///
  /// Used in emitted [RateLimitEvent]s, metrics tracking, and manager registration.
  static final String _DEFAULT_RATE_LIMIT_NAME = "default";

  // ---------------------------------------------------------------------------
  // Dependencies & Context
  // ---------------------------------------------------------------------------

  /// Reference to the owning [ApplicationContext].
  ///
  /// The context provides access to environment configuration and the
  /// event-publishing infrastructure. It is assigned during [setApplicationContext].
  late final ApplicationContext _applicationContext;

  // ---------------------------------------------------------------------------
  // Internal State and Configuration
  // ---------------------------------------------------------------------------

  /// Internal in-memory storage backing the rate-limit.
  ///
  /// Keys are arbitrary [Object] instances, and values are wrapped as [RateLimitEntry]
  /// objects to track metadata such as TTL and access timestamps.
  ///
  /// Modifications to this map are synchronized via the event loop; explicit
  /// locks are not required under Dart’s single-threaded model.
  final ConcurrentMapRateLimitResource _store = ConcurrentMapRateLimitResource();

  /// Indicates whether metrics collection is enabled for this rate-limit instance.
  ///
  /// When true, operations such as [get], [clear], and [invalidate] record activity
  /// in the [_metrics] collector.
  bool _metricsEnabled = true;

  /// Indicates whether rate-limit event emission is enabled.
  ///
  /// When true, rate-limit lifecycle events (get, clear)
  /// are asynchronously published to the [ApplicationContext] for observability.
  bool _eventEnabled = true;

  /// Metrics tracker instance for this rate-limit.
  ///
  /// Defaults to a [_RateLimitMetrics] implementation configured with the rate-limit name.
  /// Tracks hit rates, eviction counts, and other operational statistics.
  late _RateLimitMetrics _metrics;

  /// Zone identifier used for all temporal and TTL computations.
  ///
  /// Defaults to [ZoneId.UTC] unless overridden through configuration or
  /// [setZoneId]. Ensures consistent behavior across time zones.
  ZoneId _zoneId = ZoneId.UTC;

  /// The canonical name identifying this rate-limit or resource within the current
  /// JetLeaf context.
  ///
  /// This name is typically used for lookup and registration within the
  /// [RateLimitManager] or [PodFactory]. It must be unique across all rate-limits
  /// registered in the same namespace.
  String _name;

  /// {@macro jet_concurrent_map_rate_limit}
  ///
  /// Creates a new instance of [ConcurrentMapRateLimitStorage] with the default
  /// rate-limit name (`"default"`). The storage remains inactive until it is
  /// initialized via [setApplicationContext].
  ConcurrentMapRateLimitStorage() : this.named(_DEFAULT_RATE_LIMIT_NAME);

  /// {@macro jet_concurrent_map_rate_limit}
  ///
  /// Creates a new [ConcurrentMapRateLimitStorage] instance with a custom
  /// rate-limit [name]. This constructor allows explicitly naming the
  /// in-memory rate-limit instance, enabling better organization and observability
  /// when multiple rate-limit storages are registered within the same
  /// application context or represent distinct resources.
  ///
  /// A corresponding [_RateLimitMetrics] instance is automatically initialized
  /// to monitor rate-limit statistics for the given [name]. The storage remains
  /// inactive until it is initialized via [setApplicationContext].
  ConcurrentMapRateLimitStorage.named(String name) : _name = name {
    _metrics = _RateLimitMetrics(_DEFAULT_RATE_LIMIT_NAME, _zoneId);
  }

  // ---------------------------------------------------------------------------
  // Helper: Event emitter
  // ---------------------------------------------------------------------------

  /// Publish a [RateLimitEvent] to the configured [ApplicationContext] if events are enabled.
  ///
  /// This internal helper:
  /// - Guards emission using the [_eventEnabled] flag to avoid unnecessary work.
  /// - Asynchronously publishes the event via [_applicationContext.publishEvent].
  /// - Keeps event emission decoupled from core logic so that tests can disable
  ///   or replace event handling without modifying operational code paths.
  ///
  /// Note: The method intentionally swallows neither exceptions nor returns a value;
  /// any exceptions thrown by the application context will propagate to callers.
  Future<void> _emitEvent(RateLimitEvent event) async {
    if (_eventEnabled) {
      await _applicationContext.publishEvent(event);
    }
  }

  @override
  FutureOr<void> clear() async {
    return synchronizedAsync(_store, () async {
      // capture snapshot for events
      final snapshotKeys = _store.keys.toList(growable: false);
      final snapshotCounts = <Object, int>{};
      for (final key in snapshotKeys) {
        final inner = _store[key]!;
        var tot = 0;
        inner.forEach((_, entry) => tot += entry.getCount());
        snapshotCounts[key] = tot;
      }

      _store.clear();

      // emit events with per-identifier counts (not total for every event)
      for (final k in snapshotKeys) {
        if (_eventEnabled) _emitEvent(RateLimitClearEvent(k, _name, snapshotCounts[k] ?? 0, DateTime.now().toUtc()));
      }

      _metrics.reset();
    });
  }
  
  @override
  List<Object?> equalizedProperties() => [runtimeType, _name];
  
  @override
  RateLimitMetrics getMetrics() => _metrics;
  
  @override
  String getName() => _name;
  
  @override
  String getPackageName() => PackageNames.RESOURCE;

  /// Generates a window key based on the duration.
  String _getWindowKey(Duration window) => 'window_${window.inSeconds}';

  /// Gets or creates rate limit data for an identifier and window.
  _RateLimitEntry _getOrCreateData(Object identifier, String windowKey, Duration window) {
    final identifierData = _store.putIfAbsent(identifier, () => {});
    return identifierData.putIfAbsent(windowKey, () => _RateLimitEntry(windowKey, window, _zoneId));
  }
  
  @override
  FutureOr<int> getRemainingRequests(Object identifier, int limit, Duration window) async {
    final cnt = await getRequestCount(identifier, window);
    final remaining = math.max(0, limit - cnt);
    return remaining;
  }
  
  @override
  FutureOr<int> getRequestCount(Object identifier, Duration window) async {
    final windowKey = _getWindowKey(window);

    return synchronizedAsync(_store, () {
      final entry = _store[identifier]?[windowKey];
      if (entry == null) return 0;

      if (entry.isExpired()) {
        return 0;
      }

      return entry.getCount();
    });
  }
  
  @override
  FutureOr<DateTime?> getResetTime(Object identifier, Duration window) async {
    final windowKey = _getWindowKey(window);
    return synchronizedAsync(_store, () {
      final entry = _store[identifier]?[windowKey];

      if (entry == null) {
        return null;
      }

      if (entry.isExpired()) {
        return ZonedDateTime.now(_zoneId).toDateTime();
      }

      return entry.getResetTime().toDateTime();
    });
  }
  
  @override
  Resource getResource() => _store;
  
  @override
  FutureOr<ZonedDateTime?> getRetryAfter(Object identifier, Duration window) async {
    final windowKey = _getWindowKey(window);

    return synchronizedAsync(_store, () {
      final entry = _store[identifier]?[windowKey];
      if (entry == null) {
        return null;
      }

      if (!entry.isExpired()) {
        return entry.getResetTime();
      }

      return null;
    });
  }
  
  @override
  FutureOr<void> invalidate() async {
    return synchronizedAsync(_store, () async {
      final toRemoveOuter = <Object, List<String>>{};
      _store.forEach((outer, inner) {
        final expired = <String>[];
        inner.forEach((innerKey, entry) {
          if (entry.isExpired()) expired.add(innerKey);
        });
        if (expired.isNotEmpty) toRemoveOuter[outer] = expired;
      });

      for (final outer in toRemoveOuter.keys) {
        final innerKeys = toRemoveOuter[outer]!;
        for (final innerKey in innerKeys) {
          final removed = _store[outer]?.remove(innerKey);
          if (removed != null) {
            if (_metricsEnabled) _metrics.recordReset(outer);
            if (_eventEnabled) _emitEvent(RateLimitResetEvent(outer, _name, removed.getResetTime().toDateTime()));
          }
        }
        if (_store[outer]?.isEmpty ?? false) _store.remove(outer);
      }
    });
  }
  
  @override
  FutureOr<RateLimitResult> tryConsume(Object identifier, int limit, Duration window) async {
    final windowKey = _getWindowKey(window);

    return synchronizedAsync(_store, () async {
      final entry = _getOrCreateData(identifier, windowKey, window);

      // Expire/reset if needed
      if (entry.isExpired()) {
        entry.reset();
        if (_metricsEnabled) _metrics.recordReset(identifier);
        if (_eventEnabled) {
          await _emitEvent(RateLimitResetEvent(identifier, _name, entry.getResetTime().toDateTime()));
        }
      }

      final nowZdt = ZonedDateTime.now(_zoneId);
      final resetZdt = entry.getResetTime(); // ZonedDateTime

      if (entry.getCount() < limit) {
        // Allow: increment and return allowed result
        entry.increment();

        if (_metricsEnabled) _metrics.recordAllowed(identifier);
        if (_eventEnabled) {
          await _emitEvent(RateLimitAllowedEvent(identifier, _name, nowZdt.toDateTime()));
        }

        // Show currentCount capped at limit so remainingCount stays >= 0
        final currentCount = math.min(entry.getCount(), limit);

        return RateLimitResult(
          identifier: identifier,
          limitName: _name,
          currentCount: currentCount,
          limit: limit,
          window: window,
          resetTime: resetZdt,
          // allowed -> retryAfter is zero
          retryAfter: Duration.zero,
          zoneId: _zoneId,
        );
      } else {
        // Denied: record denied, return result with retryAfter
        if (_metricsEnabled) _metrics.recordDenied(identifier);

        // Compute retryAfter duration (non-negative)
        final retryAfterDur = resetZdt.toDateTime().difference(nowZdt.toDateTime());
        final retryAfter = retryAfterDur.isNegative ? Duration.zero : retryAfterDur;

        if (_eventEnabled) {
          // your Denied event previously accepted a DateTime; send absolute retryAt time
          final retryAt = nowZdt.toDateTime().add(retryAfter);
          await _emitEvent(RateLimitDeniedEvent(identifier, _name, retryAt));
        }

        // Cap the returned currentCount at limit to keep remainingCount >= 0
        final currentCount = math.min(entry.getCount(), limit);

        return RateLimitResult(
          identifier: identifier,
          limitName: _name,
          currentCount: currentCount,
          limit: limit,
          window: window,
          resetTime: resetZdt,
          retryAfter: retryAfter,
          zoneId: _zoneId,
        );
      }
    });
  }
  
  @override
  Future<void> onSingletonReady() async {
    final podFactory = _applicationContext.getPodFactory();

    // Discover and apply all RateLimitConfigurer pods
    final configurer = Class<RateLimitConfigurer>(null, PackageNames.CORE);
    final configurerMap = await podFactory.getPodsOf(configurer, allowEagerInit: true);

    if (configurerMap.isNotEmpty) {
      final configurers = List<RateLimitConfigurer>.from(configurerMap.values);
      AnnotationAwareOrderComparator.sort(configurers);

      for (final configurer in configurers) {
        configurer.configure(_name, this);
      }
    } else {}
  }
  
  @override
  FutureOr<void> recordRequest(Object identifier, Duration window) async {
    final windowKey = _getWindowKey(window);

    return synchronizedAsync(_store, () async {
      final entry = _getOrCreateData(identifier, windowKey, window);

      if (entry.isExpired()) {
        entry.reset();
        if (_metricsEnabled) {
          _metrics.recordReset(identifier);
        }

        if (_eventEnabled) {
          _emitEvent(RateLimitResetEvent(identifier, _name, entry.getResetTime().toDateTime()));
        }
      }

      entry.increment();

      if (_metricsEnabled) {
        _metrics.recordAllowed(identifier);
      }
    });
  }
  
  @override
  FutureOr<void> reset(Object identifier) async {
    return synchronizedAsync(_store, () async => _store.remove(identifier));
  }
  
  @override
  void setApplicationContext(ApplicationContext applicationContext) {
    _applicationContext = applicationContext;

    final env = applicationContext.getEnvironment();

    final zoneId = env.getProperty(RateLimitConfiguration.TIMEZONE) ?? env.getProperty(AbstractApplicationContext.APPLICATION_TIMEZONE);
    if (zoneId != null) {
      _zoneId = ZoneId.of(zoneId);
      _metrics._zoneId = _zoneId;
    }

    final metricsEnabled = env.getPropertyAs<bool>(RateLimitConfiguration.ENABLE_METRICS, Class<bool>());
    if (metricsEnabled != null) {
      _metricsEnabled = metricsEnabled;
    }

    final eventEnabled = env.getPropertyAs<bool>(RateLimitConfiguration.ENABLE_EVENTS, Class<bool>());
    if (eventEnabled != null) {
      _eventEnabled = eventEnabled;
    }
  }
  
  @override
  void setZoneId(String zone) {
    _zoneId = ZoneId.of(zone);
    _metrics._zoneId = _zoneId;
  }

  /// {@macro tunable_rate_limit_storage}
  ///
  /// Retrieves the currently active [ZoneId] used by this storage for
  /// all time-sensitive computations such as:
  /// - Window reset time calculations
  /// - Expiration of entries
  /// - Logging and monitoring timestamps
  ///
  /// The returned [ZoneId] may be `null` if no zone has been explicitly
  /// configured. In that case, the system default time zone is used.
  ///
  /// **Implementation notes:**
  /// - The zone affects all entries tracked by this storage; changing it may
  ///   impact expiration calculations and reporting.
  /// - Implementations should ensure that retrieved timestamps and reset
  ///   times respect the configured zone.
  ///
  /// **Example:**
  /// ```dart
  /// final zone = rateLimitStorage.getZoneId();
  /// if (zone != null) {
  ///   print('Current rate-limit zone: ${zone.id}');
  /// } else {
  ///   print('Using system default zone');
  /// }
  /// ```
  ZoneId? getZoneId() => _zoneId;
}

/// {@template jet_rollback_capable_rate_limit_storage}
/// An in-memory rate-limit storage variant that supports **best-effort rollback** of
/// a prior successful consume.
///
/// This storage is useful when performing `tryConsume` operations across multiple
/// storages and needing to undo earlier increments if a later storage denies
/// the request. Rollback is **best-effort**: it only decrements counters if entries
/// exist and are not expired, and silently ignores failures.
///
/// ### Purpose
///
/// - Enable atomic-like behavior when consuming from multiple rate-limit storages.
/// - Provide a safe way to undo prior increments in scenarios where partial
///   consumption occurs.
/// - Maintain metrics consistency via [_metrics] if enabled.
///
/// ### Key Responsibilities
///
/// - Extend [ConcurrentMapRateLimitStorage] with rollback capability.
/// - Decrement counters for a specific identifier/window via [rollbackConsume].
/// - Remove expired or empty entries to maintain internal storage hygiene.
/// - Log rollback failures at DEBUG level without affecting the main flow.
///
/// ### Example
///
/// ```dart
/// final rollbackStorage = RollbackCapableConcurrentMapRateLimitStorage.named('default');
/// rollbackStorage.setApplicationContext(appContext);
///
/// // Attempt to consume across multiple storages
/// final allowedFirst = await storage1.isAllowed('user:42', 10, Duration(minutes: 1));
/// final allowedSecond = await storage2.isAllowed('user:42', 10, Duration(minutes: 1));
///
/// if (!allowedSecond) {
///   // Undo the first storage increment
///   await rollbackStorage.rollbackConsume('user:42', Duration(minutes: 1));
/// }
/// ```
///
/// ### Notes
///
/// - Rollback is **best-effort**: exceptions are logged at DEBUG level and do not
///   propagate.
/// - If the rate-limit entry is expired or missing, rollback silently does nothing.
/// - Metrics (_RateLimitMetrics) are adjusted if enabled.
///
/// {@endtemplate}
final class RollbackCapableRateLimitStorage extends ConcurrentMapRateLimitStorage {
  final Log _logger = LogFactory.getLog(RollbackCapableRateLimitStorage);

  /// {@macro jet_rollback_capable_rate_limit_storage}
  RollbackCapableRateLimitStorage.named(super.name) : super.named();

  /// {@macro jet_rollback_capable_rate_limit_storage}
  RollbackCapableRateLimitStorage() : super();

  /// Best-effort rollback: decrement the counter for the given [identifier] and [window].
  ///
  /// If an entry exists and is not expired, the count is decremented by 1.
  /// If the count reaches zero, the inner map is cleaned up to prevent memory leaks.
  ///
  /// **Behavior notes:**
  /// - Does nothing if no entry exists or the entry is expired.
  /// - Metrics are adjusted only if `_metricsEnabled` is true.
  /// - Exceptions are swallowed and logged at DEBUG level.
  FutureOr<void> rollbackConsume(Object identifier, Duration window) async {
    final windowKey = _getWindowKey(window);

    await synchronizedAsync(_store, () async {
      final inner = _store[identifier];
      if (inner == null) return;

      final entry = inner[windowKey];
      if (entry == null) return;

      // If expired, nothing to rollback
      if (entry.isExpired()) return;

      try {
        // decrement once (best-effort) and get the new count
        final concrete = entry;
        final newCount = concrete.decrement(); // should return the new count (>= 0)

        // adjust metrics only if enabled
        if (_metricsEnabled) {
          _metrics.decrementAllowed(identifier);
        }

        // if the count reached zero, remove the inner key and cleanup outer map
        if (newCount <= 0) {
          inner.remove(windowKey);
          if (inner.isEmpty) {
            _store.remove(identifier);
          }
        }
      } catch (e, st) {
        // Best-effort rollback: swallow exceptions but consider logging at DEBUG level.

        if (_logger.getIsDebugEnabled()) {
          _logger.debug('rollbackConsume failed for $identifier: $e', error: e, stacktrace: st);
        }
      }
    });
  }
}

/// {@template rate_limit_entry_impl}
/// Internal implementation of [RateLimitEntry] representing a single
/// rate limit tracking window for a specific key.
///
/// This class tracks the number of allowed requests, the start timestamp,
/// the reset time for the current window, and the associated time zone.
///
/// Each entry corresponds to one unique key/window combination and is used
/// internally by rate limit storages such as [ConcurrentMapRateLimitResource].
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
final class _RateLimitEntry with EqualsAndHashCode implements RateLimitEntry {
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
  _RateLimitEntry(this._windowKey, this._windowDuration, this._zoneId)
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

  /// For increasing the count size
  void increment() {
    _count++;
  }

   /// Return number of seconds until reset (>= 0).
  int secondsUntilReset() {
    final diff = _resetTime.toDateTime().difference(ZonedDateTime.now(_zoneId).toDateTime()).inSeconds;
    return diff < 0 ? 0 : diff;
  }


  /// Decrement the count by one if > 0; return the new count.
  /// This is best-effort (used for rollback).
  int decrement() {
    if (_count > 0) {
      _count--;
    }
    return _count;
  }

  @override
  List<Object?> equalizedProperties() => [_windowKey];
}

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
/// final metrics = _RateLimitMetrics('apiRequests', ZoneId('UTC'));
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
final class _RateLimitMetrics implements RateLimitMetrics {
  /// The name of the rate-limited resource.
  final String _name;

  /// The time zone used for all timestamp computations.
  ZoneId _zoneId;

  /// Map tracking allowed requests per identifier.
  final Map<Object, int> _allowed = {};

  /// Map tracking denied requests per identifier.
  final Map<Object, int> _denied = {};

  /// Counter for total resets applied.
  int _resets = 0;

  /// Timestamp of the last metrics update.
  ZonedDateTime _lastUpdated;

  /// {@macro rate_limit_metrics_impl}
  _RateLimitMetrics(this._name, this._zoneId) : _lastUpdated = ZonedDateTime.now(_zoneId);

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
    _lastUpdated = ZonedDateTime.now(_zoneId);
  }

  @override
  void recordDenied(Object identifier) {
    _denied.update(identifier, (v) => v + 1, ifAbsent: () => 1);
    _lastUpdated = ZonedDateTime.now(_zoneId);
  }

  @override
  void recordReset(Object identifier) {
    _resets++;
    _lastUpdated = ZonedDateTime.now(_zoneId);
  }

  @override
  void reset() {
    _allowed.clear();
    _denied.clear();
    _resets = 0;
    _lastUpdated = ZonedDateTime.now(_zoneId);
  }

  @override
  int decrementAllowed(Object identifier) {
    final current = _allowed[identifier];
    if (current == null) {
      // nothing to decrement
      _lastUpdated = ZonedDateTime.now(_zoneId);
      return 0;
    }

    final newVal = current > 0 ? current - 1 : 0;

    if (newVal > 0) {
      _allowed[identifier] = newVal;
    } else {
      // remove the key to avoid map growth for stale identifiers
      _allowed.remove(identifier);
    }

    _lastUpdated = ZonedDateTime.now(_zoneId);
    return newVal;
  }

  @override
  int decrementDenied(Object identifier) {
    final current = _denied[identifier];
    if (current == null) {
      _lastUpdated = ZonedDateTime.now(_zoneId);
      return 0;
    }

    final newVal = current > 0 ? current - 1 : 0;

    if (newVal > 0) {
      _denied[identifier] = newVal;
    } else {
      _denied.remove(identifier);
    }

    _lastUpdated = ZonedDateTime.now(_zoneId);
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