import 'dart:async';

import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_logging/logging.dart';

import 'default_rate_limit_storage.dart';

/// {@template jet_rollback_capable_rate_limit_storage}
/// An in-memory rate-limit storage variant that supports **best-effort rollback** of
/// a prior successful consume.
///
/// This storage is useful when performing `tryConsume` operations across multiple
/// storages and needing to undo earlier increments if a later storage denies
/// the request. Rollback is **best-effort**: it only decrements counters if entries
/// exist and are not expired, and silently ignores failures.
///
/// ### Purpose
///
/// - Enable atomic-like behavior when consuming from multiple rate-limit storages.
/// - Provide a safe way to undo prior increments in scenarios where partial
///   consumption occurs.
/// - Maintain metrics consistency via [metrics] if enabled.
///
/// ### Key Responsibilities
///
/// - Extend [DefaultRateLimitStorage] with rollback capability.
/// - Decrement counters for a specific identifier/window via [rollbackConsume].
/// - Remove expired or empty entries to maintain internal storage hygiene.
/// - Log rollback failures at DEBUG level without affecting the main flow.
///
/// ### Example
///
/// ```dart
/// final rollbackStorage = RollbackCapableConcurrentMapRateLimitStorage.named('default');
/// rollbackStorage.setApplicationContext(appContext);
///
/// // Attempt to consume across multiple storages
/// final allowedFirst = await storage1.isAllowed('user:42', 10, Duration(minutes: 1));
/// final allowedSecond = await storage2.isAllowed('user:42', 10, Duration(minutes: 1));
///
/// if (!allowedSecond) {
///   // Undo the first storage increment
///   await rollbackStorage.rollbackConsume('user:42', Duration(minutes: 1));
/// }
/// ```
///
/// ### Notes
///
/// - Rollback is **best-effort**: exceptions are logged at DEBUG level and do not
///   propagate.
/// - If the rate-limit entry is expired or missing, rollback silently does nothing.
/// - Metrics (_RateLimitMetrics) are adjusted if enabled.
///
/// {@endtemplate}
final class RollbackCapableRateLimitStorage extends DefaultRateLimitStorage {
  final Log _logger = LogFactory.getLog(RollbackCapableRateLimitStorage);

  /// {@macro jet_rollback_capable_rate_limit_storage}
  RollbackCapableRateLimitStorage.named(super.name) : super.named();

  /// {@macro jet_rollback_capable_rate_limit_storage}
  RollbackCapableRateLimitStorage() : super();

  /// Best-effort rollback: decrement the counter for the given [identifier] and [window].
  ///
  /// If an entry exists and is not expired, the count is decremented by 1.
  /// If the count reaches zero, the inner map is cleaned up to prevent memory leaks.
  ///
  /// **Behavior notes:**
  /// - Does nothing if no entry exists or the entry is expired.
  /// - Metrics are adjusted only if `_metricsEnabled` is true.
  /// - Exceptions are swallowed and logged at DEBUG level.
  FutureOr<void> rollbackConsume(Object identifier, Duration window) async {
    final windowKey = getWindowKey(window);

    await synchronizedAsync(store, () async {
      final inner = store[identifier];
      if (inner == null) return;

      final entry = inner[windowKey];
      if (entry == null) return;

      // If expired, nothing to rollback
      if (entry.isExpired()) return;

      try {
        // decrement once (best-effort) and get the new count
        final concrete = entry;
        final newCount = concrete.decrement(); // should return the new count (>= 0)

        // adjust metrics only if enabled
        if (metricsEnabled) {
          metrics.decrementAllowed(identifier);
        }

        // if the count reached zero, remove the inner key and cleanup outer map
        if (newCount <= 0) {
          inner.remove(windowKey);
          if (inner.isEmpty) {
            store.remove(identifier);
          }
        }
      } catch (e, st) {
        // Best-effort rollback: swallow exceptions but consider logging at DEBUG level.

        if (_logger.getIsDebugEnabled()) {
          _logger.debug('rollbackConsume failed for $identifier: $e', error: e, stacktrace: st);
        }
      }
    });
  }
}