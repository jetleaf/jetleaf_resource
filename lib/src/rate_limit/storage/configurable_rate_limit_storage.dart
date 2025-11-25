import 'rate_limit_storage.dart';

/// {@template configurable_rate_limit_storage}
/// Represents a configurable rate-limit storage that allows runtime tuning
/// of critical operational parameters, primarily the time zone used for
/// window tracking and expiration calculations.
///
/// Implementations of this interface can be backed by in-memory maps,
/// distributed caches, or persistent databases. The storage is responsible
/// for tracking request counts, reset times, and TTL windows for each
/// identifier being rate-limited.
///
/// By configuring parameters like the time zone, developers ensure that
/// rate-limit calculations remain consistent across distributed systems,
/// scheduled tasks, and monitoring operations.
///
/// Typical use cases include:
/// - Rate-limiting API requests per user, IP, or client key
/// - Implementing rolling windows for burst control
/// - Synchronizing expiration logic across multiple instances
/// - Supporting multiple geographic regions with different time zones
///
/// {@endtemplate}
abstract interface class ConfigurableRateLimitStorage implements RateLimitStorage {
  /// {@macro configurable_rate_limit_storage}
  ///
  /// Sets the time zone used by the storage for all time-based computations,
  /// including creation timestamps, reset times, and TTL-based expirations.
  ///
  /// Changing the zone affects:
  /// - Determining when a rate-limit window expires
  /// - Computing the remaining time for requests
  /// - Eviction or reset scheduling for expired entries
  ///
  /// **Parameters:**
  /// - [zone]: The canonical identifier of the time zone (e.g., `"UTC"`, `"Europe/Berlin"`, `"Asia/Seoul"`).
  ///
  /// **Throws:**
  /// - [IllegalArgumentException] if the provided zone is invalid, unrecognized, or unsupported.
  ///
  /// **Example:**
  /// ```dart
  /// final storage = MyRateLimitStorage();
  /// storage.setZoneId('UTC'); // Use UTC for consistent cross-region limits
  /// ```
  void setZoneId(String zone);
}