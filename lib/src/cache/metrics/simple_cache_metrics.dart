import 'cache_metrics.dart';

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
/// final metrics = SimpleCacheMetrics('userCache'); // internal per-cache metrics
/// metrics.recordHit('user:42');
/// metrics.recordPut('user:42');
/// final graph = metrics.buildGraph(); // structured summary for telemetry
/// ```
/// {@endtemplate}
final class SimpleCacheMetrics implements CacheMetrics {
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
  SimpleCacheMetrics(this._name);

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