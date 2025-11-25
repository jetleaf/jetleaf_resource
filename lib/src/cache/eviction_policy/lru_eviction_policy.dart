import 'dart:async';

import 'package:jetleaf_lang/lang.dart';

import '../storage/cache.dart';
import 'cache_eviction_policy.dart';

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