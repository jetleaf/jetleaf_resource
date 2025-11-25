import 'dart:async';

import 'package:jetleaf_lang/lang.dart';

import '../storage/cache.dart';
import 'cache_eviction_policy.dart';

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