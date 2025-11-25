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

import '../storage/cache_storage.dart';
import 'cache_error_handler.dart';

/// {@template jet_cache_error_handler_throwable}
/// A strict [CacheErrorHandler] implementation that immediately rethrows any
/// exception encountered during cache operations.
///
/// ### Behavior
///
/// - **Always throws**: every error is rethrown using
///   [Error.throwWithStackTrace], preserving the original context.
/// - **No logging or suppression**: this handler prioritizes visibility and
///   fail-fast semantics over resiliency.
///
/// ### Example
///
/// ```dart
/// final handler = ThrowableCacheErrorHandler();
///
/// try {
///   await cache.evict('user:42');
/// } catch (e, st) {
///   await handler.onEvict(e, st, cache, 'user:42');
///   // The above call will rethrow [e] with its stack trace.
/// }
/// ```
///
/// ### Use Cases
///
/// - Unit tests, where cache integrity must be guaranteed.
/// - Development or debug environments where silent suppression is undesirable.
/// - Situations where cache consistency impacts correctness.
///
/// ### Contract
///
/// - This handler **should not** be used in production environments without
///   proper error isolation, as it can propagate transient failures upward.
/// - The rethrow mechanism preserves the exact [StackTrace], making it suitable
///   for diagnostic or audit tooling.
///
/// {@endtemplate}
final class ThrowableCacheErrorHandler implements CacheErrorHandler {
  /// Creates a new [ThrowableCacheErrorHandler].
  ///
  /// This implementation rethrows all cache operation exceptions exactly as
  /// they were caught, preserving the original stack trace.
  const ThrowableCacheErrorHandler();

  @override
  FutureOr<void> onGet(Object e, StackTrace st, CacheStorage cache, Object key) async {
    Error.throwWithStackTrace(e, st);
  }

  @override
  FutureOr<void> onPut(Object e, StackTrace st, CacheStorage cache, Object key, Object? value) async {
    Error.throwWithStackTrace(e, st);
  }

  @override
  FutureOr<void> onEvict(Object e, StackTrace st, CacheStorage cache, Object key) async {
    Error.throwWithStackTrace(e, st);
  }

  @override
  FutureOr<void> onClear(Object e, StackTrace st, CacheStorage cache) async {
    Error.throwWithStackTrace(e, st);
  }
}