import 'dart:async';

import '../storage/cache.dart';

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