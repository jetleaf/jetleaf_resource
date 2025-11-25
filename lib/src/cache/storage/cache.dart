import 'package:jetleaf_lang/lang.dart';

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