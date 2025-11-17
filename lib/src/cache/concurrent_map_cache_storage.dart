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

import '../exceptions.dart';
import '../resource.dart';
import 'cache.dart';
import 'cache_configuration.dart';

/// {@template concurrent_map_cache_resource}
/// A concurrent in-memory cache resource based on [HashMap], implementing
/// the [Resource] interface.
///
/// The [ConcurrentMapCacheResource] serves as the foundational in-memory
/// storage layer for JetLeaf’s caching subsystem. It maintains a thread-safe
/// mapping between keys and [Cache] instances, typically managed by
/// [CacheManager] implementations.
///
/// While it extends [HashMap], it is conceptually treated as a lightweight,
/// low-latency storage abstraction rather than a general-purpose collection.
/// The resource is ideal for small to medium-scale cache layers that require
/// predictable access times and thread-safety under concurrent read/write load.
///
/// ### Behavior
///
/// - Each entry maps an arbitrary object key to a [Cache] instance.
/// - Provides efficient `O(1)` average lookup and insertion times.
/// - Serves as a resource within JetLeaf’s cache infrastructure, often
///   referenced by higher-level managers or interceptors.
/// - Can be combined with external [CacheStorage] or [CacheManager]
///   implementations for hybrid or layered caching.
///
/// ### Example
///
/// ```dart
/// final resource = ConcurrentMapCacheResource();
///
/// // Add a cache instance
/// resource['users'] = SimpleCache('users');
///
/// // Retrieve and use the cache
/// final userCache = resource['users'];
/// userCache?.put('id:123', User('Alice'));
///
/// // Iterate through all caches
/// for (final entry in resource.entries) {
///   print('Cache ${entry.key}: ${entry.value.getSize()} entries');
/// }
/// ```
///
/// ### Thread Safety
///
/// Although [HashMap] itself is not inherently concurrent, JetLeaf’s
/// [ConcurrentMapCacheResource] is typically used within synchronized
/// regions or managed contexts to ensure atomic access. Implementations
/// should avoid performing non-atomic mutations concurrently unless
/// explicitly wrapped by synchronization primitives.
///
/// ### Related Components
///
/// - [Resource] – The abstract interface defining the resource contract.
/// - [Cache] – Represents the logical cache unit stored in this map.
/// - [CacheManager] – Higher-level coordinator that utilizes this resource.
/// - [ConcurrentMapCacheStorage] – A concrete cache storage built on this resource.
/// {@endtemplate}
final class ConcurrentMapCacheResource extends HashMap<Object, Cache> implements Resource {}

/// {@template jet_concurrent_map_cache}
/// A thread-safe, in-memory cache implementation backed by a concurrent [ConcurrentMapCacheResource].
///
/// The [ConcurrentMapCacheStorage] provides a simple yet configurable caching mechanism
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
final class ConcurrentMapCacheStorage implements CacheStorage, ConfigurableCacheStorage, ApplicationContextAware, SmartInitializingSingleton {
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
  final ConcurrentMapCacheResource _store = ConcurrentMapCacheResource();

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
  /// Defaults to a [_CacheMetrics] implementation configured with the cache name.
  /// Tracks hit rates, eviction counts, and other operational statistics.
  CacheMetrics _metrics = _CacheMetrics(_DEFAULT_CACHE_NAME);

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
  /// Creates a new instance of [ConcurrentMapCacheStorage] with default
  /// in-memory configuration. The cache remains inactive until it is
  /// initialized via [setApplicationContext].
  ConcurrentMapCacheStorage() : this.named(_DEFAULT_CACHE_NAME);

  /// Creates a new [ConcurrentMapCacheStorage] instance with a custom cache name
  /// and an associated metrics tracker.
  ///
  /// This constructor allows explicitly naming the in-memory cache instance,
  /// enabling better organization and observability when multiple caches
  /// are registered within the same application context or represent distinct
  /// cache regions.
  ///
  /// A corresponding [_CacheMetrics] instance is automatically initialized
  /// to monitor cache performance and statistics for the given [name].
  ///
  /// The cache remains inactive until it is initialized via [setApplicationContext].
  ConcurrentMapCacheStorage.named(String name) : _name = name, _metrics = _CacheMetrics(name);

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
  Resource getResource() => _store;

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

      _store[key] = _Cache(value, effectiveTtl, ZonedDateTime.now(_zoneId), _zoneId);
      
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

      final cacheValue = _Cache(value, effectiveTtl, ZonedDateTime.now(_zoneId), _zoneId);
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

/// {@template jet_cache_value}
/// Represents a single cache entry's stored value and its associated metadata.
///
/// A [_Cache] encapsulates not only the cached [value] itself but also
/// essential temporal metadata used for expiration, access tracking, and
/// observability. Each instance corresponds to one logical cache entry.
///
/// ### Purpose
///
/// JetLeaf caches utilize [_Cache] as the fundamental unit of stored
/// data, enabling both **time-based eviction policies** and **usage analytics**.
/// It tracks:
///
/// - The **original creation time** ([getCreatedAt]) of the cache entry.
/// - The **time-to-live (TTL)** duration ([getTtl]) defining its validity period.
/// - The **last access timestamp** ([getLastAccessedAt]) to support LRU/LFU
///   eviction strategies.
/// - The **access count** ([getAccessCount]) for frequency-based policies.
///
/// Together, these metrics allow caches to make informed decisions about
/// retention, expiration, and promotion.
///
/// ### Behavior
///
/// - If [_ttl] is `null`, the entry is considered **non-expiring**.
/// - [isExpired] computes the current state dynamically using [ZonedDateTime].
/// - Each call to [recordAccess] increments [_accessCount] and updates
///   [_lastAccessedAt], ensuring recency and usage tracking.
/// - [getRemainingTtl] calculates the remaining lifetime at query time.
///
/// ### Related Components
///
/// - [Cache]: The interface implemented by this class.
/// - [CacheStorage]: Uses [_Cache] to wrap stored entries with metadata.
/// - [CacheManager]: Interprets TTLs and access data for eviction policies.
/// - [CacheMetrics]: May aggregate statistics derived from [_Cache] usage.
///
/// ### Example
///
/// ```dart
/// final entry = _CacheValue(
///   user,
///   Duration(minutes: 10),
///   ZonedDateTime.now(ZoneId.systemDefault()),
///   ZoneId.systemDefault(),
/// );
///
/// if (!entry.isExpired()) {
///   final user = entry.get(); // retrieve cached value
///   entry.recordAccess(); // mark read
/// }
/// ```
///
/// ### Notes
///
/// - Implementations assume [ZonedDateTime] and [ZoneId] are provided by the
///   JetLeaf temporal subsystem for accurate timezone-sensitive computations.
/// - Instances are **immutable** except for access tracking fields
///   ([_accessCount] and [_lastAccessedAt]).
/// {@endtemplate}
final class _Cache implements Cache {
  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// The actual **cached value** stored in this entry.
  ///
  /// May be `null` if the original insertion explicitly cached a `null` result.
  /// Consumers should handle nullability gracefully.
  ///
  /// - Accessed via [get].
  /// - Remains immutable for the lifetime of the cache entry.
  final Object? value;

  /// The **time-to-live (TTL)** duration associated with this entry.
  ///
  /// When non-null, it represents the validity window from the creation time
  /// ([getCreatedAt]) after which the entry is considered expired.
  ///
  /// If `null`, the entry never expires automatically and must be evicted
  /// manually or via capacity policies.
  final Duration? _ttl;

  /// The **creation timestamp** for this entry.
  ///
  /// This field records when the cache item was originally written to the cache.
  /// It forms the baseline for calculating age ([getAgeInMilliseconds]) and
  /// remaining TTL ([getRemainingTtl]).
  final ZonedDateTime _createdAt;

  /// The **timezone context** used for all time computations.
  ///
  /// Ensures that expiration and access calculations are consistent and
  /// timezone-aware, critical in distributed or regionally localized systems.
  final ZoneId _zoneId;

  /// The total number of times this entry has been **accessed**.
  ///
  /// Incremented via [recordAccess]. Used by LFU (Least Frequently Used)
  /// cache strategies and analytics components such as [CacheMetrics].
  int _accessCount = 0;

  /// The **most recent access timestamp**.
  ///
  /// Updated every time [recordAccess] is called. Used by LRU
  /// (Least Recently Used) eviction strategies and recency analytics.
  late ZonedDateTime _lastAccessedAt;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  /// {@macro jet_cache_value}
  ///
  /// Creates a new cache entry encapsulating [value] and its temporal metadata.
  ///
  /// - [_ttl] defines how long the entry remains valid.
  /// - [_createdAt] marks when it was initially inserted.
  /// - [_zoneId] provides timezone awareness for expiration calculations.
  ///
  /// On construction, [_lastAccessedAt] is initialized to the current
  /// [ZonedDateTime] in the provided [_zoneId].
  _Cache(this.value, this._ttl, this._createdAt, this._zoneId) {
    _lastAccessedAt = ZonedDateTime.now(_zoneId);
  }

  @override
  Object? get() => value;

  @override
  int getAccessCount() => _accessCount;

  @override
  int getAgeInMilliseconds() => ZonedDateTime.now(_zoneId).toDateTime().difference(_createdAt.toDateTime()).inMilliseconds;

  @override
  ZonedDateTime getCreatedAt() => _createdAt;

  @override
  ZonedDateTime getLastAccessedAt() => _lastAccessedAt;

  @override
  Duration? getRemainingTtl() {
    if (_ttl == null) return null;
    final expirationTime = _createdAt.plus(_ttl);
    return expirationTime.toDateTime().difference(ZonedDateTime.now(_zoneId).toDateTime());
  }

  @override
  int getTimeSinceLastAccessInMilliseconds() => ZonedDateTime.now(_zoneId).toDateTime().difference(_lastAccessedAt.toDateTime()).inMilliseconds;

  @override
  Duration? getTtl() => _ttl;

  @override
  bool isExpired() {
    if (_ttl == null) return false;
    return ZonedDateTime.now(_zoneId).isAfter(_createdAt.plus(_ttl));
  }

  @override
  void recordAccess() {
    _lastAccessedAt = ZonedDateTime.now(_zoneId);
    _accessCount++;
  }
}

/// {@template jet_cache_metrics}
/// Tracks and aggregates statistics related to cache operations for a specific cache instance.
///
/// This internal metrics container collects raw events (hits, misses, puts,
/// evictions, expirations) and exposes aggregate insights used by JetLeaf
/// cache managers and observability layers.
///
/// ### Purpose
///
/// - Provide a lightweight in-memory store of cache events for a single
///   cache instance identified by its name.
/// - Enable calculation of derived metrics such as hit rate and totals.
/// - Produce a serializable graph/summary used by monitoring, debugging, or
///   remote telemetry subsystems via [buildGraph].
///
/// ### Behavior
///
/// - Events are appended to plain `List<Object>` buckets; entries are stored
///   as `Object` to avoid coupling to a specific key type. The stringified
///   representation (`toString()`) is used when building grouped summaries.
/// - The class is designed for **instrumentation** rather than long-term
///   storage — callers may reset metrics via [reset] to begin a new collection window.
///
/// ### Related
///
/// - [CacheMetrics] — interface implemented by this class.
/// - Useful external consumers: `CacheManager`, instrumentation/telemetry
///   exporters, health checks.
/// - Commonly referenced methods (for documentation tracking): [buildGraph],
///   [getNumberOfPutOperations], [getHitRate], [getTotalNumberOfAccesses],
///   [reset].
///
/// ### Example
///
/// ```dart
/// final metrics = _CacheMetrics('userCache'); // internal per-cache metrics
/// metrics.recordHit('user:42');
/// metrics.recordPut('user:42');
/// final graph = metrics.buildGraph(); // structured summary for telemetry
/// ```
/// {@endtemplate}
final class _CacheMetrics implements CacheMetrics {
  // ---------------------------------------------------------------------------
  // Fields (documented)
  // ---------------------------------------------------------------------------

  /// Internal list of recorded **hit** events.
  ///
  /// Each entry is stored as an [Object] and represents a key that was
  /// successfully retrieved from the cache. The list preserves the sequence
  /// of events and is used to compute counts and frequency distributions.
  ///
  /// **Notes**
  /// - Entries are not deduplicated — repeated hits for the same key are
  ///   represented as multiple entries.
  /// - When building summaries (see [buildGraph]), each entry's `toString()`
  ///   value is used as a grouping key.
  final List<Object> _hits = [];

  /// Internal list of recorded **miss** events.
  ///
  /// Mirrors the semantics of [_hits] but for failed lookups (cache misses).
  /// Used to compute access totals and miss rates.
  final List<Object> _misses = [];

  /// Internal list of recorded **eviction** events.
  ///
  /// Contains keys that were removed from the cache due to capacity or
  /// eviction policy. Useful for diagnosing churn and memory pressure.
  final List<Object> _evictions = [];

  /// Internal list of recorded **expiration** events.
  ///
  /// Contains keys that expired according to TTL/expiry policies. Useful for
  /// identifying keys that are being evicted by lifecycle policies.
  final List<Object> _expirations = [];

  /// Internal list of recorded **put** events.
  ///
  /// Each entry indicates a successful or attempted write to the cache. This
  /// counter is separate from hits/misses because writes do not imply reads.
  final List<Object> _puts = [];

  /// Human-friendly name of the cache this metrics instance is tracking.
  ///
  /// This value is included in structured summaries such as [buildGraph] so
  /// telemetry systems and logs can associate metrics with the originating
  /// cache instance.
  final String _name;

  // ---------------------------------------------------------------------------
  // Template-based constructor doc (macro included)
  // ---------------------------------------------------------------------------

  /// {@macro jet_cache_metrics}
  ///
  /// Creates an internal metrics collector bound to a single cache instance
  /// name. The provided [_name] is used when generating summaries and graphs.
  _CacheMetrics(this._name);

  @override
  Map<String, Object> buildGraph() {
    Map<String, Map<String, int>> operations = {};

    // Helper function to count occurrences in a list
    Map<String, int> countEntries(List<Object> list) {
      final counts = <String, int>{};
      for (final entry in list) {
        final key = entry.toString();
        counts[key] = (counts[key] ?? 0) + 1;
      }
      return counts;
    }

    // Add non-empty operation types
    void addIfNotEmpty(String name, List<Object> entries) {
      final grouped = countEntries(entries);
      if (grouped.isNotEmpty) {
        operations[name] = grouped;
      }
    }

    addIfNotEmpty("get", _hits);
    addIfNotEmpty("miss", _misses);
    addIfNotEmpty("put", _puts);
    addIfNotEmpty("evict", _evictions);
    addIfNotEmpty("expire", _expirations);

    return {
      "cache_name": _name,
      "operations": operations.isEmpty ? "No operation performed" : operations,
    };
  }
  
  @override
  double getHitRate() {
    final total = getTotalNumberOfAccesses();
    if (total == 0) return 0.0;
    return (_hits.length / total) * 100;
  }
  
  @override
  int getNumberOfPutOperations() => _puts.length;
  
  @override
  int getTotalNumberOfAccesses() => _hits.length + _misses.length;
  
  @override
  int getTotalNumberOfEvictions() => _evictions.length;
  
  @override
  int getTotalNumberOfExpirations() => _expirations.length;
  
  @override
  int getTotalNumberOfHits() => _hits.length;
  
  @override
  int getTotalNumberOfMisses() => _misses.length;
  
  @override
  void recordEviction(Object key) => _evictions.add(key);
  
  @override
  void recordExpiration(Object key) => _expirations.add(key);
  
  @override
  void recordHit(Object key) => _hits.add(key);
  
  @override
  void recordMiss(Object key) => _misses.add(key);
  
  @override
  void recordPut(Object key) => _puts.add(key);
  
  @override
  void reset() {
    _hits.clear();
    _misses.clear();
    _evictions.clear();
    _expirations.clear();
    _puts.clear();
  }
}