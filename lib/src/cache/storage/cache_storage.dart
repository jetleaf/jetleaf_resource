import 'dart:async';

import 'package:jetleaf_lang/lang.dart';

import '../../base/resource.dart';
import 'cache.dart';

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