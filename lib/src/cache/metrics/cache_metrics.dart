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