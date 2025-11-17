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

/// {@template rate_limit_annotation}
/// Annotation that marks a method to be subject to rate limiting.
///
/// The [RateLimit] annotation defines declarative, fine-grained rate limiting
/// rules on a specific method. When applied, JetLeaf automatically enforces
/// the defined [limit] of allowed requests per [window] duration based on
/// the configured [RateLimitStorage] and optional conditions.
///
/// ### Core Behavior
///
/// - Applies rate limiting per unique request identifier (e.g., user, IP, or key).
/// - Integrates with [RateLimitStorage] implementations to persist counters.
/// - Can be dynamically enabled/disabled via [condition] and [unless] clauses.
/// - Allows runtime customization via custom manager or resolver names.
///
/// ### Example
///
/// ```dart
/// class UserController {
///   @RateLimit(
///     {'userLimitStorage'},
///     limit: 100,
///     window: Duration(minutes: 1),
///   )
///   Future<Response> getProfile(Request request) async {
///     // This method can be called 100 times per minute per user.
///     return Response.ok(await _userService.getProfile(request.userId));
///   }
/// }
/// ```
///
/// ### Conditional Rate Limiting
///
/// You can use [condition] and [unless] to enable or disable rate limiting
/// dynamically based on runtime context:
///
/// ```dart
/// @RateLimit(
///   {'apiStorage'},
///   limit: 50,
///   window: Duration(seconds: 30),
///   condition: WhenEnvironmentPropertyEquals('api.enabled', 'true'),
///   unless: WhenEnvironmentPropertyEquals('mode', 'debug'),
/// )
/// ```
///
/// In this example:
/// - Rate limiting is only active if `api.enabled == 'true'`.
/// - It is skipped entirely when running in `debug` mode.
///
/// ### Custom Components
///
/// The annotation can reference custom implementations registered in
/// the JetLeaf [PodFactory] or dependency context:
///
/// - [keyGenerator]: Custom implementation of [KeyGenerator].
/// - [rateLimitManager]: Custom [RateLimitManager] controlling storage.
/// - [rateLimitResolver]: Custom [RateLimitResolver] deciding storages.
///
/// Example:
///
/// ```dart
/// @RateLimit(
///   {'defaultStorage'},
///   limit: 200,
///   window: Duration(minutes: 5),
///   keyGenerator: 'customUserKeyGenerator',
///   rateLimitManager: 'centralRateManager',
/// )
/// ```
///
/// ### Parameters
///
/// | Parameter | Description | Default |
/// |------------|-------------|----------|
/// | `storageNames` | Names of [RateLimitStorage]s to use. | — |
/// | `limit` | Maximum number of allowed requests per [window]. | — |
/// | `window` | The time frame for the rate limit window. | — |
/// | `condition` | A [ResourceCondition] that must match for rate limiting to apply. | [WhenAlways] |
/// | `unless` | A [ResourceCondition] that disables rate limiting if true. | [WhenNever] |
/// | `keyGenerator` | Optional name of a custom [KeyGenerator]. | `null` |
/// | `rateLimitManager` | Optional name of a custom [RateLimitManager]. | `null` |
/// | `rateLimitResolver` | Optional name of a custom [RateLimitResolver]. | `null` |
///
/// ### Related Components
///
/// - [RateLimitManager] – Manages all [RateLimitStorage]s and lifecycle.
/// - [RateLimitStorage] – Persists request counters and timestamps.
/// - [RateLimitResolver] – Determines which storages apply to a given method.
/// - [RateLimitErrorHandler] – Handles rate limit exceptions or I/O errors.
/// - [ResourceCondition] – Controls conditional activation of the annotation.
///
/// {@endtemplate}
@Target({TargetKind.method})
final class RateLimit extends ReflectableAnnotation {
  /// The names of the [RateLimitStorage] instances to use for this operation.
  ///
  /// Each name should correspond to a storage registered in the application
  /// context, typically through a [RateLimitConfigurer] or [RateLimitStorageRegistry].
  ///
  /// Multiple storages can be specified to apply distributed or hierarchical
  /// rate limiting policies.
  final Set<String> storageNames;

  /// The maximum number of requests allowed within the configured [window].
  ///
  /// Exceeding this limit triggers a rate limit violation handled by the
  /// [RateLimitErrorHandler].
  final int limit;

  /// The duration representing the rate limit window.
  ///
  /// Defines how long the request counters are valid before resetting.
  /// Common values include `Duration(seconds: 10)` or `Duration(minutes: 1)`.
  final Duration window;

  /// The activation condition for the rate limit.
  ///
  /// The rate limit is enforced **only if** this condition evaluates to `true`.
  /// Defaults to [WhenAlways], meaning rate limiting is always active.
  final ResourceCondition condition;

  /// The disabling condition for the rate limit.
  ///
  /// The rate limit is skipped **if** this condition evaluates to `true`,
  /// even if [condition] is satisfied. Defaults to [WhenNever].
  final ResourceCondition unless;

  /// The optional name of a custom [KeyGenerator] pod.
  ///
  /// If specified, JetLeaf resolves and uses the registered generator to
  /// produce unique rate limit keys for each invocation.
  final String? keyGenerator;

  /// The optional name of a custom [RateLimitManager].
  ///
  /// When provided, JetLeaf delegates rate limit enforcement to the named
  /// manager instead of using the default global one.
  final String? rateLimitManager;

  /// The optional name of a custom [RateLimitResolver].
  ///
  /// Determines which [RateLimitStorage] instances apply to this annotation.
  /// Useful for advanced routing or dynamic multi-storage configurations.
  final String? rateLimitResolver;

  /// Creates a new [RateLimit] annotation defining rate limiting behavior.
  ///
  /// Example:
  /// ```dart
  /// @RateLimit(
  ///   {'mainStorage'},
  ///   limit: 100,
  ///   window: Duration(seconds: 60),
  /// )
  /// ```
  ///
  /// Use optional parameters like [condition], [unless], [keyGenerator],
  /// and [rateLimitManager] for advanced customization.
  /// 
  /// {@macro rate_limit_annotation}
  const RateLimit(
    this.storageNames, {
    required this.limit,
    required this.window,
    this.condition = const WhenAlways(),
    this.unless = const WhenNever(),
    this.keyGenerator,
    this.rateLimitManager,
    this.rateLimitResolver,
  });

  @override
  Type get annotationType => RateLimit;
}