import 'dart:async';

import '../storage/cache_storage.dart';

/// {@template jet_cache_error_handler}
/// A strategy interface for handling exceptions that occur during cache operations.
///
/// Implementations of this interface allow custom handling, logging, suppression,
/// or recovery from errors raised during cache access (get, put, evict, or clear).
///
/// By default, most JetLeaf cache managers will catch and delegate such errors
/// to a configured [CacheErrorHandler], ensuring that cache failures do **not**
/// disrupt the main application flow.
///
/// ### Purpose
///
/// Cache systems are often non-critical to primary application logic and should
/// fail gracefully when possible. A [CacheErrorHandler] allows:
///
/// - Logging and monitoring of transient or persistent cache issues.
/// - Recovery or fallback logic (e.g., retrying a failed cache write).
/// - Filtering or ignoring specific error types (e.g., network disconnects).
/// - Ensuring consistent behavior across distributed or heterogeneous caches.
///
/// ### Example
///
/// ```dart
/// final handler = LoggingCacheErrorHandler();
///
/// try {
///   await cache.put('user:42', user);
/// } catch (e, st) {
///   await handler.onPutError(e, st, cache, 'user:42', user);
/// }
/// ```
///
/// Implementations may be **asynchronous** or **synchronous**, depending on
/// whether recovery logic (like remote logging) is required.
///
/// ### Common Implementations
///
/// - `SimpleCacheErrorHandler`: Logs and ignores all errors.
/// - `ThrowingCacheErrorHandler`: Rethrows errors for strict environments.
/// - `SilentCacheErrorHandler`: Silently swallows all cache errors.
///
/// ### Contract
///
/// - Methods in this interface **must never throw** unhandled exceptions.
///   Doing so would defeat the purpose of error containment.
/// - The [CacheStorage] instance and [key] (or [value]) parameters should be treated
///   as diagnostic metadata only — they must **not** be modified.
///
/// ### Related Components
///
/// - [CacheStorage]: The target cache instance where the operation failed.
/// - [CacheManager]: The coordinator that invokes this handler.
/// - [CacheOperation]: The high-level abstraction describing the failed operation.
/// {@endtemplate}
abstract interface class CacheErrorHandler {
  // ---------------------------------------------------------------------------
  // Error Hooks
  // ---------------------------------------------------------------------------

  /// {@template jet_cache_error_handler_get}
  /// Handles an error that occurred during a cache **get** operation.
  ///
  /// This method is invoked when a call to [CacheStorage.get] or [CacheStorage.getAs]
  /// fails due to an exception — for example, deserialization issues,
  /// conversion errors, or backend retrieval failures.
  ///
  /// Implementations may log the error, suppress it, or trigger fallbacks,
  /// but **must not rethrow** unless the entire cache operation should abort.
  ///
  /// Parameters:
  /// - [exception]: The error or exception thrown during the operation.
  /// - [stackTrace]: The stack trace associated with the error.
  /// - [cache]: The cache instance that encountered the error.
  /// - [key]: The key being retrieved at the time of the error.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<void> onGet(Object e, StackTrace st, Cache cache, Object key) async {
  ///   logger.warn('Failed to read from cache ${cache.getName()} for key $key', e, st);
  /// }
  /// ```
  /// {@endtemplate}
  FutureOr<void> onGet(Object exception, StackTrace stackTrace, CacheStorage cache, Object key);

  /// {@template jet_cache_error_handler_put}
  /// Handles an error that occurred during a cache **put** operation.
  ///
  /// This hook is triggered when storing a value fails — for example, if
  /// serialization fails, the cache is full, or a remote backend is unavailable.
  ///
  /// Parameters:
  /// - [exception]: The error or exception thrown during the operation.
  /// - [stackTrace]: The stack trace associated with the error.
  /// - [cache]: The cache instance that encountered the error.
  /// - [key]: The key being written to.
  /// - [value]: The value that was being stored when the error occurred.
  ///
  /// Implementations can:
  /// - Log the error for observability.
  /// - Retry or delay re-insertion.
  /// - Silently ignore transient failures (e.g., temporary connection loss).
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<void> onPut(Object e, StackTrace st, Cache cache, Object key, Object? value) async {
  ///   metrics.increment('cache.put.failures');
  ///   logger.error('Cache put failed for ${cache.getName()}[$key]', e, st);
  /// }
  /// ```
  /// {@endtemplate}
  FutureOr<void> onPut(Object exception, StackTrace stackTrace, CacheStorage cache, Object key, Object? value);

  /// {@template jet_cache_error_handler_evict}
  /// Handles an error that occurred during a cache **evict** operation.
  ///
  /// Invoked when a call to [CacheStorage.evict] or [CacheStorage.evictIfPresent] throws
  /// due to an unexpected condition (e.g., I/O failure in persistent caches).
  ///
  /// Parameters:
  /// - [exception]: The exception that occurred.
  /// - [stackTrace]: The stack trace associated with the error.
  /// - [cache]: The cache instance being modified.
  /// - [key]: The key being evicted.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<void> onEvict(Object e, StackTrace st, Cache cache, Object key) async {
  ///   logger.warn('Failed to evict key $key from cache ${cache.getName()}');
  /// }
  /// ```
  /// {@endtemplate}
  FutureOr<void> onEvict(Object exception, StackTrace stackTrace, CacheStorage cache, Object key);

  /// {@template jet_cache_error_handler_clear}
  /// Handles an error that occurred during a cache **clear** or **invalidate** operation.
  ///
  /// Called when [CacheStorage.clear] or [CacheStorage.invalidate] throws an exception.
  /// Typical causes include persistent store failures or concurrent modification.
  ///
  /// Parameters:
  /// - [exception]: The exception thrown during the clear operation.
  /// - [stackTrace]: The stack trace associated with the error.
  /// - [cache]: The cache instance being cleared.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<void> onClear(Object e, StackTrace st, Cache cache) async {
  ///   logger.error('Failed to clear cache ${cache.getName()}', e, st);
  /// }
  /// ```
  /// {@endtemplate}
  FutureOr<void> onClear(Object exception, StackTrace stackTrace, CacheStorage cache);
}