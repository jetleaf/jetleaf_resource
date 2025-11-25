import '../eviction_policy/cache_eviction_policy.dart';
import 'cache_storage.dart';

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
abstract interface class ConfigurableCacheStorage implements CacheStorage {
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