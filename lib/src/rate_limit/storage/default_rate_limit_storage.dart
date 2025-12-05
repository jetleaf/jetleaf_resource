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
import 'package:jetleaf_pod/pod.dart';
import 'package:meta/meta.dart';

import 'simple_rate_limit_entry.dart';
import '../events/rate_limit_allowed_event.dart';
import '../events/rate_limit_clear_event.dart';
import '../events/rate_limit_denied_event.dart';
import '../events/rate_limit_event.dart';
import '../events/rate_limit_reset_event.dart';
import '../metrics/rate_limit_metrics.dart';
import '../metrics/simple_rate_limit_metrics.dart';
import '../../config/rate_limit_configuration.dart';
import 'rate_limit_entry.dart';
import '../rate_limit_configurer.dart';
import '../rate_limit_result.dart';
import 'configurable_rate_limit_storage.dart';
import 'rate_limit_resource.dart';
import 'rate_limit_storage.dart';

/// {@template jet_concurrent_map_rate_limit}
/// A thread-safe, in-memory rate-limit storage implementation backed by a
/// concurrent [RateLimitResource].
///
/// The [DefaultRateLimitStorage] provides a simple yet configurable
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
/// - Store rate-limit entries in an in-memory [store] keyed by identifier.
/// - Support dynamic configuration via [ApplicationContext] environment properties.
/// - Enforce request limits per time window (TTL-based sliding or fixed windows).
/// - Track request counts, allowed/denied requests, and resets via [metrics].
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
base class DefaultRateLimitStorage implements RateLimitStorage, ConfigurableRateLimitStorage, ApplicationContextAware, SmartInitializingSingleton {
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
  @protected
  final RateLimitResource store = RateLimitResource();

  /// Indicates whether metrics collection is enabled for this rate-limit instance.
  ///
  /// When true, operations such as [get], [clear], and [invalidate] record activity
  /// in the [metrics] collector.
  @protected
  bool metricsEnabled = true;

  /// Indicates whether rate-limit event emission is enabled.
  ///
  /// When true, rate-limit lifecycle events (get, clear)
  /// are asynchronously published to the [ApplicationContext] for observability.
  @protected
  bool eventEnabled = true;

  /// Metrics tracker instance for this rate-limit.
  ///
  /// Defaults to a [SimpleRateLimitMetrics] implementation configured with the rate-limit name.
  /// Tracks hit rates, eviction counts, and other operational statistics.
  @protected
  late SimpleRateLimitMetrics metrics;

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
  /// Creates a new instance of [DefaultRateLimitStorage] with the default
  /// rate-limit name (`"default"`). The storage remains inactive until it is
  /// initialized via [setApplicationContext].
  DefaultRateLimitStorage() : this.named(_DEFAULT_RATE_LIMIT_NAME);

  /// {@macro jet_concurrent_map_rate_limit}
  ///
  /// Creates a new [DefaultRateLimitStorage] instance with a custom
  /// rate-limit [name]. This constructor allows explicitly naming the
  /// in-memory rate-limit instance, enabling better organization and observability
  /// when multiple rate-limit storages are registered within the same
  /// application context or represent distinct resources.
  ///
  /// A corresponding [SimpleRateLimitMetrics] instance is automatically initialized
  /// to monitor rate-limit statistics for the given [name]. The storage remains
  /// inactive until it is initialized via [setApplicationContext].
  DefaultRateLimitStorage.named(String name) : _name = name {
    metrics = SimpleRateLimitMetrics(_DEFAULT_RATE_LIMIT_NAME, _zoneId);
  }

  @override
  FutureOr<void> clear() async {
    return synchronizedAsync(store, () async {
      final snapshotKeys = store.keys.toList(growable: false);
      final snapshotCounts = <Object, int>{};

      for (final key in snapshotKeys) {
        snapshotCounts[key] = store[key]?.getCount() ?? 0;
      }

      store.clear();

      for (final key in snapshotKeys) {
        if (eventEnabled) {
          _emitEvent(RateLimitClearEvent(
            extractIdentifier(key), 
            _name, 
            snapshotCounts[key] ?? 0, 
            DateTime.now().toUtc()
          ));
        }
      }

      metrics.reset();
    });
  }
  
  @override
  List<Object?> equalizedProperties() => [runtimeType, _name];
  
  @override
  RateLimitMetrics getMetrics() => metrics;
  
  @override
  String getName() => _name;
  
  @override
  String getPackageName() => PackageNames.RESOURCE;
  
  @override
  FutureOr<int> getRemainingRequests(Object identifier, int limit, Duration window) async {
    final cnt = await getRequestCount(identifier, window);
    final remaining = math.max(0, limit - cnt);
    return remaining;
  }
  
  @override
  FutureOr<int> getRequestCount(Object identifier, Duration window) async {
    final windowKey = getWindowKey(window);
    final key = mergeKey(identifier, windowKey);

    return synchronizedAsync(store, () {
      final entry = store[key];
      if (entry == null || entry.isExpired()) return 0;
      return entry.getCount();
    });
  }
  
  @override
  FutureOr<DateTime?> getResetTime(Object identifier, Duration window) async {
    final windowKey = getWindowKey(window);
    final key = mergeKey(identifier, windowKey);

    return synchronizedAsync(store, () {
      final entry = store[key];
      if (entry == null) return null;
      if (entry.isExpired()) return ZonedDateTime.now(_zoneId).toDateTime();
      return entry.getResetTime().toDateTime();
    });
  }
  
  @override
  Resource<Object, RateLimitEntry> getResource() => store;
  
  @override
  FutureOr<ZonedDateTime?> getRetryAfter(Object identifier, Duration window) async {
    final windowKey = getWindowKey(window);
    final key = mergeKey(identifier, windowKey);

    return synchronizedAsync(store, () {
      final entry = store[key];
      if (entry == null || entry.isExpired()) return null;
      return entry.getResetTime();
    });
  }
  
  @override
  FutureOr<void> invalidate() async {
    return synchronizedAsync(store, () async {
      final toRemove = <Object>[];

      store.forEach((key, entry) {
        if (entry.isExpired()) toRemove.add(key);
      });

      for (final key in toRemove) {
        final removed = store.remove(key);
        if (removed != null) {
          if (metricsEnabled) {
            metrics.recordReset(extractIdentifier(key));
          }

          if (eventEnabled) {
            _emitEvent(RateLimitResetEvent(extractIdentifier(key), _name, removed.getResetTime().toDateTime()));
          }
        }
      }
    });
  }
  
  @override
  FutureOr<RateLimitResult> tryConsume(Object identifier, int limit, Duration window) async {
    final windowKey = getWindowKey(window);

    return synchronizedAsync(store, () async {
      final entry = getOrCreate(identifier, windowKey, window);

      // Expire/reset if needed
      if (entry.isExpired()) {
        entry.reset();
        if (metricsEnabled) metrics.recordReset(identifier);
        if (eventEnabled) {
          await _emitEvent(RateLimitResetEvent(identifier, _name, entry.getResetTime().toDateTime()));
        }
      }

      final nowZdt = ZonedDateTime.now(_zoneId);
      final resetZdt = entry.getResetTime(); // ZonedDateTime

      if (entry.getCount() < limit) {
        // Allow: increment and return allowed result
        entry.increment();

        if (metricsEnabled) metrics.recordAllowed(identifier);
        if (eventEnabled) {
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
        if (metricsEnabled) metrics.recordDenied(identifier);

        // Compute retryAfter duration (non-negative)
        final retryAfterDur = resetZdt.toDateTime().difference(nowZdt.toDateTime());
        final retryAfter = retryAfterDur.isNegative ? Duration.zero : retryAfterDur;

        if (eventEnabled) {
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
    final windowKey = getWindowKey(window);

    return synchronizedAsync(store, () async {
      final entry = getOrCreate(identifier, windowKey, window);

      if (entry.isExpired()) {
        entry.reset();
        if (metricsEnabled) {
          metrics.recordReset(identifier);
        }

        if (eventEnabled) {
          _emitEvent(RateLimitResetEvent(identifier, _name, entry.getResetTime().toDateTime()));
        }
      }

      entry.increment();

      if (metricsEnabled) {
        metrics.recordAllowed(identifier);
      }
    });
  }
  
  @override
  FutureOr<void> reset(Object identifier) async {
    return synchronizedAsync(store, () async {
      final keysToRemove = store.keys.where((k) => extractIdentifier(k) == identifier).toList();
      for (final key in keysToRemove) {
        store.remove(key);
      }
    });
  }
  
  @override
  void setApplicationContext(ApplicationContext applicationContext) {
    _applicationContext = applicationContext;

    final env = applicationContext.getEnvironment();

    final zoneId = env.getProperty(RateLimitConfiguration.TIMEZONE) ?? env.getProperty(AbstractApplicationContext.APPLICATION_TIMEZONE);
    if (zoneId != null) {
      _zoneId = ZoneId.of(zoneId);
      metrics.zoneId = _zoneId;
    }

    final metricsEnabled = env.getPropertyAs<bool>(RateLimitConfiguration.ENABLE_METRICS, Class<bool>());
    if (metricsEnabled != null) {
      this.metricsEnabled = metricsEnabled;
    }

    final eventEnabled = env.getPropertyAs<bool>(RateLimitConfiguration.ENABLE_EVENTS, Class<bool>());
    if (eventEnabled != null) {
      this.eventEnabled = eventEnabled;
    }
  }
  
  @override
  void setZoneId(String zone) {
    _zoneId = ZoneId.of(zone);
    metrics.zoneId = _zoneId;
  }

  /// Publish a [RateLimitEvent] to the configured [ApplicationContext] if events are enabled.
  ///
  /// This internal helper:
  /// - Guards emission using the [eventEnabled] flag to avoid unnecessary work.
  /// - Asynchronously publishes the event via [_applicationContext.publishEvent].
  /// - Keeps event emission decoupled from core logic so that tests can disable
  ///   or replace event handling without modifying operational code paths.
  ///
  /// Note: The method intentionally swallows neither exceptions nor returns a value;
  /// any exceptions thrown by the application context will propagate to callers.
  Future<void> _emitEvent(RateLimitEvent event) async {
    if (eventEnabled) {
      await _applicationContext.publishEvent(event);
    }
  }

  /// Generates a unique **window key** string for a given duration, based on the
  /// current timestamp.
  ///
  /// This key can be used for bucketing, rate-limiting, or time-windowed analytics.
  ///
  /// The resulting key encodes:
  /// - The window duration in seconds (`window.inSeconds`)
  /// - The starting boundary of the window, adjusted to the appropriate
  ///   granularity (second, minute, or hour) based on the duration.
  ///
  /// Example:
  /// ```dart
  /// final key = getWindowKey(Duration(minutes: 5));
  /// print(key); // "300s|ZoneX"
  /// ```
  @protected
  String getWindowKey(Duration window) {
    final now = ZonedDateTime.now();
    final windowStart = _calculateWindowStart(now, window);
    return "${window.inSeconds}s|${windowStart.zone}";
  }

  /// Calculates the **start of the current window** based on the given duration
  /// and current timestamp.
  ///
  /// Rounds the time to:
  /// - Second, if window ≤ 1 minute  
  /// - Minute, if window ≤ 1 hour  
  /// - Hour, if window > 1 hour
  ///
  /// This ensures all events within the same logical window map to the same start time.
  ///
  /// Returns a [ZonedDateTime] representing the start of the current window.
  ZonedDateTime _calculateWindowStart(ZonedDateTime now, Duration window) {
    DateTime dateTime;

    if (window.inSeconds <= 60) {
      dateTime = DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second);
    } else if (window.inSeconds <= 3600) {
      dateTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    } else {
      dateTime = DateTime(now.year, now.month, now.day, now.hour);
    }

    return ZonedDateTime.fromDateTime(dateTime);
  }

  /// Retrieves an existing [RateLimitEntry] for the given [identifier] and
  /// [windowKey], or creates a new one if none exists.
  ///
  /// - `identifier` — The object being rate-limited or tracked.
  /// - `windowKey` — The time window bucket key generated via [getWindowKey].
  /// - `window` — Duration of the window for new entries.
  ///
  /// Returns the corresponding [RateLimitEntry] from the store.
  @protected
  RateLimitEntry getOrCreate(Object identifier, String windowKey, Duration window) {
    final key = mergeKey(identifier, windowKey);
    return store.putIfAbsent(key, () => SimpleRateLimitEntry(windowKey, window, _zoneId));
  }

  /// Combines an [identifier] and [windowKey] into a single string key for storage.
  ///
  /// The resulting key format is:
  /// ```
  /// "<identifier>::<windowKey>"
  /// ```
  /// This is used internally to index rate limit entries in the store.
  @protected
  String mergeKey(Object identifier, String windowKey) {
    return '$identifier::$windowKey';
  }

  /// Extracts the original identifier from a merged key created by [mergeKey].
  ///
  /// If the merged key is a string, splits by `::` and returns the first component.
  /// If the merged key is not a string, returns it as-is.
  @protected
  Object extractIdentifier(Object mergedKey) {
    if (mergedKey is String) {
      final split = mergedKey.split('::');
      return split.first;
    }
    return mergedKey;
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