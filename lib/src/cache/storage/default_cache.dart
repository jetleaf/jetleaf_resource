import 'package:jetleaf_lang/lang.dart';

import 'cache.dart';

/// {@template jet_cache_value}
/// Represents a single cache entry's stored value and its associated metadata.
///
/// A [DefaultCache] encapsulates not only the cached [value] itself but also
/// essential temporal metadata used for expiration, access tracking, and
/// observability. Each instance corresponds to one logical cache entry.
///
/// ### Purpose
///
/// JetLeaf caches utilize [DefaultCache] as the fundamental unit of stored
/// data, enabling both **time-based eviction policies** and **usage analytics**.
/// It tracks:
///
/// - The **original creation time** ([getCreatedAt]) of the cache entry.
/// - The **time-to-live (TTL)** duration ([getTtl]) defining its validity period.
/// - The **last access timestamp** ([getLastAccessedAt]) to support LRU/LFU
///   eviction strategies.
/// - The **access count** ([getAccessCount]) for frequency-based policies.
///
/// Together, these metrics allow caches to make informed decisions about
/// retention, expiration, and promotion.
///
/// ### Behavior
///
/// - If [_ttl] is `null`, the entry is considered **non-expiring**.
/// - [isExpired] computes the current state dynamically using [ZonedDateTime].
/// - Each call to [recordAccess] increments [_accessCount] and updates
///   [_lastAccessedAt], ensuring recency and usage tracking.
/// - [getRemainingTtl] calculates the remaining lifetime at query time.
///
/// ### Related Components
///
/// - [Cache]: The interface implemented by this class.
/// - [CacheStorage]: Uses [DefaultCache] to wrap stored entries with metadata.
/// - [CacheManager]: Interprets TTLs and access data for eviction policies.
/// - [CacheMetrics]: May aggregate statistics derived from [DefaultCache] usage.
///
/// ### Example
///
/// ```dart
/// final entry = _CacheValue(
///   user,
///   Duration(minutes: 10),
///   ZonedDateTime.now(ZoneId.systemDefault()),
///   ZoneId.systemDefault(),
/// );
///
/// if (!entry.isExpired()) {
///   final user = entry.get(); // retrieve cached value
///   entry.recordAccess(); // mark read
/// }
/// ```
///
/// ### Notes
///
/// - Implementations assume [ZonedDateTime] and [ZoneId] are provided by the
///   JetLeaf temporal subsystem for accurate timezone-sensitive computations.
/// - Instances are **immutable** except for access tracking fields
///   ([_accessCount] and [_lastAccessedAt]).
/// {@endtemplate}
final class DefaultCache implements Cache {
  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// The actual **cached value** stored in this entry.
  ///
  /// May be `null` if the original insertion explicitly cached a `null` result.
  /// Consumers should handle nullability gracefully.
  ///
  /// - Accessed via [get].
  /// - Remains immutable for the lifetime of the cache entry.
  final Object? value;

  /// The **time-to-live (TTL)** duration associated with this entry.
  ///
  /// When non-null, it represents the validity window from the creation time
  /// ([getCreatedAt]) after which the entry is considered expired.
  ///
  /// If `null`, the entry never expires automatically and must be evicted
  /// manually or via capacity policies.
  final Duration? _ttl;

  /// The **creation timestamp** for this entry.
  ///
  /// This field records when the cache item was originally written to the cache.
  /// It forms the baseline for calculating age ([getAgeInMilliseconds]) and
  /// remaining TTL ([getRemainingTtl]).
  final ZonedDateTime _createdAt;

  /// The **timezone context** used for all time computations.
  ///
  /// Ensures that expiration and access calculations are consistent and
  /// timezone-aware, critical in distributed or regionally localized systems.
  final ZoneId _zoneId;

  /// The total number of times this entry has been **accessed**.
  ///
  /// Incremented via [recordAccess]. Used by LFU (Least Frequently Used)
  /// cache strategies and analytics components such as [CacheMetrics].
  int _accessCount = 0;

  /// The **most recent access timestamp**.
  ///
  /// Updated every time [recordAccess] is called. Used by LRU
  /// (Least Recently Used) eviction strategies and recency analytics.
  late ZonedDateTime _lastAccessedAt;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  /// {@macro jet_cache_value}
  ///
  /// Creates a new cache entry encapsulating [value] and its temporal metadata.
  ///
  /// - [_ttl] defines how long the entry remains valid.
  /// - [_createdAt] marks when it was initially inserted.
  /// - [_zoneId] provides timezone awareness for expiration calculations.
  ///
  /// On construction, [_lastAccessedAt] is initialized to the current
  /// [ZonedDateTime] in the provided [_zoneId].
  DefaultCache(this.value, this._ttl, this._createdAt, this._zoneId) {
    _lastAccessedAt = ZonedDateTime.now(_zoneId);
  }

  @override
  Object? get() => value;

  @override
  int getAccessCount() => _accessCount;

  @override
  int getAgeInMilliseconds() => ZonedDateTime.now(_zoneId).toDateTime().difference(_createdAt.toDateTime()).inMilliseconds;

  @override
  ZonedDateTime getCreatedAt() => _createdAt;

  @override
  ZonedDateTime getLastAccessedAt() => _lastAccessedAt;

  @override
  Duration? getRemainingTtl() {
    if (_ttl == null) return null;
    final expirationTime = _createdAt.plus(_ttl);
    return expirationTime.toDateTime().difference(ZonedDateTime.now(_zoneId).toDateTime());
  }

  @override
  int getTimeSinceLastAccessInMilliseconds() => ZonedDateTime.now(_zoneId).toDateTime().difference(_lastAccessedAt.toDateTime()).inMilliseconds;

  @override
  Duration? getTtl() => _ttl;

  @override
  bool isExpired() {
    if (_ttl == null) return false;
    return ZonedDateTime.now(_zoneId).isAfter(_createdAt.plus(_ttl));
  }

  @override
  void recordAccess() {
    _lastAccessedAt = ZonedDateTime.now(_zoneId);
    _accessCount++;
  }
}