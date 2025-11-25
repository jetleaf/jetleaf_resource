import 'dart:async';

import 'package:jetleaf_core/intercept.dart';

import '../annotations.dart';
import '../storage/rate_limit_storage.dart';

/// {@template rate_limit_resolver}
/// The [RateLimitResolver] defines the strategy contract for resolving one or more
/// [RateLimitStorage] instances for a specific [RateLimit] operation.
///
/// It acts as the bridge between annotation-level configuration ([RateLimit])
/// and runtime rate-limiting infrastructure ([RateLimitStorage] and [RateLimitManager]).
///
/// ### Purpose
///
/// In a multi-storage environment, different rate limits may apply to different
/// tiers, domains, or regions of the system.  
/// The [RateLimitResolver] encapsulates the decision logic for mapping a rate limit
/// declaration to the correct storage(s).
///
/// For instance, a global API rate limit might use a distributed Redis storage,
/// while a user-specific limit could rely on a local in-memory backend.
///
/// ### Behavior
///
/// - Given a [RateLimit] annotation, the resolver selects one or more storages
///   where the rate-limit state should be read and updated.
/// - The resolution may depend on:
///   - Explicit storage names declared in the annotation.
///   - Default storage selection rules.
///   - Contextual information (such as tenant, environment, or endpoint).
///
/// ### Example
///
/// ```dart
/// @RateLimit(['redis-rate-limit', 'local-cache'], limit: 100, window: Duration(seconds: 30))
/// Future<Response> getUserData(Request req) async {
///   ...
/// }
///
/// // During runtime
/// final resolver = DefaultRateLimitResolver(manager);
/// final storages = await resolver.resolveStorages(rateLimitAnnotation);
/// for (final storage in storages) {
///   final allowed = await storage.tryConsume('user:42', limit: rateLimit.limit, window: rateLimit.window);
///   if (!allowed) throw TooManyRequestsException();
/// }
/// ```
///
/// ### Implementation Notes
///
/// - Implementations may use priority rules, profile-based resolution,
///   or caching mechanisms to optimize lookups.
/// - The resolver should be stateless or thread-safe if shared globally.
///
/// ### Related Components
///
/// - [RateLimit]: Annotation defining the rate-limiting metadata.
/// - [RateLimitManager]: Provides access to available storages.
/// - [RateLimitStorage]: The backend persistence mechanism.
/// - [RateLimiter]: Uses this resolver during evaluation.
/// {@endtemplate}
abstract interface class RateLimitResolver {
  /// {@template rate_limit_resolver_resolve_storages}
  /// Resolves the appropriate [RateLimitStorage] instances for a given
  /// [RateLimit] operation.
  ///
  /// ### Parameters
  /// - [rateLimit]: The rate-limit metadata annotation specifying the
  ///   configuration for the current operation.
  ///
  /// ### Returns
  /// - A collection of [RateLimitStorage] instances that should participate
  ///   in the evaluation and enforcement of the given rate limit.
  ///
  /// ### Behavior
  ///
  /// - If multiple storages are declared, the returned collection must preserve
  ///   their configured order of precedence.
  /// - If no storages are explicitly defined, the resolver may fall back to
  ///   a default storage policy (e.g., a globally configured primary storage).
  ///
  /// ### Example
  /// ```dart
  /// final storages = await resolver.resolveStorages(rateLimitAnnotation);
  /// for (final storage in storages) {
  ///   await storage.recordRequest('client:abc', window: rateLimitAnnotation.window);
  /// }
  /// ```
  ///
  /// ### Related
  /// - [RateLimitStorage]
  /// - [RateLimitManager]
  /// {@endtemplate}
  FutureOr<Iterable<RateLimitStorage>> resolveStorages(RateLimit rateLimit, MethodInvocation invocation);
}