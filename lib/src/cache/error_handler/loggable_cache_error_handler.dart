// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
//
// This source file is part of the JetLeaf Framework and is protected
// under copyright law. You may not copy, modify, or distribute this file
// except in compliance with the JetLeaf license.
//
// For licensing terms, see the LICENSE file in the root of this project.
// ---------------------------------------------------------------------------
// 
// 🔧 Powered by Hapnium — the Dart backend engine 🍃

import 'dart:async';

import 'package:jetleaf_logging/logging.dart';

import '../storage/cache_storage.dart';
import 'cache_error_handler.dart';

/// {@template jet_cache_error_handler_loggable}
/// A [CacheErrorHandler] implementation that logs all cache operation failures.
///
/// This handler ensures that errors encountered during cache access do not
/// interrupt the normal control flow of the application, while still providing
/// detailed diagnostic logs for observability and debugging.
///
/// ### Behavior
///
/// - **Never throws**: all exceptions are logged and suppressed.
/// - **Severity-aware logging**: prefers `error` level logging when available,
///   and falls back to `warn` if the logger does not support errors.
/// - **Contextual messages**: each log entry includes the cache name and key
///   (or operation type) involved in the failure.
///
/// ### Example
///
/// ```dart
/// final cache = ConcurrentMapCache('users', conversionService);
/// final handler = LoggableCacheErrorHandler(appLogger);
///
/// try {
///   await cache.put('user:42', user);
/// } catch (e, st) {
///   await handler.onPut(e, st, cache, 'user:42', user);
/// }
/// ```
///
/// ### Usage Notes
///
/// - This handler is suitable as the **default** for production environments.
/// - Combine it with an application-wide [Log] instance to capture cache
///   errors in your structured logging pipeline (e.g., ELK, Datadog).
///
/// ### Logging Policy
///
/// | Condition | Log Level |
/// |------------|------------|
/// | `logger.getIsErrorEnabled() == true` | Logs as `error` |
/// | `logger.getIsErrorEnabled() == false` and `getIsWarnEnabled() == true` | Logs as `warn` |
/// | Otherwise | No-op |
///
/// ### Example Log Output
///
/// ```text
/// [ERROR] Failed to get from cache "users" for key "user:42"
/// [WARN ] Failed to clear cache "sessions"
/// ```
///
/// {@endtemplate}
final class LoggableCacheErrorHandler implements CacheErrorHandler {
  /// The logger instance used to record cache operation errors.
  final Log _logger = LogFactory.getLog(LoggableCacheErrorHandler);

  /// Creates a new [LoggableCacheErrorHandler] that delegates all cache errors
  /// to the provided [_logger].
  LoggableCacheErrorHandler();

  @override
  FutureOr<void> onGet(Object e, StackTrace st, CacheStorage cache, Object key) async {
    final message = 'Failed to get from cache ${cache.getName()} for key $key';

    if (_logger.getIsErrorEnabled()) {
      _logger.error(message, error: e, stacktrace: st);
    } else if (_logger.getIsWarnEnabled()) {
      _logger.warn(message, error: e, stacktrace: st);
    }
  }

  @override
  FutureOr<void> onPut(Object e, StackTrace st, CacheStorage cache, Object key, Object? value) async {
    final message = 'Failed to put into cache ${cache.getName()} for key $key';

    if (_logger.getIsErrorEnabled()) {
      _logger.error(message, error: e, stacktrace: st);
    } else if (_logger.getIsWarnEnabled()) {
      _logger.warn(message, error: e, stacktrace: st);
    }
  }

  @override
  FutureOr<void> onEvict(Object e, StackTrace st, CacheStorage cache, Object key) async {
    final message = 'Failed to evict from cache ${cache.getName()} for key $key';

    if (_logger.getIsErrorEnabled()) {
      _logger.error(message, error: e, stacktrace: st);
    } else if (_logger.getIsWarnEnabled()) {
      _logger.warn(message, error: e, stacktrace: st);
    }
  }

  @override
  FutureOr<void> onClear(Object e, StackTrace st, CacheStorage cache) async {
    final message = 'Failed to clear cache ${cache.getName()}';

    if (_logger.getIsErrorEnabled()) {
      _logger.error(message, error: e, stacktrace: st);
    } else if (_logger.getIsWarnEnabled()) {
      _logger.warn(message, error: e, stacktrace: st);
    }
  }
}