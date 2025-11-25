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

import '../annotations.dart';
import '../core/cache_operation_context.dart';
import 'cache_operation.dart';
import 'validate_and_get_cache.dart';

/// {@template jet_cache_put_operation}
/// Represents the execution logic for a `@CachePut` method within the JetLeaf
/// caching subsystem.
///
/// A **cache put operation** is responsible for writing or updating data in
/// one or more caches after a successful method invocation. Unlike
/// [`CacheableOperation`], which attempts to retrieve from cache first,
/// `CachePutOperation` always proceeds with the method execution before
/// inserting or updating the result in cache.
///
/// ### Overview
/// This operation ensures that a method result is stored in all configured
/// caches when the caching conditions are met. It is often used for write-through
/// or synchronization scenarios where you want to ensure the cache reflects
/// the most up-to-date state of the underlying data source.
///
/// ### Execution Flow
/// The operation follows this ordered sequence:
///
/// 1. **Evaluate the `unless` condition** — if this evaluates to `true`, caching
///    is completely bypassed for this invocation.
/// 2. **Evaluate the `condition` expression** — if this evaluates to `false`,
///    no cache write occurs.
/// 3. **Check for a valid result** — if the invocation has no result (e.g., void,
///    null, or not yet available), caching is skipped.
/// 4. **Resolve cache instances** — using the [CacheOperationContext], all
///    applicable [CacheManager] instances are located.
/// 5. **Generate a cache key** — using the provided [CustomKeyGenerator] or
///    the framework default.
/// 6. **Write to each cache** — the resolved result is stored in every configured
///    cache under the generated key.
///
/// ### Error Handling
/// - Errors encountered during cache write are captured and reported to the
///   [CacheOperationContext] using [CacheErrorType.PUT].
/// - An exception in one cache does not stop the process — the next cache is
///   attempted.
/// - The operation itself never rethrows unless the error handler explicitly
///   propagates.
///
/// ### Thread-Safety
/// The implementation is stateless and therefore safe for concurrent invocation
/// across multiple method calls. All per-invocation data is encapsulated inside
/// the [CacheOperationContext].
///
/// ### Example
/// ```dart
/// @CachePut(cacheNames: {'users'}, condition: WhenExpr('#result != null'))
/// Future<User> updateUser(User user) async {
///   final updated = await repository.save(user);
///   return updated;
/// }
/// ```
///
/// ### Behavior Summary
/// | Step | Description | Outcome |
/// |------|--------------|----------|
/// | 1 | Evaluate `unless` | Skip caching if `true` |
/// | 2 | Evaluate `condition` | Skip caching if `false` |
/// | 3 | Validate result | Skip if no result |
/// | 4 | Resolve caches | Discover target cache managers |
/// | 5 | Generate key | Derive cache key from context |
/// | 6 | Write to cache | Store result value |
///
/// ### Usage Scenarios
/// - Keeping cache entries consistent with updates in the data source.
/// - Ensuring cache freshness after a modification call (e.g., `save`, `update`, or `patch`).
/// - Coordinating multiple caches under a unified write policy.
///
/// {@endtemplate}
final class CachePutOperation implements CacheOperation {
  /// The `@CachePut` annotation defining this operation’s configuration.
  ///
  /// Includes cache names, conditional expressions, and optional components
  /// such as a custom key generator or cache resolver.
  final CachePut annotation;

  /// Creates a new [CachePutOperation] for the given [annotation].
  const CachePutOperation(this.annotation);

  /// {@macro jet_cache_put_operation}
  @override
  FutureOr<void> execute<T>(CacheOperationContext<T> context) async {
    // ─────────────────────────────────────────────────────────────
    // STEP 1: Resolve caches and determine if caching should proceed.
    // ─────────────────────────────────────────────────────────────
    final caches = await validateAndGetCaches(annotation, context);
    if (caches == null) {
      return null;
    }

    // ─────────────────────────────────────────────────────────────
    // STEP 2: Ensure a valid method result is available
    // ─────────────────────────────────────────────────────────────
    if (!context.hasResult()) {
      return; // Nothing to cache — likely a void or incomplete operation.
    }

    // ─────────────────────────────────────────────────────────────
    // STEP 3: Generate and compute cache key
    // ─────────────────────────────────────────────────────────────
    final key = await context.generateKey(annotation.keyGenerator);
    final result = context.getResult();

    // ─────────────────────────────────────────────────────────────
    // STEP 4: Write result to each resolved cache
    // ─────────────────────────────────────────────────────────────
    for (final cache in caches) {
      try {
        await cache.put(key, result, annotation.ttl);
      } catch (e, st) {
        await context.onPut(e, st, cache, key, result);
      }
    }
  }
}