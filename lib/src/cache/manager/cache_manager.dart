import 'dart:async';

import '../storage/cache_storage.dart';

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