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

import 'annotations.dart';
import 'cache.dart';

/// {@template jet_cacheable_operation}
/// Represents the execution logic for a `@Cacheable` method within the JetLeaf
/// resource management framework.
///
/// A **cacheable operation** determines whether a method invocation should be
/// served from cache or executed normally, based on the declarative rules defined
/// in the [`Cacheable`] annotation and the associated runtime [CacheOperationContext].
///
/// ### Overview
/// This operation forms the foundation of JetLeaf’s transparent caching layer.
/// It follows a reactive, non-blocking contract that integrates seamlessly with
/// asynchronous or synchronous methods.
///
/// When invoked, it performs the following sequence:
///
/// 1. **Evaluate exclusion (`unless`) condition** — if this evaluates to `true`,
///    caching is completely bypassed for the current invocation.
/// 2. **Evaluate eligibility (`condition`) expression** — if this evaluates to
///    `false`, the method execution proceeds without cache interaction.
/// 3. **Resolve cache instances** from the context (typically via the
///    [CacheResolver] or PodFactory lookup).
/// 4. **Generate a unique cache key** using the configured [CustomKeyGenerator],
///    method parameters, and context metadata.
/// 5. **Attempt cache retrieval** — if a matching entry is found, it is applied
///    directly as the method result, marking a cache hit.
/// 6. **Mark cache miss** — if no cache contains the requested entry, the context
///    flags the invocation for standard method execution (after which a
///    `CachePut` or similar operation may populate it).
///
/// ### Error Handling
/// - Cache lookup failures (I/O, serialization, or resolver errors) are captured
///   via [CacheErrorType.GET] and reported to the [CacheOperationContext].
/// - A failure in one cache does not terminate the chain; the next cache is
///   attempted automatically.
///
/// ### Thread-Safety and Concurrency
/// Implementations are stateless and safe for concurrent access. The contextual
/// state is isolated in the provided [CacheOperationContext].
///
/// ### Example
/// ```dart
/// @Cacheable(cacheNames: {'users'}, condition: WhenExpr('#args[0] != null'))
/// Future<User?> findUserById(String id) async {
///   return await database.findUser(id);
/// }
/// ```
///
/// ### Behavior Summary
/// | Step | Description | Outcome |
/// |------|--------------|----------|
/// | 1 | Evaluate `unless` | Skip caching if `true` |
/// | 2 | Evaluate `condition` | Skip caching if `false` |
/// | 3 | Resolve caches | May throw if unavailable |
/// | 4 | Generate key | Delegates to key generator |
/// | 5 | Attempt get() | Apply result if hit |
/// | 6 | Cache miss | Proceed with method execution |
///
/// {@endtemplate}
final class CacheableOperation implements CacheOperation {
  /// The `@Cacheable` annotation that defines cache metadata and behavior.
  ///
  /// This includes cache names, key generator, conditions, and resolver configuration.
  final Cacheable annotation;

  /// Creates a new [CacheableOperation] bound to a specific annotation instance.
  const CacheableOperation(this.annotation);

  /// {@macro jet_cacheable_operation}
  @override
  FutureOr<void> execute<T>(CacheOperationContext<T> context) async {
    // ─────────────────────────────────────────────────────────────
    // STEP 1: Evaluate the "unless" condition — skip if true
    // ─────────────────────────────────────────────────────────────
    final unlessResult = await annotation.unless.shouldApply(context);
    if (unlessResult) {
      // Caching is explicitly disabled for this invocation.
      return;
    }

    // ─────────────────────────────────────────────────────────────
    // STEP 2: Evaluate the "condition" — skip if false
    // ─────────────────────────────────────────────────────────────
    final conditionResult = await annotation.condition.shouldApply(context);
    if (!conditionResult) {
      // Does not meet caching criteria.
      return;
    }

    // ─────────────────────────────────────────────────────────────
    // STEP 3: Resolve cache instances and generate a cache key
    // ─────────────────────────────────────────────────────────────
    final caches = await context.resolveCaches(annotation);
    final key = await context.generateKey(annotation.keyGenerator);

    // ─────────────────────────────────────────────────────────────
    // STEP 4: Attempt retrieval from each cache
    // ─────────────────────────────────────────────────────────────
    for (final cache in caches) {
      try {
        final cachedValue = await cache.get(key);
        if (cachedValue != null) {
          // Cache hit — immediately return cached data
          context.setCachedResult(cachedValue.get());
          return;
        }
      } catch (e, st) {
        // Isolate and record cache-specific exceptions
        await context.onGet(e, st, cache, key);
      }
    }

    // ─────────────────────────────────────────────────────────────
    // STEP 5: No hit found — mark cache miss
    // ─────────────────────────────────────────────────────────────
    context.setCacheMiss();
  }
}

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
    // STEP 1: Evaluate the "unless" condition — skip if true
    // ─────────────────────────────────────────────────────────────
    final unlessResult = await annotation.unless.shouldApply(context);
    if (unlessResult) {
      return; // Explicitly prevented from caching.
    }

    // ─────────────────────────────────────────────────────────────
    // STEP 2: Evaluate the "condition" expression — skip if false
    // ─────────────────────────────────────────────────────────────
    final conditionResult = await annotation.condition.shouldApply(context);
    if (!conditionResult) {
      return; // Not eligible for cache update.
    }

    // ─────────────────────────────────────────────────────────────
    // STEP 3: Ensure a valid method result is available
    // ─────────────────────────────────────────────────────────────
    if (!context.hasResult()) {
      return; // Nothing to cache — likely a void or incomplete operation.
    }

    // ─────────────────────────────────────────────────────────────
    // STEP 4: Resolve caches and compute cache key
    // ─────────────────────────────────────────────────────────────
    final caches = await context.resolveCaches(annotation);
    final key = await context.generateKey(annotation.keyGenerator);
    final result = context.getResult();

    // ─────────────────────────────────────────────────────────────
    // STEP 5: Write result to each resolved cache
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

/// {@template jet_cache_evict_operation}
/// Represents the execution logic for a `@CacheEvict` method within the JetLeaf
/// caching subsystem.
///
/// A **cache eviction operation** removes one or more entries from configured
/// caches based on the annotation configuration and evaluated runtime
/// conditions. This operation helps maintain cache integrity by ensuring that
/// outdated or invalid data is removed when a mutating method executes.
///
/// ### Overview
/// The `CacheEvictOperation` provides flexible cache removal semantics for
/// post-modification scenarios (e.g., after a database update). It supports both
/// **selective eviction** (removing a specific key) and **bulk eviction**
/// (clearing all entries in the cache).
///
/// ### Execution Flow
/// The eviction logic proceeds as follows:
///
/// 1. **Evaluate the `unless` condition** — if this evaluates to `true`, the
///    eviction process is skipped.
/// 2. **Evaluate the `condition` expression** — if this evaluates to `false`,
///    eviction does not proceed.
/// 3. **Resolve cache instances** — all [CacheManager] instances specified by
///    the annotation are located through the [CacheOperationContext].
/// 4. **Perform the eviction**:
///    - If [`allEntries`] is `true`, clears all entries from each cache.
///    - Otherwise, generates a cache key and evicts the corresponding entry.
/// 5. **Handle errors gracefully** — exceptions raised by cache implementations
///    are caught and reported to the [CacheOperationContext].
///
/// ### Configuration Options
/// - **`allEntries`** — If `true`, clears the entire cache rather than a single key.
/// - **`beforeInvocation`** — If `true`, eviction occurs *before* the method
///   executes; otherwise, it runs *after* completion.
/// - **`condition`** — A [ResourceCondition] controlling when eviction should
///   occur. Defaults to [WhenAlways].
/// - **`unless`** — A [ResourceCondition] that, if evaluated to `true`, prevents
///   eviction entirely. Defaults to [WhenNever].
///
/// ### Error Handling
/// - Errors during cache eviction or clearing are passed to
///   [CacheOperationContext.handleError].
/// - A single cache error does not interrupt eviction attempts on other caches.
/// - The operation does not rethrow by default; instead, each cache handles
///   its own failure path.
///
/// ### Thread-Safety
/// This operation is stateless and designed for concurrent use. Each invocation
/// operates exclusively on the data contained within its
/// [CacheOperationContext].
///
/// ### Example
/// ```dart
/// @CacheEvict(
///   cacheNames: {'users'},
///   allEntries: false,
///   beforeInvocation: false,
///   condition: WhenExpr('#args[0] != null'),
/// )
/// Future<void> deleteUser(String userId) async {
///   await repository.removeUser(userId);
/// }
/// ```
///
/// ### Behavior Summary
/// | Step | Description | Outcome |
/// |------|--------------|----------|
/// | 1 | Evaluate `unless` | Skip eviction if `true` |
/// | 2 | Evaluate `condition` | Skip eviction if `false` |
/// | 3 | Resolve caches | Locate configured cache managers |
/// | 4 | Evict or clear | Remove specific key or all entries |
/// | 5 | Handle errors | Report failures without aborting |
///
/// ### Usage Scenarios
/// - Removing cached data after database updates or deletions.
/// - Clearing cache regions after global state invalidation.
/// - Supporting pre- and post-invocation cache invalidation flows for data-driven
///   services.
///
/// {@endtemplate}
final class CacheEvictOperation implements CacheOperation {
  /// The `@CacheEvict` annotation defining this operation’s configuration.
  ///
  /// Contains metadata such as cache names, conditional expressions,
  /// and optional references to cache manager and key generator classes.
  final CacheEvict annotation;

  /// Creates a new [CacheEvictOperation] instance based on the given annotation.
  const CacheEvictOperation(this.annotation);

  /// {@macro jet_cache_evict_operation}
  @override
  FutureOr<void> execute<T>(CacheOperationContext<T> context) async {
    // ─────────────────────────────────────────────────────────────
    // STEP 1: Evaluate the "unless" condition — skip if true
    // ─────────────────────────────────────────────────────────────
    final unlessResult = await annotation.unless.shouldApply(context);
    if (unlessResult) {
      return; // Eviction disabled by condition
    }

    // ─────────────────────────────────────────────────────────────
    // STEP 2: Evaluate the "condition" expression — skip if false
    // ─────────────────────────────────────────────────────────────
    final conditionResult = await annotation.condition.shouldApply(context);
    if (!conditionResult) {
      return; // Eviction not applicable
    }

    // ─────────────────────────────────────────────────────────────
    // STEP 3: Resolve all cache instances
    // ─────────────────────────────────────────────────────────────
    final caches = await context.resolveCaches(annotation);

    // ─────────────────────────────────────────────────────────────
    // STEP 4: Evict specific key or clear all entries
    // ─────────────────────────────────────────────────────────────
    if (annotation.allEntries) {
      // Full cache clear
      for (final cache in caches) {
        try {
          await cache.clear();
        } catch (e, st) {
          await context.onClear(e, st, cache);
        }
      }
    } else {
      // Targeted eviction by key
      final key = await context.generateKey(annotation.keyGenerator);
      for (final cache in caches) {
        try {
          await cache.evict(key);
        } catch (e, st) {
          await context.onEvict(e, st, cache, key);
        }
      }
    }
  }
}