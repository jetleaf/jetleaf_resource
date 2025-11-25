import 'dart:async';

import '../storage/cache.dart';
import 'cache_eviction_policy.dart';

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