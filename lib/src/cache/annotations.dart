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

import 'package:jetleaf_lang/lang.dart';
import 'package:meta/meta_meta.dart';

import '../conditions.dart';

/// {@template cacheable_annotation}
/// Marks a method as cacheable — its result will be stored in one or more caches.
///
/// When a method annotated with `@Cacheable` is invoked, the caching
/// mechanism first checks whether the result for the given arguments
/// already exists in the specified caches. If found, the cached result
/// is returned immediately without invoking the method. Otherwise, the
/// method executes, and its return value is stored in the cache for
/// subsequent invocations.
/// 
/// Cacheable works with the [Interceptable] mixin that provides [when] method, and it is required, else caching cannot
/// intercept the method call.
///
/// ## Example
/// ```dart
/// @Service()
/// final class UserService with Interceptable {
///   @Cacheable({'users'}, condition: WhenExpr('#args[0] != null'), unless: WhenExpr('#result == null'))
///   Future<User?> findUserById(String id) async {
///     return when(() async => database.findUser(id));
///   }
/// }
/// ```
///
/// ## Parameters
/// - [cacheNames] — The set of cache identifiers where results will be stored.
/// - [condition] — A [ResourceCondition] that must evaluate to `true`
///   for caching to occur. Defaults to [WhenAlways].
/// - [unless] — A [ResourceCondition] that prevents caching if it
///   evaluates to `true`. Defaults to [WhenNever].
/// - [keyGenerator] — An optional reference to a custom key generator
///   name `customKeyGenerator`. Must be registered in
///   the PodFactory context.
/// - [cacheManager] — An optional reference to a custom cache manager
///   name `customCacheManager`. Must be registered in
///   the PodFactory context.
/// - [cacheResolver] — An optional reference to a custom cache resolver
///   name `cacheResolverType`. Must be registered in
///   the PodFactory context.
///
/// ## Notes
/// - The `condition` and `unless` attributes support both declarative DSLs
///   and expression-based evaluation (via [WhenExpr]).
/// - The cache behavior depends on the active [CacheManager] implementation
///   registered in the context.
/// - If both `condition` and `unless` evaluate to `true`, caching is skipped.
///
/// {@endtemplate}
@Target({TargetKind.method})
final class Cacheable extends ReflectableAnnotation {
  /// The names of the caches to use for this operation.
  final Set<String> cacheNames;

  /// The condition that must be satisfied for caching to occur.
  /// 
  /// Defaults to [WhenAlways].
  final ResourceCondition condition;

  /// The condition that, if true, prevents caching.
  /// 
  /// Defaults to [WhenNever].
  final ResourceCondition unless;

  /// {@template cache_value.time_to_live}
  /// The time-to-live (TTL) duration for this cache entry.
  ///
  /// Defines how long the cached value remains valid before it expires.
  /// Once the TTL elapses, the cache entry becomes eligible for eviction
  /// or automatic invalidation depending on the cache configuration.
  ///
  /// ### Example:
  /// ```dart
  /// final entry = CacheValue(
  ///   data,
  ///   Duration(minutes: 10),
  /// );
  /// ```
  ///
  /// A `null` value indicates that the entry does not expire automatically.
  /// {@endtemplate}
  final Duration? ttl;

  /// Optional custom key generator name
  /// 
  /// `customKeyGenerator`.
  /// Must be registered in the PodFactory context.
  final String? keyGenerator;

  /// Optional custom cache manager name
  /// 
  /// `customCacheManager`.
  /// Must be registered in the PodFactory context.
  final String? cacheManager;

  /// Optional custom cache resolver name
  /// 
  /// `cacheResolverType`.
  /// Must be registered in the PodFactory context.
  final String? cacheResolver;

  /// Creates a new [Cacheable] annotation for cacheable methods.
  /// 
  /// {@macro cacheable_annotation}
  const Cacheable(this.cacheNames, {
    this.condition = const WhenAlways(),
    this.unless = const WhenNever(),
    this.keyGenerator,
    this.cacheManager,
    this.cacheResolver,
    this.ttl
  });

  @override
  Type get annotationType => Cacheable;
}

/// {@template cache_put_annotation}
/// Marks a method whose result should always be stored (or updated) in the cache.
///
/// Unlike [Cacheable], which checks if the result already exists before caching,
/// `@CachePut` forces the method to execute and **updates** the cache with the
/// returned value — ensuring that the cache entry stays fresh and consistent
/// with the latest computation.
/// 
/// CachePut works with the [Interceptable] mixin that provides [when] method, and it is required, else caching cannot
/// intercept the method call.
///
/// ## Example
/// ```dart
/// @Service()
/// final class UserService with Interceptable {
///   @CachePut({'users'}, condition: WhenExpr('#args[0] != null'), unless: WhenExpr('#result == null'))
///   Future<User> updateUser(User user) async {
///     return when(() async => userRepository.save(user));
///   }
/// }
/// ```
/// 
/// ## Behavior
/// - The annotated method is **always executed**, unlike [Cacheable].
/// - After execution, if the `condition` evaluates to `true` and `unless`
///   evaluates to `false`, the result is stored in the specified caches.
/// - The cache key is generated using the default key generator or a custom one
///   specified via [keyGenerator].
///
/// ## Parameters
/// - [cacheNames] — The set of cache identifiers to update or replace.
/// - [condition] — A [ResourceCondition] that must evaluate to `true`
///   for cache updating to occur. Defaults to [WhenAlways].
/// - [unless] — A [ResourceCondition] that prevents cache updating if it
///   evaluates to `true`. Defaults to [WhenNever].
/// - [keyGenerator] — An optional reference to a custom key generator
///   name `customKeyGenerator`. Must be registered in
///   the PodFactory context.
/// - [cacheManager] — An optional reference to a custom cache manager
///   name `customCacheManager`. Must be registered in
///   the PodFactory context.
/// - [cacheResolver] — An optional reference to a custom cache resolver
///   name `cacheResolverType`. Must be registered in
///   the PodFactory context.
///
/// ## Notes
/// - Typically used for methods that modify underlying data sources (e.g., update or insert).
/// - Can be combined with [CacheEvict] to synchronize multiple caches.
/// - Both [condition] and [unless] support expression-based evaluation through [WhenExpr].
///
/// {@endtemplate}
@Target({TargetKind.method})
final class CachePut extends Cacheable {
  /// Creates a new [CachePut] annotation for cache-update methods.
  /// 
  /// {@macro cache_put_annotation}
  const CachePut(super.cacheNames, {
    super.condition = const WhenAlways(),
    super.unless = const WhenNever(),
    super.keyGenerator,
    super.cacheManager,
    super.cacheResolver,
    super.ttl
  });

  @override
  Type get annotationType => CachePut;
}

/// {@template cache_evict_annotation}
/// Marks a method that triggers the removal (or invalidation) of cache entries.
///
/// The `@CacheEvict` annotation provides fine-grained control over cache
/// eviction, allowing developers to clear specific cache keys or entire caches
/// based on configurable conditions.
/// 
/// CacheEvict works with the [Interceptable] mixin that provides [when] method, and it is required, else caching cannot
/// intercept the method call.
///
/// ## Example
/// ```dart
/// @Service()
/// final class UserService with Interceptable {
///   @CacheEvict({'users'}, condition: WhenExpr('#args[0] != null'), beforeInvocation: true)
///   Future<void> deleteUser(String userId) async {
///     return when(() async => userRepository.delete(userId));
///   }
/// }
/// ```
///
/// ## Behavior
/// - If `beforeInvocation` is `true`, eviction occurs **before** the method runs.
/// - If `beforeInvocation` is `false`, eviction occurs **after** successful execution.
/// - If `allEntries` is `true`, **all entries** in the specified caches are cleared.
/// - Otherwise, only entries corresponding to the generated cache key are removed.
/// - The operation will only proceed if:
///   - `condition` evaluates to `true`, and
///   - `unless` evaluates to `false`.
///
/// ## Parameters
/// - [cacheNames] — The names of the caches to evict from.
/// - [condition] — A [ResourceCondition] determining whether eviction should occur.
///   Defaults to [WhenAlways].
/// - [unless] — A [ResourceCondition] that, if `true`, prevents eviction.
///   Defaults to [WhenNever].
/// - [allEntries] — When `true`, evicts all entries from the caches rather than a single key.
///   Defaults to `false`.
/// - [beforeInvocation] — When `true`, performs eviction before the annotated method executes;
///   otherwise, eviction happens afterward. Defaults to `false`.
/// - [keyGenerator] — Optional reference to a custom key generator name
///   `customKeyGenerator`. Must be registered in the PodFactory context.
/// - [cacheManager] — Optional reference to a custom cache manager name
///   `customCacheManager`. Must be registered in the PodFactory context.
/// - [cacheResolver] — Optional reference to a custom cache resolver name
///   `cacheResolverType`. Must be registered in the PodFactory context.
///
/// ## Notes
/// - Use `allEntries: true` for bulk invalidation (e.g., after data refresh operations).
/// - Use `beforeInvocation: true` to prevent stale data access during method execution.
/// - Both [condition] and [unless] support expression-based evaluation using [WhenExpr].
///
/// ## See also
/// - [Cacheable] — for caching method results.
/// - [CachePut] — for updating cache entries.
/// {@endtemplate}
@Target({TargetKind.method})
final class CacheEvict extends Cacheable {
  /// If true, clears all entries from the cache instead of just the key.
  final bool allEntries;

  /// If true, evicts before method execution; otherwise after.
  final bool beforeInvocation;

  /// Creates a new [CacheEvict] annotation for cache invalidation methods.
  ///
  /// Supports both conditional and expression-based eviction logic, as well as
  /// full-cache clearing via [allEntries].
  /// 
  /// {@macro cache_evict_annotation}
  const CacheEvict(super.cacheNames, {
    super.condition = const WhenAlways(),
    super.unless = const WhenNever(),
    this.allEntries = false,
    this.beforeInvocation = false,
    super.keyGenerator,
    super.cacheManager,
    super.cacheResolver,
  });

  @override
  Type get annotationType => CacheEvict;
}