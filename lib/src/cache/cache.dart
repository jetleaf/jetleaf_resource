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
import 'package:jetleaf_core/intercept.dart';
import 'package:jetleaf_lang/lang.dart';

import '../key_generator/key_generator.dart';
import '../resource.dart';
import 'annotations.dart';

/// Represents a single cache entry, encapsulating both the **cached value**
/// and its associated **lifecycle metadata**.
///
/// A [Cache] is the foundational abstraction for all cache systems
/// built on top of Jetleaf’s caching infrastructure. It models not only
/// the stored value itself but also the essential temporal and behavioral
/// characteristics that define the entry’s validity, usage frequency,
/// and expiration semantics.
///
/// ## Overview
///
/// When a method annotated with `@Cacheable` or `@CachePut` is invoked,
/// the framework stores its computed result within a [CacheStorage] instance.
/// Rather than simply persisting the raw result, the cache backend wraps
/// it inside a [Cache], allowing the framework to reason about:
///
/// - When the value was created
/// - When it was last accessed
/// - How many times it has been accessed
/// - Whether it has expired
/// - How much time remains before it expires (TTL-based)
///
/// This metadata enables the framework to perform intelligent cache
/// management, including:
///
/// - **Expiration**: Automatically removing stale entries based on TTL.
/// - **Eviction policies**: Prioritizing old or infrequently used entries.
/// - **Monitoring and metrics**: Collecting access and lifetime statistics.
///
///
/// ## Contract and Semantics
///
/// Implementations of this interface are expected to adhere to the
/// following core rules:
///
/// 1. **Thread-safety**: If a cache implementation supports concurrent
///    access (e.g., multi-threaded environments or async I/O),
///    `CacheValue` instances must be safe to read and update concurrently.
///
/// 2. **Immutability of value**: The value returned by [get] should be
///    treated as immutable by consumers. If the object is mutable,
///    any external modifications may invalidate the cache semantics.
///
/// 3. **Time consistency**: All timestamp-related methods
///    ([getCreatedAt], [getLastAccessedAt], etc.) should use the same
///    system time source (typically UTC or a monotonic clock) to ensure
///    consistent comparisons and expiry calculations.
///
/// 4. **Expiration semantics**: The [isExpired] method must accurately
///    reflect whether the entry should be considered invalid according
///    to its configured [getTtl] and current system time.
///
///
/// ## Example Usage
///
/// A simplified interaction pattern might look like this:
///
/// ```dart
/// final cacheValue = await cache.get('user:42');
///
/// if (cacheValue != null) {
///   if (!cacheValue.isExpired()) {
///     // Access the stored value.
///     final user = cacheValue.get();
///
///     // Optionally update its access metadata.
///     cacheValue.recordAccess();
///   } else {
///     // The value has expired — remove it or refresh it.
///     await cache.evict('user:42');
///   }
/// }
/// ```
///
///
/// ## Implementor Guidelines
///
/// When implementing this interface, you should:
///
/// - Maintain internal fields for:
///   - The cached object itself
///   - Creation time (`ZonedDateTime`)
///   - Last accessed time (`ZonedDateTime`)
///   - Access count (`int`)
///   - Time-to-live (`Duration?`)
///
/// - Update [recordAccess] on every retrieval or usage of the cached
///   value, including framework-driven accesses (e.g., in
///   `CacheableOperation`).
///
/// - Accurately calculate remaining TTL in [getRemainingTtl] by subtracting
///   the elapsed time since creation from the configured [getTtl].
///
///
/// ## Relationship to Other Components
///
/// [Cache] instances are returned from [CacheStorage.get], stored by
/// [CacheStorage.put], and inspected by caching operations such as
/// [CacheableOperation], [CachePutOperation], and [CacheEvictOperation].
///
/// The interface is designed to be **cache-engine agnostic** — it can be
/// backed by simple in-memory structures, distributed cache clusters,
/// or persistent storage.
///
///
/// ## See Also
///
/// - [CacheStorage]: Defines the cache container abstraction.
/// - [CacheManager]: Provides high-level lifecycle management of caches.
/// - [CacheErrorHandler]: Handles operational errors during cache access.
/// - [Cacheable], [CachePut], [CacheEvict]: Declarative caching annotations.
///
///
/// ## API Summary
///
/// Each method on this interface contributes to understanding the
/// lifecycle of a cached entry:
///
abstract interface class Cache {
  /// Returns the actual value stored within this cache entry.
  ///
  /// The returned value represents the payload originally cached during
  /// a `@Cacheable` or `@CachePut` operation.
  ///
  /// Implementations should **not** perform any mutation or deserialization
  /// beyond what is necessary for cache retrieval.
  ///
  /// Returns `null` if the cached payload is missing or has been
  /// explicitly invalidated.
  Object? get();

  /// Determines whether this cache entry has expired according to its
  /// configured [getTtl] or custom expiration strategy.
  ///
  /// When `true`, this entry should be treated as **logically invalid**
  /// and must not be served to callers.
  ///
  /// Cache implementations may perform physical removal lazily, meaning
  /// expired entries might still exist in memory but will be filtered out
  /// during access.
  bool isExpired();

  /// Records an access event for this cache entry.
  ///
  /// Implementations typically:
  /// - Update the `lastAccessedAt` timestamp.
  /// - Increment the internal access count.
  ///
  /// This method is usually invoked automatically whenever [get] is
  /// called, but can also be used manually to track background read
  /// patterns (e.g., cache warming or monitoring).
  void recordAccess();

  /// Returns the total time in milliseconds since this cache entry was
  /// first created and added to the cache.
  ///
  /// This metric is often used for age-based eviction or analytical
  /// dashboards.
  int getAgeInMilliseconds();

  /// Returns the elapsed time in milliseconds since the last access
  /// to this cache entry.
  ///
  /// Can be used in idle-time eviction strategies, or to identify
  /// “cold” entries that are rarely read.
  int getTimeSinceLastAccessInMilliseconds();

  /// Returns the configured **Time-To-Live (TTL)** duration for this
  /// cache entry, or `null` if the entry does not expire.
  ///
  /// A `null` value indicates that the entry should live indefinitely
  /// until explicitly evicted.
  Duration? getTtl();

  /// Calculates and returns the **remaining time-to-live** for this entry,
  /// i.e., how long until it expires.
  ///
  /// If no TTL is defined, returns `null`.
  ///
  /// Implementations should ensure the result never falls below zero.
  Duration? getRemainingTtl();

  /// Returns the timestamp representing when this cache entry was
  /// originally created.
  ///
  /// Used for age-based analysis and expiration calculations.
  ZonedDateTime getCreatedAt();

  /// Returns the timestamp representing when this entry was last accessed.
  ///
  /// Implementations should initialize this field to the creation time
  /// for new entries and update it on every access.
  ZonedDateTime getLastAccessedAt();

  /// Returns the total number of times this cache entry has been accessed
  /// since creation.
  ///
  /// Useful for usage-based cache metrics and adaptive eviction policies.
  int getAccessCount();
}

// -------------------------------------------------------------------------------------------------------------
// CACHE METRICS
// -------------------------------------------------------------------------------------------------------------

/// An abstract interface class for collecting and reporting **cache-related metrics**.
///
/// ## Overview
/// `CacheMetrics` provides a standardized way to track the behavior and performance
/// of a cache implementation. Metrics include hits, misses, evictions, expirations,
/// put operations, total accesses, and hit rates. Implementations can be used to
/// monitor cache efficiency, tune eviction policies, or expose statistics to
/// administrators.
///
/// ## Metrics Explained
/// - **Hit:** A successful retrieval of a value from the cache.
/// - **Miss:** A failed retrieval where the value was not present in the cache.
/// - **Eviction:** Removal of an entry due to cache policy (e.g., LRU, LFU, FIFO).
/// - **Expiration:** Removal of an entry because its time-to-live (TTL) expired.
/// - **Put Operation:** Insertion of a value into the cache.
/// - **Total Accesses:** The sum of hits and misses.
/// - **Hit Rate:** The percentage of accesses that were successful (hits / total accesses * 100).
///
/// ## Typical Usage
/// ```dart
/// final metrics = MyCacheMetricsImplementation();
/// cache.put('key1', value);
/// metrics.recordPut();
/// cache.get('key1');
/// metrics.recordHit();
/// cache.get('key2');
/// metrics.recordMiss();
/// print('Cache hit rate: ${metrics.getHitRate()}%');
/// ```
///
/// ## Notes
/// Implementations of `CacheMetrics` should ensure thread-safety in concurrent
/// environments and provide efficient increment and retrieval operations.
abstract interface class CacheMetrics {
  /// {@macro cache_metrics_operations}
  ///
  /// Builds a structured graph representation of the cache state and recent operations.
  ///
  /// This method returns a JSON-compatible [Map] representation of key-value
  /// relationships and their associated operations (hits, misses, puts, etc.).
  ///
  /// The output may include metadata such as operation counts, timestamps,
  /// or access frequency depending on the implementation.
  ///
  /// Example output:
  /// ```dart
  /// {
  ///   "cache_name": "products",
  ///   "operations": {
  ///     "get": {"id:100": 35},
  ///     "put": {"id:101": 2}
  ///   }
  /// }
  /// ```
  Map<String, Object> buildGraph();

  /// Records a successful cache hit for the given [key].
  ///
  /// Invoked when a requested key exists in the cache and the cached value
  /// is returned to the caller. Hits indicate effective reuse of cached data
  /// and directly contribute to higher hit ratios.
  ///
  /// Example:
  /// ```dart
  /// cacheMetrics.recordHit('user:42');
  /// ```
  void recordHit(Object key);

  /// Records a cache miss for the specified [key].
  ///
  /// Invoked when a requested key is not present in the cache, requiring
  /// computation or retrieval from the underlying data source. Frequent
  /// misses may indicate insufficient cache capacity or suboptimal TTLs.
  ///
  /// Example:
  /// ```dart
  /// cacheMetrics.recordMiss('user:99');
  /// ```
  void recordMiss(Object key);

  /// Records the eviction of a cache entry identified by [key].
  ///
  /// Evictions are triggered by capacity constraints or policy-driven decisions
  /// (e.g., [LruEvictionPolicy], [LfuEvictionPolicy], [FifoEvictionPolicy]).
  /// This event is important for analyzing cache churn and assessing
  /// eviction policy effectiveness.
  ///
  /// Example:
  /// ```dart
  /// cacheMetrics.recordEviction('session:abc123');
  /// ```
  void recordEviction(Object key);

  /// Records the expiration of a cache entry identified by [key].
  ///
  /// Expiration occurs when a cached entry’s TTL (time-to-live) elapses.
  /// Recording these events helps monitor how often entries naturally expire
  /// versus being manually evicted.
  ///
  /// Example:
  /// ```dart
  /// cacheMetrics.recordExpiration('order:8871');
  /// ```
  void recordExpiration(Object key);

  /// Records a cache write (insert or update) operation for the given [key].
  ///
  /// Called whenever a value is added to or updated in the cache, regardless
  /// of whether it previously existed. Useful for tracking cache churn,
  /// mutation rates, and synchronization with upstream data sources.
  ///
  /// Example:
  /// ```dart
  /// cacheMetrics.recordPut('user:42');
  /// ```
  void recordPut(Object key);

  /// Returns the total number of cache hits.
  ///
  /// This metric reflects how often requested keys were found in the cache.
  int getTotalNumberOfHits();

  /// Returns the total number of cache misses.
  ///
  /// This metric reflects how often requested keys were **not** found in
  /// the cache.
  int getTotalNumberOfMisses();

  /// Returns the total number of evictions that have occurred.
  ///
  /// Each eviction represents a cache entry removed by a policy to make
  /// room for new entries.
  int getTotalNumberOfEvictions();

  /// Returns the total number of cache expirations that have occurred.
  ///
  /// Each expiration represents a cached entry that became invalid due
  /// to TTL or time-based constraints.
  int getTotalNumberOfExpirations();

  /// Returns the total number of put operations.
  ///
  /// This includes insertions of new entries as well as updates to
  /// existing entries.
  int getNumberOfPutOperations();

  /// Returns the total number of accesses, which is the sum of hits and misses.
  ///
  /// This represents the total number of times the cache has been queried.
  int getTotalNumberOfAccesses();

  /// Returns the cache hit rate as a percentage (0.0–100.0).
  ///
  /// Hit rate is calculated as `(totalHits / totalAccesses) * 100`.
  /// Returns 0.0 if no accesses have occurred to avoid division by zero.
  double getHitRate();

  /// Resets all metrics to zero, clearing the historical statistics.
  ///
  /// This is useful for monitoring windows or when starting a new
  /// measurement interval.
  void reset();
}

// -------------------------------------------------------------------------------------------------------------
// CACHE
// -------------------------------------------------------------------------------------------------------------

/// {@template cache}
/// The core abstraction representing a single named cache.
///
/// A cache is a key-value store that provides fast access to frequently
/// accessed data. This interface defines the fundamental operations for
/// interacting with a cache, including retrieval, storage, and eviction.
///
/// ## Operations
///
/// - **get**: Retrieve a value from the cache
/// - **put**: Store a value in the cache
/// - **putIfAbsent**: Store a value only if the key doesn't exist
/// - **evict**: Remove a specific entry from the cache
/// - **clear**: Remove all entries from the cache
/// - **invalidate**: Clear cache and reset internal state
///
/// ## Null Handling
///
/// Caches support storing null values through the [Cache] abstraction.
/// This allows distinguishing between a cache miss and a cached null value.
///
/// ## Async Support
///
/// All operations return [FutureOr] to support both synchronous and
/// asynchronous cache implementations.
///
/// **Example:**
/// ```dart
/// final cache = cacheManager.getCache('users');
/// 
/// // Store a value
/// await cache.put('user:1', user);
/// 
/// // Retrieve a value
/// final wrapper = await cache.get('user:1');
/// if (wrapper != null) {
///   final user = wrapper.get();
///   print('Found user: ${user.name}');
/// }
/// 
/// // Remove a value
/// await cache.evict('user:1');
/// 
/// // Clear entire cache
/// await cache.clear();
/// 
/// // Type-safe retrieval
/// final cachedUser = await cache.getAs<User>('user:1');
/// if (cachedUser != null) {
///   print('User email: ${cachedUser.email}');
/// }
/// ```
/// {@endtemplate}
abstract interface class CacheStorage with EqualsAndHashCode {
  /// Returns the cache name.
  ///
  /// The name identifies this cache instance and is typically used
  /// for configuration and monitoring purposes.
  ///
  /// **Example:**
  /// ```dart
  /// final cacheName = cache.getName();
  /// print('Cache name: $cacheName'); // 'users'
  /// ```
  String getName();

  /// Returns the underlying native cache provider.
  ///
  /// This allows access to the actual cache implementation for
  /// provider-specific operations and advanced features.
  ///
  /// **Example:**
  /// ```dart
  /// final nativeCache = cache.getResource();
  /// if (nativeCache is MemoryCache) {
  ///   // Perform memory-specific operations
  ///   nativeCache.trimToSize(1000);
  /// }
  /// ```
  Resource getResource();

  /// {@macro cacheGet}
  /// Retrieves a value from the cache.
  ///
  /// Returns a [Cache] containing the cached value, or null if
  /// the key is not present in the cache.
  ///
  /// The [Cache] allows distinguishing between a cache miss (null return)
  /// and a cached null value (non-null wrapper with null value).
  ///
  /// **Parameters:**
  /// - [key]: The cache key to look up
  ///
  /// **Returns:**
  /// - A [Cache] containing the cached value, or null if not found
  ///
  /// **Example:**
  /// ```dart
  /// final wrapper = await cache.get('user:123');
  /// 
  /// if (wrapper == null) {
  ///   // Cache miss - key not found
  ///   print('User not found in cache');
  /// } else {
  ///   final user = wrapper.get();
  ///   if (user == null) {
  ///     // Cached null value - user was explicitly cached as null
  ///     print('User was cached as null');
  ///   } else {
  ///     // Cached non-null value
  ///     print('Found user: $user');
  ///   }
  /// }
  /// ```
  FutureOr<Cache?> get(Object key);

  /// {@macro cacheGetAs}
  /// Retrieves a value from the cache with type casting.
  ///
  /// This is a convenience method that retrieves the value and casts it
  /// to the specified type [T]. It handles the [Cache] abstraction
  /// internally for simpler usage.
  ///
  /// **Parameters:**
  /// - [key]: The cache key to look up
  /// - [type]: The expected type of the cached value (optional, for runtime checks)
  ///
  /// **Returns:**
  /// - The cached value cast to type [T], or null if not found
  ///
  /// **Throws:**
  /// - [TypeError] if the cached value cannot be cast to type [T]
  ///
  /// **Example:**
  /// ```dart
  /// // Type-safe retrieval
  /// final user = await cache.getAs<User>('user:123');
  /// if (user != null) {
  ///   print('User name: ${user.name}');
  /// }
  /// 
  /// // With runtime type checking
  /// final data = await cache.getAs<List<int>>('binary-data', type: Class<List>());
  /// if (data != null) {
  ///   print('Data length: ${data.length}');
  /// }
  /// ```
  FutureOr<T?> getAs<T>(Object key, [Class<T>? type]);

  /// {@macro cachePut}
  /// Stores a value in the cache.
  ///
  /// Associates the specified value with the specified key in this cache.
  /// If the cache previously contained a value for this key, the old value
  /// is replaced.
  ///
  /// **Parameters:**
  /// - [key]: The cache key
  /// - [value]: The value to cache (can be null)
  /// - [ttl]: The time to live
  ///
  /// **Example:**
  /// ```dart
  /// // Cache a non-null value
  /// await cache.put('user:123', User(id: 123, name: 'John'));
  /// 
  /// // Cache a null value (explicitly)
  /// await cache.put('user:999', null);
  /// 
  /// // Cache collections and complex objects
  /// await cache.put('active-users', [user1, user2, user3]);
  /// await cache.put('config', appConfig);
  /// ```
  FutureOr<void> put(Object key, [Object? value, Duration? ttl]);

  /// {@macro cachePutIfAbsent}
  /// Stores a value in the cache only if the key is not already present.
  ///
  /// This is an atomic operation that checks for the key's existence and
  /// stores the value only if the key is not found.
  ///
  /// **Parameters:**
  /// - [key]: The cache key
  /// - [value]: The value to cache (can be null)
  ///
  /// **Returns:**
  /// - A [Cache] containing the existing value if the key was present,
  ///   or null if the value was successfully stored
  ///
  /// **Example:**
  /// ```dart
  /// // Only store if not already present
  /// final existing = await cache.putIfAbsent('user:123', newUser);
  /// 
  /// if (existing == null) {
  ///   print('User was successfully cached');
  /// } else {
  ///   print('User already exists in cache: ${existing.get()}');
  /// }
  /// ```
  FutureOr<Cache?> putIfAbsent(Object key, [Object? value, Duration? ttl]);

  /// {@macro cacheEvict}
  /// Removes a specific entry from the cache.
  ///
  /// **Parameters:**
  /// - [key]: The cache key to remove
  ///
  /// **Example:**
  /// ```dart
  /// // Remove a single entry
  /// await cache.evict('user:123');
  /// 
  /// // Remove multiple entries
  /// await cache.evict('user:123');
  /// await cache.evict('user:456');
  /// await cache.evict('user:789');
  /// ```
  FutureOr<void> evict(Object key);

  /// {@macro cacheEvictIfPresent}
  /// Removes a specific entry from the cache if it exists.
  ///
  /// This is similar to [evict] but returns a boolean indicating whether
  /// the key was actually present and removed.
  ///
  /// **Parameters:**
  /// - [key]: The cache key to remove
  ///
  /// **Returns:**
  /// - true if the key was present and removed, false otherwise
  ///
  /// **Example:**
  /// ```dart
  /// final wasRemoved = await cache.evictIfPresent('user:123');
  /// if (wasRemoved) {
  ///   print('User was removed from cache');
  /// } else {
  ///   print('User was not found in cache');
  /// }
  /// ```
  FutureOr<bool> evictIfPresent(Object key);

  /// {@macro cacheClear}
  /// Removes all entries from the cache.
  ///
  /// After this operation, the cache will be empty.
  ///
  /// **Example:**
  /// ```dart
  /// // Clear entire cache
  /// await cache.clear();
  /// print('Cache has been cleared');
  /// 
  /// // Verify cache is empty
  /// final wrapper = await cache.get('any-key');
  /// assert(wrapper == null);
  /// ```
  FutureOr<void> clear();

  /// {@macro cacheInvalidate}
  /// Invalidates the cache, clearing all entries and potentially
  /// resetting internal state.
  ///
  /// This is similar to [clear] but may perform additional cleanup
  /// operations depending on the cache implementation, such as
  /// resetting statistics or clearing internal buffers.
  ///
  /// **Example:**
  /// ```dart
  /// // Invalidate cache (more thorough than clear)
  /// await cache.invalidate();
  /// print('Cache has been invalidated');
  /// ```
  FutureOr<void> invalidate();
}

/// {@template configurable_cache_storage}
/// Defines configuration capabilities for a cache storage implementation.
///
/// The [ConfigurableCacheStorage] interface provides runtime configurability
/// for cache-related parameters such as eviction policies, time-to-live (TTL),
/// capacity limits, and time zone behavior. It is designed to allow flexible
/// cache tuning without rebuilding or redeploying components.
///
/// ### Overview
///
/// Implementations of this interface enable dynamic control over how
/// cached data is stored, evicted, and expired. This allows developers
/// or framework integrators to optimize caching strategies for specific
/// application workloads, environments, or performance goals.
///
/// Typical implementations include:
/// - [ConcurrentMapCacheStorage]
/// - [HybridCacheStorage]
/// - [DistributedCacheStorage]
///
/// ### Configuration Parameters
///
/// | Configuration | Description | Example |
/// |----------------|-------------|----------|
/// | **Eviction Policy** | Defines how entries are removed when capacity is exceeded. | `setEvictionPolicy(LruEvictionPolicy())` |
/// | **Default TTL** | Controls expiration time for entries without explicit TTL. | `setDefaultTtl(Duration(minutes: 30))` |
/// | **Zone ID** | Specifies the time zone for timestamped cache operations. | `setZoneId('UTC')` |
/// | **Max Entries** | Sets the maximum cache capacity. | `setMaxEntries(500)` |
///
/// ### Example Usage
///
/// ```dart
/// final cache = ConcurrentMapCacheStorage();
/// cache
///   ..setEvictionPolicy(LfuEvictionPolicy())
///   ..setDefaultTtl(Duration(hours: 1))
///   ..setZoneId('America/New_York')
///   ..setMaxEntries(1000);
/// ```
///
/// ### Integration
///
/// - Used by [CacheManager] to apply runtime cache tuning.
/// - Interacts with [CacheEvictionPolicy] to determine eviction behavior.
/// - Consulted by monitoring tools to inspect and update live cache parameters.
/// - Commonly used in auto-configuration modules to enforce cache defaults.
///
/// ### Error Handling
///
/// Implementations are encouraged to validate configuration parameters strictly
/// and throw descriptive exceptions such as:
///
/// - [ArgumentError] → For null or invalid arguments.
/// - [IllegalArgumentException] → For invalid zone identifiers.
/// - [CacheCapacityExceededException] → When existing capacity exceeds a new limit.
///
/// {@endtemplate}
abstract interface class ConfigurableCacheStorage {
  /// Sets the [CacheEvictionPolicy] that determines how cache entries are removed.
  ///
  /// The eviction policy defines the strategy used to free cache space when
  /// the maximum capacity is reached or when manual eviction is triggered.
  ///
  /// Common strategies include:
  /// - **LRU (Least Recently Used)** → Evicts the least recently accessed entries.
  /// - **LFU (Least Frequently Used)** → Evicts entries with the fewest accesses.
  /// - **FIFO (First-In-First-Out)** → Evicts entries in insertion order.
  ///
  /// **Parameters:**
  /// - [policy]: The cache eviction strategy to apply.
  ///
  /// **Throws:**
  /// - [ArgumentError] if the provided [policy] is `null`.
  ///
  /// **Example:**
  /// ```dart
  /// cache.setEvictionPolicy(LruEvictionPolicy());
  /// ```
  void setEvictionPolicy(CacheEvictionPolicy policy);

  /// Sets the default Time-To-Live (TTL) for cache entries.
  ///
  /// Entries without an explicitly defined TTL will expire after the
  /// duration specified here. Passing `null` disables expiration entirely,
  /// making entries persistent until evicted by policy or cleared manually.
  ///
  /// **Parameters:**
  /// - [ttl]: The default expiration duration, or `null` for no expiration.
  ///
  /// **Throws:**
  /// - [ArgumentError] if the duration is negative.
  ///
  /// **Example:**
  /// ```dart
  /// cache.setDefaultTtl(Duration(minutes: 15));
  /// ```
  void setDefaultTtl(Duration? ttl);

  /// Configures the time zone used for all time-sensitive cache operations.
  ///
  /// This setting affects all timestamp computations within the cache,
  /// including TTL expiration checks and eviction scheduling.
  ///
  /// **Parameters:**
  /// - [zone]: The canonical time zone identifier (e.g., `"UTC"`, `"Asia/Tokyo"`).
  ///
  /// **Throws:**
  /// - [IllegalArgumentException] if the provided zone is invalid or unsupported.
  ///
  /// **Example:**
  /// ```dart
  /// cache.setZoneId('UTC');
  /// ```
  void setZoneId(String zone);

  /// Defines the maximum number of entries this cache may hold at once.
  ///
  /// When the cache reaches this limit, entries are evicted according to
  /// the currently active [CacheEvictionPolicy]. If `maxEntries` is `null`,
  /// the cache becomes unbounded and will grow indefinitely until cleared.
  ///
  /// **Parameters:**
  /// - [maxEntries]: Maximum number of entries, or `null` for unlimited capacity.
  ///
  /// **Throws:**
  /// - [ArgumentError] if `maxEntries` is negative.
  ///
  /// **Example:**
  /// ```dart
  /// cache.setMaxEntries(1000);
  /// ```
  void setMaxEntries(int? maxEntries);
}

// -------------------------------------------------------------------------------------------------------------
// CACHE MANAGER
// -------------------------------------------------------------------------------------------------------------

/// {@template cacheManager}
/// Manages multiple [CacheStorage] instances and provides lookup by name.
///
/// A cache manager is responsible for creating, managing, and providing
/// access to named cache instances. It serves as the central registry
/// for all caches in an application, providing a unified interface for
/// cache lifecycle management.
///
/// ## Responsibilities
///
/// - **Cache Lookup**: Retrieve cache instances by name
/// - **Cache Lifecycle**: Manage cache creation and destruction
/// - **Cache Registry**: Maintain a registry of all available caches
/// - **Resource Management**: Handle resource cleanup and destruction
///
/// ## Usage
///
/// **Example:**
/// ```dart
/// final cacheManager = ConcurrentMapCacheManager();
/// 
/// // Get or create a cache
/// final userCache = cacheManager.getCache('users');
/// await userCache.put('user:1', user);
/// 
/// // List all cache names
/// final cacheNames = cacheManager.getCacheNames();
/// print('Available caches: $cacheNames');
/// 
/// // Clear all caches
/// await cacheManager.clearAll();
/// 
/// // Proper cleanup
/// await cacheManager.destroy();
/// ```
/// {@endtemplate}
abstract interface class CacheManager {
  /// {@macro getCache}
  /// Retrieves a cache by name.
  ///
  /// If the cache does not exist, the behavior depends on the implementation:
  /// - Some implementations may create the cache on-demand
  /// - Others may return null if the cache doesn't exist
  /// - Some may throw an exception for unknown cache names
  ///
  /// **Parameters:**
  /// - [name]: The name of the cache to retrieve
  ///
  /// **Returns:**
  /// - The [CacheStorage] instance, or null if not found and not created
  ///
  /// **Example:**
  /// ```dart
  /// // Get existing cache
  /// final userCache = await cacheManager.getCache('users');
  /// if (userCache != null) {
  ///   await userCache.put('key', 'value');
  /// }
  /// 
  /// // Try to get non-existent cache
  /// final unknownCache = await cacheManager.getCache('unknown');
  /// if (unknownCache == null) {
  ///   print('Cache "unknown" does not exist');
  /// }
  /// 
  /// // Get cache with dynamic name
  /// final tenantId = 'tenant-123';
  /// final tenantCache = await cacheManager.getCache('users-$tenantId');
  /// ```
  FutureOr<CacheStorage?> getCache(String name);

  /// {@macro getCacheNames}
  /// Returns the names of all caches managed by this cache manager.
  ///
  /// This method provides insight into all available caches and can be
  /// used for monitoring, debugging, or administrative purposes.
  ///
  /// **Returns:**
  /// - A collection of cache names
  ///
  /// **Example:**
  /// ```dart
  /// // List all available caches
  /// final cacheNames = await cacheManager.getCacheNames();
  /// print('Available caches:');
  /// for (final name in cacheNames) {
  ///   print('  - $name');
  /// }
  /// 
  /// // Check if specific cache exists
  /// final cacheNames = await cacheManager.getCacheNames();
  /// if (cacheNames.contains('users')) {
  ///   print('Users cache is available');
  /// }
  /// 
  /// // Monitor cache count
  /// final cacheCount = (await cacheManager.getCacheNames()).length;
  /// print('Managing $cacheCount caches');
  /// ```
  FutureOr<Iterable<String>> getCacheNames();

  /// {@macro clearAllCaches}
  /// Clears all caches managed by this cache manager.
  ///
  /// This is a convenience method that calls [CacheStorage.clear] on all
  /// managed caches. It provides a way to reset all cached data
  /// without destroying the cache instances themselves.
  ///
  /// **Example:**
  /// ```dart
  /// // Clear all caches (e.g., during logout or reset)
  /// await cacheManager.clearAll();
  /// print('All caches cleared');
  /// 
  /// // Clear caches periodically for maintenance
  /// Timer.periodic(Duration(hours: 24), (_) async {
  ///   await cacheManager.clearAll();
  ///   print('Daily cache clearance completed');
  /// });
  /// 
  /// // Verify caches are empty after clearance
  /// final userCache = await cacheManager.getCache('users');
  /// final wrapper = await userCache?.get('any-key');
  /// assert(wrapper == null); // Cache should be empty
  /// ```
  FutureOr<void> clearAll();

  /// {@macro destroyCacheManager}
  /// Destroys all caches and releases resources.
  ///
  /// This method performs complete cleanup of all managed caches,
  /// including releasing any system resources, closing connections,
  /// and ensuring proper disposal. After calling this method, the
  /// cache manager should not be used.
  ///
  /// **Example:**
  /// ```dart
  /// // Proper application shutdown
  /// await cacheManager.clearAll();
  /// await cacheManager.destroy();
  /// print('Cache manager destroyed successfully');
  /// 
  /// // Using in try-finally for resource safety
  /// try {
  ///   // Use cache manager...
  ///   final cache = await cacheManager.getCache('data');
  ///   await cache.put('key', 'value');
  /// } finally {
  ///   await cacheManager.destroy();
  /// }
  /// 
  /// // After destruction, operations should not be attempted
  /// try {
  ///   await cacheManager.getCache('users'); // May throw
  /// } catch (e) {
  ///   print('Cache manager is destroyed: $e');
  /// }
  /// ```
  FutureOr<void> destroy();
}

// -------------------------------------------------------------------------------------------------------------
// CACHE RESOLVER
// -------------------------------------------------------------------------------------------------------------

/// {@template jetleaf_cache_resolver}
/// Strategy interface for resolving one or more [CacheStorage] instances
/// associated with a particular [Cacheable] operation.
///
/// A [CacheResolver] is responsible for determining which caches should
/// participate in a given cache operation (e.g., `@Cacheable`, `@CachePut`,
/// `@CacheEvict`). Implementations can apply a wide range of strategies —
/// from simple name-based lookups to dynamic, context-aware cache routing.
///
/// ### Overview
/// The [CacheResolver] abstraction allows the JetLeaf caching framework
/// to remain decoupled from the underlying cache resolution logic.
/// Instead of binding directly to a single [CacheManager], JetLeaf can
/// delegate the resolution process to one or more resolvers that determine
/// appropriate cache instances based on annotations, environment, or runtime
/// conditions.
///
/// ### Typical Implementations
/// - **[DefaultCacheResolver]** — resolves caches by name from a
///   registered [CacheManager].
/// - **TenantCacheResolver** — routes caches dynamically per tenant.
/// - **CompositeCacheResolver** — aggregates multiple resolvers using
///   a chain-of-responsibility model (see [_CacheResolverChain]).
/// - **DynamicExpressionResolver** — evaluates expressions or conditions
///   to determine target caches at runtime.
///
/// ### Example
/// ```dart
/// class CustomCacheResolver implements CacheResolver {
///   final CacheManager manager;
///
///   CustomCacheResolver(this.manager);
///
///   @override
///   FutureOr<Iterable<Cache>> resolveCaches(Cacheable cacheable) async {
///     final caches = <Cache>[];
///     for (final name in cacheable.cacheNames) {
///       final cache = await manager.getCache('${AppEnv.prefix}::$name');
///       if (cache != null) caches.add(cache);
///     }
///     return caches;
///   }
/// }
/// ```
///
/// ### Resolution Behavior
/// - Implementations must **never return null**; return an empty collection
///   if no caches are resolved.
/// - Implementations may **cache resolved instances** for performance,
///   but must handle invalidation appropriately if the cache topology changes.
/// - The framework may invoke `resolveCaches()` multiple times for different
///   cache operations, so resolution should be efficient and idempotent.
///
/// ### Thread Safety
/// Implementations **must be thread-safe** if used in multi-isolate or
/// concurrent environments.
///
/// ### Error Handling
/// - Throwing an exception will typically abort the resolution process.
/// - When used in composite structures like [_CacheResolverChain],
///   individual resolver errors are ignored to preserve fault tolerance.
///
/// ### See Also
/// - [Cacheable]
/// - [CacheManager]
/// - [CacheStorage]
/// - [_CacheResolverChain]
///
/// {@endtemplate}
abstract interface class CacheResolver {
  /// Resolves the [CacheStorage] instances to be used for a given [Cacheable] operation.
  ///
  /// The returned collection represents all caches that will participate
  /// in the caching operation (read, write, or eviction). If no caches are
  /// applicable, return an empty collection.
  ///
  /// Implementations may inspect any metadata available in the
  /// [Cacheable] annotation, including `cacheNames`, `keyGenerator`,
  /// or `cacheManager`, to decide which caches to target.
  ///
  /// @param cacheable The [Cacheable] metadata defining the cache operation.
  /// @return A collection of resolved [CacheStorage] instances.
  FutureOr<Iterable<CacheStorage>> resolveCaches(Cacheable cacheable);
}

// -------------------------------------------------------------------------------------------------------------
// CACHE EVICTION
// -------------------------------------------------------------------------------------------------------------

/// Represents a cache eviction strategy for determining which cache entry
/// should be removed when the cache reaches capacity or when specific
/// conditions are met.
///
/// In caching systems, it's important to manage limited memory or storage
/// efficiently. Eviction policies encapsulate the logic used to select
/// entries to remove in order to make space for new data. By abstracting
/// this logic, caches can be flexible and support multiple eviction
/// strategies without changing the core caching implementation.
///
/// Implementations of this interface may interface decisions on various factors:
/// - Access patterns (e.g., Least Recently Used, Most Recently Used) [LRU]
/// - Frequency of access (e.g., Least Frequently Used) [LFU]
/// - Time-based expiration (e.g., TTL - Time To Live)
/// - **FIFO (First In First Out)**: Evict the oldest entry
/// - Custom business rules (e.g., priority-based eviction)
///
/// Example usage:
/// ```dart
/// final policy = LruEvictionPolicy();
/// final keyToEvict = policy.determineEvictionCandidate(cache.entries);
/// if (keyToEvict != null) {
///   cache.evict(keyToEvict);
/// }
/// ```
///
/// By providing the `getName()` method, different policies can also be
/// identified for logging, metrics, or debugging purposes.
abstract interface class CacheEvictionPolicy {
  /// Determines which entry in the cache should be evicted.
  ///
  /// Parameters:
  /// - [entries]: A map of cache keys to their corresponding [Cache]
  ///   objects, representing the current state of the cache.
  ///
  /// Returns:
  /// - The key of the entry to evict according to the policy logic.
  /// - Returns `null` if no eviction is necessary at this time.
  ///
  /// Notes:
  /// - This method may be synchronous or asynchronous depending on the
  ///   complexity of the eviction decision.
  /// - The returned key must exist in [entries]. Implementations must handle
  ///   empty or null caches gracefully.
  /// - The eviction decision may consider multiple factors such as last
  ///   access time, access count, TTL, or custom metadata attached to
  ///   [Cache].
  FutureOr<Object?> determineEvictionCandidate(Map<Object, Cache> entries);

  /// Returns a descriptive name for this eviction policy.
  ///
  /// The name is useful for:
  /// - Logging and debugging to identify which eviction strategy is active.
  /// - Metrics collection (e.g., tracking eviction counts per policy).
  /// - Dynamically selecting policies at runtime.
  ///
  /// Example:
  /// ```dart
  /// print('Using eviction policy: ${policy.getName()}'); // "LRU"
  /// ```
  String getName();
}

/// {@template fifo_eviction_policy}
/// A **First-In-First-Out (FIFO) cache eviction policy** that removes
/// the oldest entry from the cache when eviction is necessary.
///
/// FIFO eviction is based solely on the insertion order of entries:
/// the entry that has been in the cache the longest will be evicted
/// first. This policy does **not** take into account access frequency
/// or recency of use, unlike LRU (Least Recently Used) or LFU
/// (Least Frequently Used) policies.
///
/// FIFO is simple, predictable, and suitable for caches where entries
/// are expected to have similar lifetimes or where access patterns
/// are uniform and do not favor recently used items.
///
/// Use this policy in scenarios where:
/// - Deterministic eviction is needed based on creation order.
/// - The cache is used as a queue of elements that expire in order.
/// - Recency or frequency of access is not important.
///
/// ⚠️ Note:
/// While FIFO is straightforward, it may evict frequently accessed
/// entries simply because they were added earlier. Consider LRU
/// if you need eviction based on usage patterns.
/// {@endtemplate}
final class FifoEvictionPolicy implements CacheEvictionPolicy {
  /// Creates a new instance of the FIFO eviction policy.
  ///
  /// {@macro fifo_eviction_policy}
  const FifoEvictionPolicy();

  @override
  FutureOr<Object?> determineEvictionCandidate(Map<Object, Cache> entries) {
    if (entries.isEmpty) return null;

    Object? fifoKey;
    ZonedDateTime? fifoTime;

    for (final entry in entries.entries) {
      if (fifoTime == null || entry.value.getCreatedAt().isBefore(fifoTime)) {
        fifoKey = entry.key;
        fifoTime = entry.value.getCreatedAt();
      }
    }

    return fifoKey;
  }

  @override
  String getName() => 'FIFO';
}

/// {@template lfu_eviction_policy}
/// A **Least-Frequently-Used (LFU) cache eviction policy** for managing
/// cache memory efficiently by evicting the entries that are accessed least often.
///
/// ## Overview
/// LFU maintains an access count for each cached entry. When the cache reaches
/// its capacity and an eviction is required, the entry with the **lowest access
/// frequency** is removed first. This ensures that frequently accessed entries
/// remain in the cache, improving hit rates for common operations.
///
/// LFU is especially useful in workloads with:
/// - Hotspots where certain entries are accessed very frequently.
/// - Rarely accessed entries that should not occupy cache space unnecessarily.
///
/// ## Behavior
/// - Each cache entry has an associated access count that increments each time
///   the entry is read or used.
/// - When eviction is needed, the policy scans all entries and selects the one
///   with the smallest access count.
/// - Ties (entries with the same access count) are resolved arbitrarily, typically
///   based on the iteration order of the entries.
///
/// ## Complexity
/// - **Time Complexity:** O(n) per eviction operation, where `n` is the number of
///   entries in the cache. This is because each entry’s access count must be
///   inspected to find the least frequently used item.
/// - **Space Complexity:** O(n) to maintain access counts for all cached entries.
///
/// ## Trade-offs
/// - LFU can be memory-intensive for large caches since it needs to track access
///   frequency for each entry.
/// - Eviction decision may be slower compared to simpler policies like FIFO or LRU,
///   due to scanning all entries on each eviction.
/// - Works best for workloads with stable access patterns.
///
/// ## Usage Example
/// ```dart
/// final cache = Cache<String, Object>(evictionPolicy: LfuEvictionPolicy());
/// cache.put('a', 1);
/// cache.put('b', 2);
/// cache.get('a'); // access count of 'a' increases
/// cache.put('c', 3); // if capacity exceeded, the entry with lowest access count is evicted
/// ```
/// {@endtemplate}
final class LfuEvictionPolicy implements CacheEvictionPolicy {
  /// Creates a new LFU eviction policy instance.
  ///
  /// {@macro lfu_eviction_policy}
  const LfuEvictionPolicy();

  @override
  FutureOr<Object?> determineEvictionCandidate(Map<Object, Cache> entries) {
    if (entries.isEmpty) return null;

    Object? lfuKey;
    int? lfuCount;

    for (final entry in entries.entries) {
      if (lfuCount == null || entry.value.getAccessCount() < lfuCount) {
        lfuKey = entry.key;
        lfuCount = entry.value.getAccessCount();
      }
    }

    return lfuKey;
  }

  @override
  String getName() => 'LFU';
}

/// {@template lru_eviction_policy}
/// A **Least-Recently-Used (LRU) cache eviction policy** that removes the cache
/// entry that has not been accessed for the longest time when eviction is required.
///
/// ## Overview
/// LRU tracks the last access time of each cache entry. When the cache reaches its
/// maximum capacity and needs to evict an entry, it selects the entry that was
/// **least recently accessed**. This policy helps retain frequently used data while
/// discarding stale or rarely used entries.
///
/// LRU is commonly used in scenarios where:
/// - Recent access patterns are good predictors of future accesses.
/// - Old entries should gradually expire in favor of newer entries.
///
/// ## Behavior
/// - Each cache entry maintains a timestamp of its last access.
/// - On each cache read or write, the last access timestamp is updated.
/// - When eviction is triggered, the policy scans all entries and selects the one
///   with the oldest last access timestamp.
///
/// ## Complexity
/// - **Time Complexity:** O(n) per eviction operation, where `n` is the number of
///   entries in the cache, due to scanning all entries.
/// - **Space Complexity:** O(n) to store last access timestamps for all cache entries.
///
/// ## Trade-offs
/// - Slightly slower than simpler policies like FIFO if implemented with a naive scan.
/// - Requires updating timestamps on each access, which adds minimal overhead.
/// - Works best when recent accesses are more likely to be reused than older ones.
///
/// ## Usage Example
/// ```dart
/// final cache = Cache<String, Object>(evictionPolicy: LruEvictionPolicy());
/// cache.put('a', 1);
/// cache.put('b', 2);
/// cache.get('a'); // updates last accessed time for 'a'
/// cache.put('c', 3); // if capacity exceeded, the least recently used entry is evicted
/// ```
/// {@endtemplate}
final class LruEvictionPolicy implements CacheEvictionPolicy {
  /// Creates a new LRU eviction policy instance.
  ///
  /// {@macro lru_eviction_policy}
  const LruEvictionPolicy();

  @override
  FutureOr<Object?> determineEvictionCandidate(Map<Object, Cache> entries) {
    if (entries.isEmpty) return null;

    Object? lruKey;
    ZonedDateTime? lruTime;

    for (final entry in entries.entries) {
      if (lruTime == null || entry.value.getLastAccessedAt().isBefore(lruTime)) {
        lruKey = entry.key;
        lruTime = entry.value.getLastAccessedAt();
      }
    }

    return lruKey;
  }

  @override
  String getName() => 'LRU';
}

// -------------------------------------------------------------------------------------------------------------
// CACHE EVENTS
// -------------------------------------------------------------------------------------------------------------

/// {@template cache_event}
/// Base class representing an event related to a cache operation.
///
/// This abstract interface class serves as the foundation for all cache-related
/// events within the Jetleaf caching system. A cache event encapsulates
/// contextual information about an operation performed on a specific cache,
/// such as additions, updates, evictions, or expirations.
///
/// Cache events can be published via the application’s event system
/// ([ApplicationEventPublisher]) to enable observers or listeners to react
/// to cache lifecycle changes. For example, you might use this mechanism to:
///
/// - Log cache access or mutation events.
/// - Trigger cache monitoring metrics.
/// - Synchronize distributed caches or propagate invalidation signals.
/// - Audit access to sensitive cached data.
///
/// ## Core Properties
///
/// - [source]: Typically the key of the cache entry involved in this event.
/// - [cacheName]: The name of the cache where the event occurred.
/// - [timestamp]: Optional event timestamp. Defaults to the current time
///   if not provided by the caller.
///
/// ## Usage Example
///
/// ```dart
/// class UserCacheEvictEvent extends CacheEvent {
///   const UserCacheEvictEvent(String key)
///       : super(key, 'userCache');
/// }
///
/// void onCacheEvict(CacheEvent event) {
///   print('Evicted key ${event.source} from cache ${event.cacheName}');
/// }
/// ```
///
/// ## Extending CacheEvent
///
/// Subclasses of [CacheEvent] should represent **specific cache operations**
/// such as:
///
/// - [CachePutEvent]: A value was added or updated in the cache.
/// - [CacheEvictEvent]: A value was removed from the cache.
/// - [CacheClearEvent]: All values in the cache were cleared.
///
/// Each subclass may extend the interface properties with additional metadata
/// relevant to the specific operation (e.g., cached value, TTL, access count).
/// {@endtemplate}
abstract class CacheEvent extends ApplicationEvent {
  /// The name of the cache where this event occurred.
  ///
  /// This identifies the logical cache container (as registered in
  /// the cache manager) affected by the event.
  final String cacheName;

  /// Creates a new cache event.
  ///
  /// [source] is typically the key of the cached entry involved in this event.
  /// [cacheName] identifies the cache where the operation occurred.
  /// [timestamp] optionally overrides the default event timestamp.
  /// 
  /// {@macro cache_event}
  const CacheEvent(super.source, this.cacheName, [super.timestamp]);

  @override
  String getPackageName() => PackageNames.RESOURCE;
}

/// {@template cache_hit_event}
/// Event published when a cached value is successfully retrieved.
///
/// This event indicates that a cache lookup operation has succeeded and
/// returned a value without invoking the underlying method or data source.
/// Observers can use this event to track cache hit rates, monitor
/// performance, or trigger logging and metrics collection.
///
/// ## Core Properties
///
/// - [source]: The key of the cached entry that was accessed.
/// - [cacheName]: The name of the cache from which the value was retrieved.
/// - [value]: The actual value retrieved from the cache (may be `null` if
///   the cache stores `null` values explicitly).
/// - [timestamp]: Optional timestamp of the event occurrence.
///
/// ## Usage Example
///
/// ```dart
/// void onCacheHit(CacheHitEvent event) {
///   print('Cache hit for key ${event.source} in cache ${event.cacheName}');
///   print('Retrieved value: ${event.value}');
/// }
/// ```
///
/// Observers can use this information to implement:
/// - Cache hit/miss metrics.
/// - Conditional logging of frequently accessed keys.
/// - Performance monitoring or adaptive caching strategies.
/// {@endtemplate}
final class CacheHitEvent extends CacheEvent {
  /// The value that was retrieved from the cache.
  final Object? value;

  /// Creates a new cache hit event.
  ///
  /// [source] is the key of the cached entry.
  /// [cacheName] identifies the cache where the hit occurred.
  /// [value] is the retrieved value (may be `null`).
  /// [timestamp] optionally overrides the default event timestamp.
  /// 
  /// {@macro cache_hit_event}
  const CacheHitEvent(super.source, super.cacheName, [this.value, super.timestamp]);

  @override
  String toString() => 'CacheHitEvent(cache: $cacheName, key: ${getSource()}, value: $value)';
}

/// {@template cache_miss_event}
/// Event published when a cache lookup fails to find a value.
///
/// This event indicates that a cache lookup operation did not return a
/// stored value, and the underlying method or data source will likely
/// need to be invoked to compute or retrieve the value. Observers can
/// use this event to track cache miss rates, monitor performance,
/// or trigger logging and metrics collection.
///
/// ## Core Properties
///
/// - [source]: The key of the cache entry that was looked up.
/// - [cacheName]: The name of the cache where the lookup occurred.
/// - [timestamp]: Optional timestamp of when the event occurred.
///
/// ## Usage Example
///
/// ```dart
/// void onCacheMiss(CacheMissEvent event) {
///   print('Cache miss for key ${event.source} in cache ${event.cacheName}');
/// }
/// ```
///
/// Observers can use this information to:
/// - Track cache efficiency (hit/miss ratios).
/// - Identify frequently missed keys for potential preloading.
/// - Monitor performance of cache-backed operations.
/// {@endtemplate}
final class CacheMissEvent extends CacheEvent {
  /// Creates a new cache miss event.
  ///
  /// [source] is the key that was looked up in the cache.
  /// [cacheName] is the name of the cache where the miss occurred.
  /// [timestamp] optionally overrides the default event timestamp.
  /// 
  /// {@macro cache_miss_event}
  const CacheMissEvent(super.source, super.cacheName, [super.timestamp]);

  @override
  String toString() => 'CacheMissEvent(cache: $cacheName, key: ${getSource()})';
}

/// {@template cache_put_event}
/// Event published when a value is stored in a cache.
///
/// This event indicates that a cache put operation has successfully
/// stored a value in the specified cache. Observers can use this event
/// to track cache writes, monitor TTL usage, or trigger logging and metrics collection.
///
/// ## Core Properties
///
/// - [source]: The key associated with the cached value.
/// - [cacheName]: The name of the cache where the value was stored.
/// - [value]: The object that was cached.
/// - [ttl]: Optional time-to-live duration applied to the cached entry.
/// - [timestamp]: Optional timestamp of when the event occurred.
///
/// ## Usage Example
///
/// ```dart
/// void onCachePut(CachePutEvent event) {
///   print('Stored value for key ${event.source} in cache ${event.cacheName} with TTL ${event.ttl}');
/// }
/// ```
///
/// Observers can use this information to:
/// - Track cache write operations and patterns.
/// - Monitor TTL usage for cache entries.
/// - Collect metrics or trigger actions based on cached values.
/// {@endtemplate}
final class CachePutEvent extends CacheEvent {
  /// The value that was stored in the cache.
  final Object? value;

  /// The TTL (time-to-live) applied to this cached entry, if any.
  final Duration? ttl;

  /// Creates a new cache put event.
  ///
  /// [source] is the cache key.
  /// [cacheName] is the name of the cache.
  /// [value] is the object stored in the cache.
  /// [ttl] optionally specifies the time-to-live for the entry.
  /// [timestamp] optionally overrides the event timestamp.
  /// 
  /// {@macro cache_put_event}
  const CachePutEvent(super.source, super.cacheName, [this.value, this.ttl, super.timestamp]);

  @override
  String toString() => 'CachePutEvent(cache: $cacheName, key: ${getSource()}, ttl: $ttl)';
}

/// {@template cache_evict_event}
/// Event published when an entry is removed (evicted) from a cache.
///
/// This event indicates that a cache eviction operation has occurred,
/// either due to explicit removal, TTL expiration, eviction policies,
/// or other cache management rules. Observers can use this event
/// to track cache invalidations, logging, or metrics collection.
///
/// ## Core Properties
///
/// - [source]: The key of the cache entry that was evicted.
/// - [cacheName]: The name of the cache from which the entry was evicted.
/// - [reason]: The reason for eviction, such as 'manual', 'policy', or 'ttl_expired'.
/// - [timestamp]: Optional timestamp of when the event occurred.
///
/// ## Usage Example
///
/// ```dart
/// void onCacheEvict(CacheEvictEvent event) {
///   print('Evicted key ${event.source} from cache ${event.cacheName} due to ${event.reason}');
/// }
/// ```
///
/// Observers can use this information to:
/// - Track cache eviction patterns.
/// - Monitor TTL or policy-driven evictions.
/// - Trigger logging, metrics collection, or dependent invalidations.
/// {@endtemplate}
final class CacheEvictEvent extends CacheEvent {
  /// The reason why the cache entry was evicted.
  ///
  /// Common examples include:
  /// - `'manual'` – explicitly removed by a user or operation.
  /// - `'policy'` – evicted due to a cache eviction policy.
  /// - `'ttl_expired'` – evicted because the time-to-live expired.
  final String reason;

  /// Creates a new cache evict event.
  ///
  /// [source] is the cache key being evicted.
  /// [cacheName] is the name of the cache.
  /// [reason] describes why the eviction occurred.
  /// [timestamp] optionally overrides the event timestamp.
  /// 
  /// {@macro cache_evict_event}
  const CacheEvictEvent(super.source, super.cacheName, this.reason, [super.timestamp]);

  @override
  String toString() => 'CacheEvictEvent(cache: $cacheName, key: ${getSource()}, reason: $reason)';
}

/// {@template cache_expire_event}
/// Event published when a cache entry expires due to reaching its TTL (time-to-live).
///
/// This event indicates that a cached value was automatically invalidated
/// because it exceeded its defined lifespan. Observers can use this event
/// to track expiration behavior, logging, metrics collection, or
/// triggering dependent invalidations.
///
/// ## Core Properties
///
/// - [source]: The key of the cache entry that expired.
/// - [cacheName]: The name of the cache where the entry expired.
/// - [value]: The value of the entry that expired (if available).
/// - [ttl]: The time-to-live duration that caused the expiration.
/// - [timestamp]: Optional timestamp of when the event occurred.
///
/// ## Usage Example
///
/// ```dart
/// void onCacheExpire(CacheExpireEvent event) {
///   print('Cache entry ${event.source} in ${event.cacheName} expired after ${event.ttl}');
/// }
/// ```
///
/// Observers can use this information to:
/// - Track TTL-based cache expirations.
/// - Monitor cache usage patterns and TTL effectiveness.
/// - Trigger dependent actions when specific entries expire.
/// {@endtemplate}
final class CacheExpireEvent extends CacheEvent {
  /// The value of the cache entry that expired.
  final Object? value;

  /// The time-to-live (TTL) duration that caused the expiration.
  final Duration ttl;

  /// Creates a new cache expiration event.
  ///
  /// [source] is the cache key that expired.
  /// [cacheName] is the name of the cache.
  /// [ttl] is the TTL that triggered the expiration.
  /// [value] is the optional expired value.
  /// [timestamp] optionally overrides the event timestamp.
  /// 
  /// {@macro cache_expire_event}
  const CacheExpireEvent(super.source, super.cacheName, this.ttl, [this.value, super.timestamp]);

  @override
  String toString() => 'CacheExpireEvent(cache: $cacheName, key: ${getSource()}, ttl: $ttl)';
}

/// {@template cache_clear_event}
/// Event published when one or more entries in a cache are cleared.
///
/// This event indicates that cache entries have been removed either
/// manually or due to an administrative operation (e.g., `clear()` or
/// `clearAll()`). Observers can use this event to track cache usage,
/// logging, metrics, or trigger dependent actions when caches are cleared.
///
/// ## Core Properties
///
/// - [source]: The key that triggered the clear operation. For `clearAll`
///   operations, this may be a placeholder or null.
/// - [cacheName]: The name of the cache where the entries were cleared.
/// - [entriesCleared]: The number of cache entries that were removed.
/// - [timestamp]: Optional timestamp of when the event occurred.
///
/// ## Usage Example
///
/// ```dart
/// void onCacheClear(CacheClearEvent event) {
///   print('Cleared ${event.entriesCleared} entries from cache ${event.cacheName}');
/// }
/// ```
///
/// Observers can use this information to:
/// - Track cache size and usage over time.
/// - Detect bulk clear operations for auditing or monitoring.
/// - Trigger dependent cleanup or recalculation logic after cache clearance.
/// {@endtemplate}
final class CacheClearEvent extends CacheEvent {
  /// The number of cache entries that were cleared.
  final int entriesCleared;

  /// Creates a new cache clear event.
  ///
  /// [source] is the key or object that initiated the clear operation.
  /// [cacheName] is the name of the cache affected.
  /// [entriesCleared] is the count of entries removed from the cache.
  /// [timestamp] optionally overrides the event timestamp.
  /// 
  /// {@macro cache_clear_event}
  const CacheClearEvent(super.source, super.cacheName, this.entriesCleared, [super.timestamp]);

  @override
  String toString() => 'CacheClearEvent(cache: $cacheName, entriesCleared: $entriesCleared)';
}

// -------------------------------------------------------------------------------------------------------------
// CACHE ERROR HANDLER
// -------------------------------------------------------------------------------------------------------------

/// {@template jet_cache_error_handler}
/// A strategy interface for handling exceptions that occur during cache operations.
///
/// Implementations of this interface allow custom handling, logging, suppression,
/// or recovery from errors raised during cache access (get, put, evict, or clear).
///
/// By default, most JetLeaf cache managers will catch and delegate such errors
/// to a configured [CacheErrorHandler], ensuring that cache failures do **not**
/// disrupt the main application flow.
///
/// ### Purpose
///
/// Cache systems are often non-critical to primary application logic and should
/// fail gracefully when possible. A [CacheErrorHandler] allows:
///
/// - Logging and monitoring of transient or persistent cache issues.
/// - Recovery or fallback logic (e.g., retrying a failed cache write).
/// - Filtering or ignoring specific error types (e.g., network disconnects).
/// - Ensuring consistent behavior across distributed or heterogeneous caches.
///
/// ### Example
///
/// ```dart
/// final handler = LoggingCacheErrorHandler();
///
/// try {
///   await cache.put('user:42', user);
/// } catch (e, st) {
///   await handler.onPutError(e, st, cache, 'user:42', user);
/// }
/// ```
///
/// Implementations may be **asynchronous** or **synchronous**, depending on
/// whether recovery logic (like remote logging) is required.
///
/// ### Common Implementations
///
/// - `SimpleCacheErrorHandler`: Logs and ignores all errors.
/// - `ThrowingCacheErrorHandler`: Rethrows errors for strict environments.
/// - `SilentCacheErrorHandler`: Silently swallows all cache errors.
///
/// ### Contract
///
/// - Methods in this interface **must never throw** unhandled exceptions.
///   Doing so would defeat the purpose of error containment.
/// - The [CacheStorage] instance and [key] (or [value]) parameters should be treated
///   as diagnostic metadata only — they must **not** be modified.
///
/// ### Related Components
///
/// - [CacheStorage]: The target cache instance where the operation failed.
/// - [CacheManager]: The coordinator that invokes this handler.
/// - [CacheOperation]: The high-level abstraction describing the failed operation.
/// {@endtemplate}
abstract interface class CacheErrorHandler {
  // ---------------------------------------------------------------------------
  // Error Hooks
  // ---------------------------------------------------------------------------

  /// {@template jet_cache_error_handler_get}
  /// Handles an error that occurred during a cache **get** operation.
  ///
  /// This method is invoked when a call to [CacheStorage.get] or [CacheStorage.getAs]
  /// fails due to an exception — for example, deserialization issues,
  /// conversion errors, or backend retrieval failures.
  ///
  /// Implementations may log the error, suppress it, or trigger fallbacks,
  /// but **must not rethrow** unless the entire cache operation should abort.
  ///
  /// Parameters:
  /// - [exception]: The error or exception thrown during the operation.
  /// - [stackTrace]: The stack trace associated with the error.
  /// - [cache]: The cache instance that encountered the error.
  /// - [key]: The key being retrieved at the time of the error.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<void> onGet(Object e, StackTrace st, Cache cache, Object key) async {
  ///   logger.warn('Failed to read from cache ${cache.getName()} for key $key', e, st);
  /// }
  /// ```
  /// {@endtemplate}
  FutureOr<void> onGet(Object exception, StackTrace stackTrace, CacheStorage cache, Object key);

  /// {@template jet_cache_error_handler_put}
  /// Handles an error that occurred during a cache **put** operation.
  ///
  /// This hook is triggered when storing a value fails — for example, if
  /// serialization fails, the cache is full, or a remote backend is unavailable.
  ///
  /// Parameters:
  /// - [exception]: The error or exception thrown during the operation.
  /// - [stackTrace]: The stack trace associated with the error.
  /// - [cache]: The cache instance that encountered the error.
  /// - [key]: The key being written to.
  /// - [value]: The value that was being stored when the error occurred.
  ///
  /// Implementations can:
  /// - Log the error for observability.
  /// - Retry or delay re-insertion.
  /// - Silently ignore transient failures (e.g., temporary connection loss).
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<void> onPut(Object e, StackTrace st, Cache cache, Object key, Object? value) async {
  ///   metrics.increment('cache.put.failures');
  ///   logger.error('Cache put failed for ${cache.getName()}[$key]', e, st);
  /// }
  /// ```
  /// {@endtemplate}
  FutureOr<void> onPut(Object exception, StackTrace stackTrace, CacheStorage cache, Object key, Object? value);

  /// {@template jet_cache_error_handler_evict}
  /// Handles an error that occurred during a cache **evict** operation.
  ///
  /// Invoked when a call to [CacheStorage.evict] or [CacheStorage.evictIfPresent] throws
  /// due to an unexpected condition (e.g., I/O failure in persistent caches).
  ///
  /// Parameters:
  /// - [exception]: The exception that occurred.
  /// - [stackTrace]: The stack trace associated with the error.
  /// - [cache]: The cache instance being modified.
  /// - [key]: The key being evicted.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<void> onEvict(Object e, StackTrace st, Cache cache, Object key) async {
  ///   logger.warn('Failed to evict key $key from cache ${cache.getName()}');
  /// }
  /// ```
  /// {@endtemplate}
  FutureOr<void> onEvict(Object exception, StackTrace stackTrace, CacheStorage cache, Object key);

  /// {@template jet_cache_error_handler_clear}
  /// Handles an error that occurred during a cache **clear** or **invalidate** operation.
  ///
  /// Called when [CacheStorage.clear] or [CacheStorage.invalidate] throws an exception.
  /// Typical causes include persistent store failures or concurrent modification.
  ///
  /// Parameters:
  /// - [exception]: The exception thrown during the clear operation.
  /// - [stackTrace]: The stack trace associated with the error.
  /// - [cache]: The cache instance being cleared.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<void> onClear(Object e, StackTrace st, Cache cache) async {
  ///   logger.error('Failed to clear cache ${cache.getName()}', e, st);
  /// }
  /// ```
  /// {@endtemplate}
  FutureOr<void> onClear(Object exception, StackTrace stackTrace, CacheStorage cache);
}

// -------------------------------------------------------------------------------------------------------------
// CACHE REGISTRY
// -------------------------------------------------------------------------------------------------------------

/// A central registry for all cache-related infrastructure components.
///
/// Implementations of [CacheErrorHandlerRegistry] are responsible for collecting and
/// managing all configurable cache subsystems — such as cache managers,
/// key generators, resolvers, and error handlers.
///
/// This interface acts as the integration point for [CacheConfigurer]s
/// that contribute pods to the caching subsystem.
///
/// Typical implementations (like [AbstractCacheSupport]) provide
/// thread-safe storage, ordering, and fallback logic for registered
/// components.
abstract interface class CacheErrorHandlerRegistry {
  /// Sets the global [CacheErrorHandler] for the cache system.
  ///
  /// The registered error handler is invoked whenever a cache operation
  /// (get, put, evict, or clear) throws an exception. Implementations may
  /// choose to log, suppress, or propagate the exception.
  ///
  /// If not explicitly configured, a default error handler (either
  /// logging or throwing, depending on the environment) is used.
  void setErrorHandler(CacheErrorHandler errorHandler);
}

/// {@template jet_cache_resolver_registry}
/// A registry contract for managing multiple [CacheResolver] pods within JetLeaf.
///
/// The [CacheResolverRegistry] defines the mechanism for registering and
/// coordinating [CacheResolver] instances. These resolvers are responsible for
/// mapping a [Cacheable] annotation (logical cache operation) to one or more
/// physical [CacheStorage] instances managed by underlying [CacheManager] pods.
///
/// ### Responsibilities
///
/// - Acts as a central registry for all cache resolvers.
/// - Ensures resolvers can be added dynamically or during initialization.
/// - Serves as the delegation point for composite resolver chains, such as
///   [CompositeCacheResolver], to maintain deterministic lookup order.
///
/// ### Usage
///
/// A typical implementation (e.g., [CompositeCacheResolver]) will:
///
/// 1. Maintain a synchronized set of resolvers.
/// 2. Support lifecycle discovery via [PodFactoryAware] and [SmartInitializingSingleton].
/// 3. Provide resolution delegation through a resolver chain.
///
/// ### Example
///
/// ```dart
/// final registry = CompositeCacheResolver();
/// registry.addResolver(myCustomResolver);
/// ```
///
/// ### Related Components
///
/// - [CacheResolver]: Resolves [Cacheable] annotations to concrete [CacheStorage] instances.
/// - [CompositeCacheResolver]: A registry implementation that manages multiple resolvers.
/// - [CacheManager]: Provides physical cache storage for resolved caches.
/// {@endtemplate}
abstract interface class CacheResolverRegistry {
  /// Adds a [CacheResolver] pod to this registry.
  ///
  /// Each resolver is responsible for resolving a [Cacheable] annotation
  /// into one or more concrete [CacheStorage] instances. This allows logical
  /// cache definitions to be mapped to physical caches in a modular,
  /// extensible manner.
  void addResolver(CacheResolver cacheResolver);
}

/// {@template jet_cache_manager_registry}
/// A registry contract for managing multiple [CacheManager] pods within JetLeaf.
///
/// The [CacheManagerRegistry] defines the mechanism for registering and
/// coordinating [CacheManager] instances. Each manager represents a distinct
/// source of caches — for example, in-memory, distributed, or Redis-backed
/// caches.
///
/// ### Responsibilities
///
/// - Acts as a central registry for all cache manager pods.
/// - Supports multiple managers, which can be combined in a composite or
///   chained structure for unified cache access.
/// - Ensures deterministic registration order and safe concurrent updates.
///
/// ### Usage
///
/// A typical implementation (e.g., [CompositeCacheManager]) will:
///
/// 1. Maintain a synchronized set of registered cache managers.
/// 2. Provide unified access and delegation to underlying managers.
/// 3. Support lifecycle integration via [PodFactoryAware] and
///    [SmartInitializingSingleton].
///
/// ### Example
///
/// ```dart
/// final registry = CompositeCacheManager();
/// registry.addManager(SimpleInMemoryCacheManager());
/// registry.addManager(RedisCacheManager());
/// ```
///
/// ### Related Components
///
/// - [CacheManager]: Represents physical or logical cache stores.
/// - [CompositeCacheManager]: A registry implementation that aggregates multiple managers.
/// - [CacheResolver]: Resolves [Cacheable] annotations to caches provided by managers.
/// {@endtemplate}
abstract interface class CacheManagerRegistry {
  /// Registers a [CacheManager] pod with this registry.
  ///
  /// Each manager provides one or more caches. Multiple managers can be
  /// combined in a composite or chained structure to enable unified
  /// cache operations across heterogeneous backends.
  void addManager(CacheManager cacheManager);
}

/// {@template jet_cache_storage_registry}
/// Defines a registry contract for managing [CacheStorage] instances.
///
/// A [CacheStorageRegistry] is responsible for registering concrete cache
/// storage implementations that back one or more [Cache] instances.
/// Each registered [CacheStorage] typically represents a physical persistence
/// or memory layer within the caching infrastructure.
///
/// ### Usage
///
/// This interface is implemented by composite or configurable cache systems
/// that manage multiple storage backends (e.g., in-memory, file-based,
/// distributed).
///
/// ### Example
///
/// ```dart
/// registry.addStorage(InMemoryCacheStorage());
/// registry.addStorage(FileCacheStorage());
/// ```
///
/// ### Related Components
///
/// - [CacheStorage]
/// - [CacheManager]
/// - [CompositeCacheManager]
///
/// {@endtemplate}
abstract interface class CacheStorageRegistry {
  /// Registers a [CacheStorage] instance within the registry.
  ///
  /// Registered storages serve as underlying physical stores for cache data.
  /// Multiple storages can coexist, providing a unified access layer through
  /// composite cache management.
  void addStorage(CacheStorage storage);
}

// -------------------------------------------------------------------------------------------------------------
// CACHE CONFIGURER
// -------------------------------------------------------------------------------------------------------------

/// {@template jet_cache_configurer}
/// Contract for JetLeaf cache configuration contributors.
///
/// The [CacheConfigurer] interface allows framework extensions, modules, or
/// application-level components to **programmatically register, modify, or
/// replace cache infrastructure components** during system initialization.
///
/// These configuration hooks are invoked automatically by JetLeaf’s
/// dependency injection lifecycle, typically during [SmartInitializingSingleton]
/// callbacks or at startup of the [CacheAutoConfiguration] subsystem.
///
/// ### Overview
///
/// Implementations of this interface provide centralized points for customizing
/// JetLeaf’s cache behavior — without the need for manual wiring or hardcoded
/// bindings. This includes:
///
/// - Adding or overriding [CacheManager] instances (e.g., Redis, in-memory, hybrid)
/// - Registering [CacheResolver]s for annotation-driven cache resolution
/// - Providing [KeyGenerator]s for cache key derivation
/// - Registering [CacheStorage] backends
///
/// Each configuration method receives a specialized registry that exposes
/// an additive, fluent-style API for component registration.
///
/// ### Example
///
/// ```dart
/// @Service()
/// final class CustomCacheConfigurer implements CacheConfigurer {
///   @override
///   void configure(CacheRegistry registry) {
///     // Optional: Global setup or metrics registration
///   }
///
///   @override
///   void configureCacheResolver(CacheResolverRegistry registry) {
///     registry.addResolver(SimpleCacheResolver(MyCacheManager()));
///   }
///
///   @override
///   void configureCacheManager(CacheManagerRegistry registry) {
///     registry.addManager(SimpleInMemoryCacheManager());
///   }
///
///   @override
///   void configureKeyGenerator(KeyGeneratorRegistry registry) {
///     registry.addKeyGenerator(DefaultKeyGenerator());
///   }
///
///   @override
///   void configureCacheStorage(CacheStorageRegistry registry) {
///     registry.addStorage(InMemoryCacheStorage('default'));
///   }
/// 
///   @override
///   void configureCache(String name, ConfigurableCacheStorage storage) {
///     if (name == 'users') {
///       storage
///         ..setEvictionPolicy(LruEvictionPolicy())
///         ..setDefaultTtl(Duration(minutes: 30))
///         ..setMaxEntries(500);
///     }
///   }
/// }
/// ```
///
/// ### Related Components
///
/// - [CacheResolverRegistry] — Registers and chains cache resolvers.
/// - [CacheManagerRegistry] — Manages sources of cache instances.
/// - [KeyGeneratorRegistry] — Determines cache key generation strategy.
/// - [CacheStorageRegistry] — Manages underlying cache stores.
/// - [CacheErrorHandlerRegistry] — Top-level composite registry passed during initialization.
///
/// {@endtemplate}
abstract class CacheConfigurer {
  /// Called during cache subsystem initialization to allow custom
  /// registration of cache-related components.
  ///
  /// Implementations should use the provided [registry] to add or
  /// replace cache managers, resolvers, key generators, or error handlers.
  void configureErrorHandler(CacheErrorHandlerRegistry registry) {}

  /// Registers and configures cache resolvers.
  ///
  /// Called after JetLeaf auto-discovers [CacheResolver] pods but before
  /// resolution chains are finalized. Implementations may use this hook to
  /// register additional resolvers or override existing ones.
  void configureCacheResolver(CacheResolverRegistry registry) {}

  /// Registers and configures cache managers.
  ///
  /// This method is typically used to integrate different cache management
  /// strategies, such as distributed caching or hybrid caching layers.
  void configureCacheManager(CacheManagerRegistry registry) {}

  /// Registers and configures cache key generators.
  ///
  /// This allows the system to control how cache keys are derived from
  /// method invocations or custom annotations.
  void configureKeyGenerator(KeyGeneratorRegistry registry) {}

  /// Registers and configures cache storages.
  ///
  /// Each storage corresponds to a physical or logical cache backend (e.g.,
  /// in-memory, Redis, file-based). Multiple storages may be registered
  /// under different cache managers.
  void configureCacheStorage(CacheStorageRegistry registry) {}

  /// Configures a [ConfigurableCacheStorage] instance conditionally by name.
  ///
  /// Implementations should use this method to customize the behavior of
  /// a specific cache identified by its logical name. The method will be
  /// called for every discovered cache during initialization — and the
  /// implementation decides whether to apply configuration.
  ///
  /// This enables fine-grained control over individual caches without
  /// modifying the global configuration.
  ///
  /// Example:
  /// ```dart
  /// void configure(String name, ConfigurableCacheStorage storage) {
  ///   if (name == 'sessions') {
  ///     storage
  ///       ..setEvictionPolicy(FifoEvictionPolicy())
  ///       ..setDefaultTtl(Duration(hours: 1))
  ///       ..setMaxEntries(2000);
  ///   }
  /// }
  /// ```
  void configure(String name, ConfigurableCacheStorage storage) {}
}

// -------------------------------------------------------------------------------------------------------------
// CACHE OPERATION
// -------------------------------------------------------------------------------------------------------------

/// {@template jet_cache_operation_context}
/// Defines the execution context for a cache operation within JetLeaf’s
/// caching subsystem.
///
/// A [CacheOperationContext] represents the complete state of a cacheable
/// method invocation, providing access to method metadata, generated cache
/// keys, operation definitions, and resolved cache instances.  
///
/// This interface bridges the gap between **runtime cache operations**
/// (like `Cacheable`, `CachePut`, `CacheEvict`) and their **execution logic**
/// (implemented by [CacheOperation] objects).
///
/// ### Responsibilities
/// - Generating and storing the **cache key** for the current method invocation.
/// - Tracking and managing **cached results** and **execution results**.
/// - Serving as a unified view of method invocation metadata through
///   [MethodInvocation].
/// - Handling cache-related errors and resolving applicable caches.
///
/// ### Lifecycle Overview
/// 1. A cacheable method is invoked.
/// 2. A [CacheOperationContext] is created by the cache interceptor.
/// 3. The operation (e.g., `CacheableOperation`) calls [generateKey] and
///    [resolveCaches] to locate or modify caches.
/// 4. Results or errors are recorded using [setCachedResult],
///    [setResult], or [CacheErrorHandler].
/// 5. The context may then be reused for post-execution processing.
///
/// ### Example
/// ```dart
/// final context = MyCacheOperationContext(invocation, cacheOperation);
///
/// // Generate a cache key
/// final key = await context.generateKey(annotation.keyGenerator);
///
/// // Fetch or store results
/// if (context.hasCachedResult()) {
///   return context.getCachedResult();
/// }
///
/// final result = await invocation.proceed();
/// context.setResult(result);
///
/// await cache.put(key, result);
/// ```
///
/// ### Implementations
/// Custom implementations may be created for advanced caching behavior,
/// such as distributed cache contexts, asynchronous cache coordination,
/// or context-aware error policies.
///
/// ### Thread Safety
/// Implementations should ensure thread safety, particularly when caching
/// is performed concurrently or in reactive execution models.
///
/// ### See Also
/// - [CacheOperation]
/// - [Cacheable]
/// - [CacheResolver]
/// - [CacheErrorHandler]
/// - [MethodInvocation]
/// {@endtemplate}
abstract interface class CacheOperationContext<T> implements OperationContext, CacheResolver, CacheErrorHandler {
  /// Generates a unique cache key for the current method invocation.
  ///
  /// This key is typically based on the target object, method signature,
  /// and argument values (see [KeyGenerator]).
  /// 
  /// - param [preferredKeyGeneratorName] is for any custom generator the developer prefers to use
  FutureOr<Object> generateKey([String? preferredKeyGeneratorName]);

  /// Records a retrieved value from the cache.
  ///
  /// This marks the current invocation as having a cached result,
  /// allowing subsequent checks through [hasCachedResult].
  void setCachedResult(Object? result);

  /// Marks the context as a cache miss.
  ///
  /// Indicates that no cached value was found for the generated key.
  void setCacheMiss();

  /// Returns `true` if the current invocation resulted in a cache miss.
  bool isCacheMiss();

  /// Returns `true` if the target method produced a result.
  bool hasResult();

  /// Retrieves the actual result from the target method invocation.
  ///
  /// Returns `null` if no result is yet available.
  Object? getResult();

  /// Sets the result produced by the target method.
  ///
  /// This allows caching operations (e.g., [CachePutOperation]) to store
  /// the method result into cache layers.
  void setResult(T? result);

  /// Returns `true` if a cached result was found.
  bool hasCachedResult();

  /// Retrieves the cached result associated with the current context.
  ///
  /// Returns `null` if no cached result is available.
  Object? getCachedResult();

  /// Returns the reflective method invocation associated with this context.
  ///
  /// Contains method metadata and invocation state such as arguments,
  /// target instance, and return value handling.
  MethodInvocation<T> getMethodInvocation();
}

/// {@template jetleaf_cache_operation}
/// Defines the contract for a cache operation within the JetLeaf caching subsystem.
///
/// A [CacheOperation] represents a specific cache behavior such as:
/// - **Read** operations (`@Cacheable`) — retrieving values from cache if present
/// - **Write/Update** operations (`@CachePut`) — updating or inserting cached values
/// - **Eviction** operations (`@CacheEvict`) — removing specific or all cache entries
///
/// Each concrete implementation encapsulates a distinct cache strategy and
/// interacts with the cache layer through a [CacheOperationContext].
///
/// ### Responsibilities
/// Implementations of [CacheOperation] are responsible for:
/// - Evaluating caching conditions and expressions (`condition`, `unless`)
/// - Resolving the appropriate cache instances via the [CacheResolver]
/// - Handling cache read/write/eviction logic
/// - Managing cache-related exceptions using the [CacheOperationContext]
///
/// ### Example
/// ```dart
/// final operation = CacheableOperation(cacheableAnnotation);
/// await operation.execute(context);
/// ```
///
/// In the example above, the [CacheableOperation] attempts to read a cached value
/// from the configured caches, falling back to the target method invocation if
/// the cache miss occurs.
///
/// ### Integration Notes
/// - The [CacheOperationContext] provided to [execute] acts as the carrier for
///   runtime information including method invocation data, expression resolvers,
///   and cache access coordination.
/// - Each [CacheOperation] implementation is typically stateless and reusable
///   across multiple invocations.
/// - The caching infrastructure (e.g., `CacheInterceptor`) determines which
///   operation to invoke based on the detected annotation at runtime.
///
/// ### Error Handling
/// - Use the [CacheOperationContext.CacheErrorHandler] method to safely delegate cache
///   access errors without interrupting method execution.
/// - Operations should never throw directly unless the error indicates a critical
///   framework or configuration issue.
///
/// ### Extensibility
/// Developers can define custom [CacheOperation] implementations for specialized
/// caching logic such as:
/// - Time-based expiration
/// - Hierarchical or multi-tier caching
/// - External service coordination (e.g., distributed cache refresh)
///
/// ### See Also
/// - [CacheableOperation]
/// - [CachePutOperation]
/// - [CacheEvictOperation]
/// - [CacheOperationContext]
/// - [CacheResolver]
/// {@endtemplate}
abstract interface class CacheOperation {
  /// Base constructor for cache operations.
  ///
  /// All concrete cache operations must call this to ensure consistent
  /// initialization semantics.
  const CacheOperation();

  /// Executes this cache operation with the provided [CacheOperationContext].
  ///
  /// Implementations define the full logic of the cache action:
  /// - For read operations, attempt cache lookup before proceeding.
  /// - For write operations, store the computed result after execution.
  /// - For eviction operations, remove affected entries according to configuration.
  ///
  /// @param context The runtime context providing cache metadata and execution state.
  FutureOr<void> execute<T>(CacheOperationContext<T> context);
}