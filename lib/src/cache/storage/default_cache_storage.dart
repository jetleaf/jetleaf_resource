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

import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_core/core.dart';
import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_pod/pod.dart';

import '../../base/exceptions.dart';
import '../../config/cache_configuration.dart';
import '../cache_configurer.dart';
import '../event/cache_clear_event.dart';
import '../event/cache_event.dart';
import '../event/cache_evict_event.dart';
import '../event/cache_expire_event.dart';
import '../event/cache_hit_event.dart';
import '../event/cache_miss_event.dart';
import '../event/cache_put_event.dart';
import '../eviction_policy/cache_eviction_policy.dart';
import '../eviction_policy/fifo_eviction_policy.dart';
import '../eviction_policy/lfu_eviction_policy.dart';
import '../eviction_policy/lru_eviction_policy.dart';
import '../metrics/cache_metrics.dart';
import '../metrics/simple_cache_metrics.dart';
import 'cache.dart';
import 'cache_resource.dart';
import 'cache_storage.dart';
import 'configurable_cache_storage.dart';
import 'default_cache.dart';



/// {@template jet_concurrent_map_cache}
/// A thread-safe, in-memory cache implementation backed by a concurrent [CacheResource].
///
/// The [DefaultCacheStorage] provides a simple yet configurable caching mechanism
/// that integrates with JetLeaf's core caching infrastructure. It supports
/// configurable eviction policies, time-to-live (TTL) expiration, event
/// emission, and runtime metrics collection.
///
/// ### Purpose
///
/// Designed as the **default in-memory cache provider** within the JetLeaf
/// caching subsystem, this implementation balances concurrency and simplicity,
/// enabling applications to quickly cache and retrieve objects with minimal
/// overhead while maintaining observability and lifecycle awareness.
///
/// ### Key Responsibilities
///
/// - Store cache entries in an in-memory [_store] keyed by `Object`.
/// - Support dynamic configuration via [ApplicationContext] environment properties.
/// - Enforce size limits and eviction rules via [CacheEvictionPolicy].
/// - Track cache activity using [CacheMetrics].
/// - Optionally emit JetLeaf [CacheEvent]s for monitoring and auditing.
///
/// ### Configuration
///
/// The cache automatically resolves runtime configuration from
/// [CacheConfiguration] keys at context initialization:
///
/// | Property Key | Description | Default |
/// |---------------|--------------|----------|
/// | `CacheConfiguration.TIMEZONE` | Zone identifier used for temporal operations | `UTC` |
/// | `CacheConfiguration.TTL` | Default time-to-live duration (seconds) | `null` (non-expiring) |
/// | `CacheConfiguration.EVICTION_POLICY` | Eviction policy (`LRU`, `LFU`, `FIFO`) | `null` |
/// | `CacheConfiguration.MAX_ENTRIES` | Maximum allowed entries before eviction | `null` (unbounded) |
/// | `CacheConfiguration.ENABLE_METRICS` | Enables metrics tracking via [CacheMetrics] | `true` |
/// | `CacheConfiguration.ENABLE_EVENTS` | Enables cache event emission | `true` |
///
/// ### Lifecycle
///
/// 1. Upon startup, [setApplicationContext] loads environment configuration.
/// 2. The cache becomes operational with defaults or environment overrides.
/// 3. During runtime, cache operations such as [get], [put], and [evict] maintain
///    both data integrity and metrics/event synchronization.
/// 4. Calls to [invalidate] or [clear] safely purge expired or all entries.
///
/// ### Related Components
///
/// - [TunableCacheStorage]: Base interface defining core cache operations.
/// - [CacheMetrics]: Used to record operation-level statistics.
/// - [CacheEvent]: Framework-level cache event abstraction.
/// - [CacheEvictionPolicy]: Determines removal logic for size-bound caches.
/// - [ApplicationContext]: Provides environment and event-publishing services.
///
/// ### Example
///
/// ```dart
/// final cache = ConcurrentMapCache();
/// cache.setApplicationContext(appContext);
///
/// await cache.put('user:42', User('Alice'));
/// final user = await cache.getAs<User>('user:42');
///
/// print('Cache Hit Rate: ${cache.getMetrics().getHitRate()}%');
/// ```
///
/// ### Notes
///
/// - This cache is **non-distributed** and suitable for single-node deployments.
/// - All operations are asynchronous to integrate cleanly with JetLeaf’s
///   reactive event model, even though the backing storage is synchronous.
/// - Expiration and eviction are evaluated lazily during [get], [put], and
///   [invalidate] calls.
///
/// {@endtemplate}
final class DefaultCacheStorage implements CacheStorage, ConfigurableCacheStorage, ApplicationContextAware, SmartInitializingSingleton {
  // ---------------------------------------------------------------------------
  // Static Constants
  // ---------------------------------------------------------------------------

  /// The canonical cache name associated with this implementation.
  ///
  /// Used in emitted [CacheEvent]s, metrics tracking, and manager registration.
  static final String _DEFAULT_CACHE_NAME = "default";

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

  /// Internal in-memory storage backing the cache.
  ///
  /// Keys are arbitrary [Object] instances, and values are wrapped as [Cache]
  /// objects to track metadata such as TTL and access timestamps.
  ///
  /// Modifications to this map are synchronized via the event loop; explicit
  /// locks are not required under Dart’s single-threaded model.
  final CacheResource _store = CacheResource();

  /// The active eviction policy controlling entry removal when capacity is reached.
  ///
  /// May be dynamically configured through environment properties or by calling
  /// [setEvictionPolicy].
  CacheEvictionPolicy? _evictionPolicy;

  /// The maximum number of entries this cache can hold.
  ///
  /// When set, insertions beyond this limit will trigger eviction of
  /// candidates determined by the active [_evictionPolicy].
  int? _maxEntries;

  /// Default time-to-live (TTL) applied to entries when none is specified.
  ///
  /// If unset, entries are considered non-expiring unless individually
  /// created with a specific TTL value.
  Duration? _defaultTtl;

  /// Indicates whether metrics collection is enabled for this cache instance.
  ///
  /// When true, operations such as [get], [put], and [evict] record activity
  /// in the [_metrics] collector.
  bool _metricsEnabled = true;

  /// Indicates whether cache event emission is enabled.
  ///
  /// When true, cache lifecycle events (hit, miss, put, evict, expire, clear)
  /// are asynchronously published to the [ApplicationContext] for observability.
  bool _eventEnabled = true;

  /// Metrics tracker instance for this cache.
  ///
  /// Defaults to a [SimpleCacheMetrics] implementation configured with the cache name.
  /// Tracks hit rates, eviction counts, and other operational statistics.
  CacheMetrics _metrics = SimpleCacheMetrics(_DEFAULT_CACHE_NAME);

  /// Zone identifier used for all temporal and TTL computations.
  ///
  /// Defaults to [ZoneId.UTC] unless overridden through configuration or
  /// [setZoneId]. Ensures consistent behavior across time zones.
  ZoneId _zoneId = ZoneId.UTC;

  /// The canonical name identifying this cache or resource within the current
  /// JetLeaf context.
  ///
  /// This name is typically used for lookup and registration within the
  /// [CacheManager] or [PodFactory]. It must be unique across all caches
  /// registered in the same namespace.
  String _name;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  /// {@macro jet_concurrent_map_cache}
  ///
  /// Creates a new instance of [DefaultCacheStorage] with default
  /// in-memory configuration. The cache remains inactive until it is
  /// initialized via [setApplicationContext].
  DefaultCacheStorage() : this.named(_DEFAULT_CACHE_NAME);

  /// Creates a new [DefaultCacheStorage] instance with a custom cache name
  /// and an associated metrics tracker.
  ///
  /// This constructor allows explicitly naming the in-memory cache instance,
  /// enabling better organization and observability when multiple caches
  /// are registered within the same application context or represent distinct
  /// cache regions.
  ///
  /// A corresponding [SimpleCacheMetrics] instance is automatically initialized
  /// to monitor cache performance and statistics for the given [name].
  ///
  /// The cache remains inactive until it is initialized via [setApplicationContext].
  DefaultCacheStorage.named(String name) : _name = name, _metrics = SimpleCacheMetrics(name);

  @override
  String getPackageName() => PackageNames.RESOURCE;

  @override
  void setApplicationContext(ApplicationContext applicationContext) {
    _applicationContext = applicationContext;

    final env = applicationContext.getEnvironment();

    final zoneId = env.getProperty(CacheConfiguration.TIMEZONE) ?? env.getProperty(AbstractApplicationContext.APPLICATION_TIMEZONE);
    if (zoneId != null) {
      _zoneId = ZoneId.of(zoneId);
    }

    final ttl = env.getPropertyAs<int>(CacheConfiguration.TTL, Class<int>());
    if (ttl != null) {
      _defaultTtl = Duration(seconds: ttl);
    }

    final evictionPolicy = env.getProperty(CacheConfiguration.EVICTION_POLICY);
    if (evictionPolicy != null) {
      _evictionPolicy = _determineEvictionPolicy(evictionPolicy);
    }

    final maxEntries = env.getPropertyAs<int>(CacheConfiguration.MAX_ENTRIES, Class<int>());
    if (maxEntries != null) {
      _maxEntries = maxEntries;
    }

    final metricsEnabled = env.getPropertyAs<bool>(CacheConfiguration.ENABLE_METRICS, Class<bool>());
    if (metricsEnabled != null) {
      _metricsEnabled = metricsEnabled;
    }

    final eventEnabled = env.getPropertyAs<bool>(CacheConfiguration.ENABLE_EVENTS, Class<bool>());
    if (eventEnabled != null) {
      _eventEnabled = eventEnabled;
    }
  }

  @override
  Future<void> onSingletonReady() async {
    final podFactory = _applicationContext.getPodFactory();

    // Discover and apply all CacheConfigurer pods
    final configurer = Class<CacheConfigurer>(null, PackageNames.CORE);
    final configurerMap = await podFactory.getPodsOf(configurer, allowEagerInit: true);

    if (configurerMap.isNotEmpty) {
      final configurers = List<CacheConfigurer>.from(configurerMap.values);
      AnnotationAwareOrderComparator.sort(configurers);

      for (final configurer in configurers) {
        configurer.configure(_name, this);
      }
    } else {}

    // Discover and apply all CacheEvictionPolicy pods
    if (_evictionPolicy == null) {
      final type = Class<CacheEvictionPolicy>(null, PackageNames.CORE);
      final pods = await podFactory.getPodsOf(type, allowEagerInit: true);

      if (pods.isNotEmpty) {
        final policies = List<CacheEvictionPolicy>.from(pods.values);
        AnnotationAwareOrderComparator.sort(policies);

        final policy = policies.find((policy) => policy.getName().equalsIgnoreCase(CacheConfiguration.EVICTION_POLICY));
        if (policy != null) {
          _evictionPolicy = policy;
        }
      } else {}
    }
  }

  // ---------------------------------------------------------------------------
  // Helper: Eviction policy resolver
  // ---------------------------------------------------------------------------

  /// Resolve a named eviction policy string into a concrete [CacheEvictionPolicy] instance.
  ///
  /// The method accepts common policy identifiers (case-insensitive):
  /// - `'LRU'` → returns an [LruEvictionPolicy]
  /// - `'LFU'` → returns an [LfuEvictionPolicy]
  /// - `'FIFO'` → returns a [FifoEvictionPolicy]
  ///
  /// If the provided name does not match a known policy, the method returns `null`,
  /// indicating that no automatic eviction policy should be applied.
  ///
  /// This resolver centralizes string-to-policy mapping to keep configuration
  /// parsing consistent (used during [setApplicationContext] initialization).
  CacheEvictionPolicy? _determineEvictionPolicy(String evictionPolicy) {
    switch (evictionPolicy.toUpperCase()) {
      case 'LRU':
        return LruEvictionPolicy();
      case 'LFU':
        return LfuEvictionPolicy();
      case 'FIFO':
        return FifoEvictionPolicy();
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Helper: Event emitter
  // ---------------------------------------------------------------------------

  /// Publish a [CacheEvent] to the configured [ApplicationContext] if events are enabled.
  ///
  /// This internal helper:
  /// - Guards emission using the [_eventEnabled] flag to avoid unnecessary work.
  /// - Asynchronously publishes the event via [_applicationContext.publishEvent].
  /// - Keeps event emission decoupled from core logic so that tests can disable
  ///   or replace event handling without modifying operational code paths.
  ///
  /// Note: The method intentionally swallows neither exceptions nor returns a value;
  /// any exceptions thrown by the application context will propagate to callers.
  Future<void> _emitEvent(CacheEvent event) async {
    if (_eventEnabled) {
      await _applicationContext.publishEvent(event);
    }
  }

  @override
  FutureOr<void> clear() async {
    return synchronizedAsync(_store, () async {
      final count = _store.length;
      final keys = _store.keys;

      _store.clear();

      for (final key in keys) {
        await _emitEvent(CacheClearEvent(key, _name, count, DateTime.now()));
      }

      _metrics.reset();
    });
  }

  @override
  FutureOr<void> evict(Object key) async {
    return synchronizedAsync(_store, () async {
      if (_store.remove(key) != null) {
        if (_metricsEnabled) {
          _metrics.recordEviction(key);
        }

        await _emitEvent(CacheEvictEvent(key, _name, 'manual', DateTime.now()));
      } else {
        throw NoCacheFoundException(key);
      }
    });
  }

  @override
  FutureOr<bool> evictIfPresent(Object key) async {
    return synchronizedAsync(_store, () async {
      try {
        await evict(key);
        return true;
      } on NoCacheFoundException catch (_) {
        return false;
      }
    });
  }

  @override
  FutureOr<Cache?> get(Object key) async {
    return synchronizedAsync(_store, () async {
      final entry = _store[key];

      if (entry == null) {
        if (_metricsEnabled) {
          _metrics.recordMiss(key);
        }

        await _emitEvent(CacheMissEvent(key, _name, DateTime.now()));

        return null;
      }

      if (entry.isExpired()) {
        _store.remove(key);
        
        if (_metricsEnabled) {
          _metrics.recordEviction(key);
          _metrics.recordExpiration(key);
        }

        if (entry.getTtl() != null) {
          await _emitEvent(CacheExpireEvent(key, _name, entry.getTtl()!, entry.get(), DateTime.now()));
        }

        return null;
      }

      entry.recordAccess();
      
      if (_metricsEnabled) {
        _metrics.recordHit(key);
      }

      await _emitEvent(CacheHitEvent(key, _name, entry.get(), DateTime.now()));

      return entry;
    });
  }

  @override
  FutureOr<T?> getAs<T>(Object key, [Class<T>? type]) async {
    return synchronizedAsync(_store, () async {
      final entry = await get(key);

      if (entry == null) {
        return null;
      }

      return _applicationContext.getConversionService().convert(entry.get(), type ?? Class<T>());
    });
  }

  /// Retrieves the default Time-To-Live (TTL) duration applied to new cache entries.
  ///
  /// If `null`, entries are considered **non-expiring** unless explicitly given
  /// a TTL at insertion time.
  ///
  /// TTL defines how long an entry remains valid in the cache before it is automatically
  /// expired. Implementations may support dynamic TTL updates at runtime.
  ///
  /// Example:
  /// ```dart
  /// final ttl = cache.getDefaultTtl();
  /// print('Default TTL: ${ttl?.inMinutes ?? 'no expiry'} minutes');
  /// ```
  Duration? getDefaultTtl() => _defaultTtl;

  /// {@macro configurable_cache_storage}
  ///
  /// Retrieves the currently configured [CacheEvictionPolicy].
  ///
  /// The eviction policy determines which cache entries are selected for removal
  /// when the cache reaches its maximum capacity. Common implementations include:
  ///
  /// * [LruEvictionPolicy] — Evicts the least recently used entry.
  /// * [LfuEvictionPolicy] — Evicts the least frequently used entry.
  /// * [FifoEvictionPolicy] — Evicts the oldest inserted entry.
  ///
  /// Returns `null` if no eviction policy is currently set.
  CacheEvictionPolicy? getEvictionPolicy() => _evictionPolicy;

  /// Retrieves the maximum number of entries that this cache can hold before eviction.
  ///
  /// When the cache exceeds this limit, entries are evicted according to the configured
  /// [CacheEvictionPolicy]. If this value is `null`, the cache is considered **unbounded**
  /// and may grow without limit (depending on the implementation).
  int? getMaxEntries() => _maxEntries;

  /// Returns the [CacheMetrics] instance associated with this cache.
  ///
  /// Metrics track cumulative cache behavior over the cache’s lifetime, including:
  /// - **Hits:** Successful lookups that returned a cached value.
  /// - **Misses:** Lookups that found no cached entry.
  /// - **Evictions:** Entries removed due to policy-based eviction.
  /// - **Expirations:** Entries that expired after their TTL elapsed.
  /// - **Put operations:** Insertions or updates of cache entries.
  ///
  /// These statistics are useful for performance tuning, adaptive eviction,
  /// and monitoring system cache efficiency.
  ///
  /// Example:
  /// ```dart
  /// final metrics = cache.getMetrics();
  /// print('Cache hit rate: ${metrics.getHitRate()}%');
  /// ```
  CacheMetrics getMetrics() => _metrics;

  @override
  String getName() => _name;

  @override
  Resource<Object, Cache> getResource() => _store;

  /// Retrieves the [ZoneId] used by this cache for time-based computations.
  ///
  /// The zone determines how timestamps (such as creation, last access, and expiration)
  /// are resolved and displayed. This ensures consistent time semantics across
  /// distributed or region-aware cache instances.
  ///
  /// Example:
  /// ```dart
  /// print('Cache zone: ${cache.getZoneId()?.id ?? 'system default'}');
  /// ```
  ZoneId? getZoneId() => _zoneId;

  @override
  FutureOr<void> invalidate() async {
    return synchronizedAsync(_store, () async {
      final expiredKeys = <Object>[];

      // Collect all expired keys
      for (final entry in _store.entries) {
        if (entry.value.isExpired()) {
          expiredKeys.add(entry.key);
        }
      }

      // Remove expired entries
      for (final key in expiredKeys) {
        final removed = _store.remove(key);
        if (removed != null) {
          if (_metricsEnabled) {
            _metrics.recordEviction(key);
            _metrics.recordExpiration(key);
          }

          if (removed.getTtl() != null) {
            await _emitEvent(CacheExpireEvent(
              key,
              _name,
              removed.getTtl()!,
              removed.get(),
              DateTime.now(),
            ));
          }
        }
      }
    });
  }

  @override
  FutureOr<void> put(Object key, [Object? value, Duration? ttl]) async {
    return synchronizedAsync(_store, () async {
      final effectiveTtl = ttl ?? _defaultTtl;

      // Check if we need to evict
      if (_maxEntries != null && _store.length >= _maxEntries! && !_store.containsKey(key)) {
        if (_evictionPolicy == null) {
          throw CacheCapacityExceededException(_name, _maxEntries!);
        }

        final keyToEvict = await _evictionPolicy?.determineEvictionCandidate(_store);

        if (keyToEvict != null) {
          _store.remove(keyToEvict);
          
          if (_metricsEnabled) {
            _metrics.recordEviction(keyToEvict);
          }

          await _emitEvent(CacheEvictEvent(keyToEvict, _name, 'eviction_policy', DateTime.now()));
        }
      }

      _store[key] = DefaultCache(value, effectiveTtl, ZonedDateTime.now(_zoneId), _zoneId);
      
      if (_metricsEnabled) {
        _metrics.recordPut(key);
      }

      await _emitEvent(CachePutEvent(key, _name, value, effectiveTtl, DateTime.now()));
    });
  }

  @override
  FutureOr<Cache?> putIfAbsent(Object key, [Object? value, Duration? ttl]) async {
    return synchronizedAsync(_store, () async {
      final existing = _store[key];
      if (existing != null) {
        if (_metricsEnabled) {
          _metrics.recordHit(key); // optional: count as a hit
        }

        await _emitEvent(CacheHitEvent(key, _name, DateTime.now()));
        return existing;
      }

      // Key is absent → insert
      final effectiveTtl = ttl ?? _defaultTtl;

      // Eviction check same as in put
      if (_maxEntries != null && _store.length >= _maxEntries!) {
        final keyToEvict = await _evictionPolicy?.determineEvictionCandidate(_store);
        if (keyToEvict != null) {
          _store.remove(keyToEvict);
          
          if (_metricsEnabled) {
            _metrics.recordEviction(keyToEvict);
          }

          await _emitEvent(CacheEvictEvent(keyToEvict, _name, 'eviction_policy', DateTime.now()));
        }
      }

      final cacheValue = DefaultCache(value, effectiveTtl, ZonedDateTime.now(_zoneId), _zoneId);
      _store[key] = cacheValue;

      if (_metricsEnabled) {
        _metrics.recordPut(key);
      }

      await _emitEvent(CachePutEvent(key, _name, value, effectiveTtl, DateTime.now()));

      return cacheValue;
    });
  }

  @override
  void setDefaultTtl(Duration? ttl) {
    _defaultTtl = ttl;
  }

  @override
  void setEvictionPolicy(CacheEvictionPolicy policy) {
    _evictionPolicy = policy;
  }

  @override
  void setMaxEntries(int? maxEntries) {
    _maxEntries = maxEntries;
  }

  @override
  void setZoneId(String zone) {
    _zoneId = ZoneId.of(zone);
  }

  @override
  List<Object?> equalizedProperties() => [runtimeType, _name];
}