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

import 'resource.dart';

/// {@template resource_condition}
/// Defines a generalized conditional policy for applying resource-level operations.
///
/// Implementations of [ResourceCondition] are used to determine whether a given
/// cross-cutting concern (such as caching, rate limiting, retrying, or metering)
/// should be applied to a specific operation invocation.
///
/// This abstraction decouples *when* an operation should be affected by
/// a resource control policy from *how* it is applied.
///
/// The [shouldApply] method is invoked at runtime with an [OperationContext]
/// providing contextual information such as:
/// - The method being executed
/// - Input arguments and metadata
/// - The returned result or thrown exception
///
/// ## Example
/// ```dart
/// class OnlyForPremiumUsers extends ResourceCondition {
///   const OnlyForPremiumUsers();
///
///   @override
///   FutureOr<bool> shouldApply(OperationContext context) {
///     final user = context.getArgument('user');
///     return user?.isPremium == true;
///   }
/// }
/// ```
///
/// Built-in conditions include:
/// - [WhenAlways] — always applies
/// - [WhenNever] — never applies
/// - [WhenAll], [WhenAny], [WhenNot] — logical combinators
/// {@endtemplate}
abstract interface class ResourceCondition {
  /// Creates a new [ResourceCondition] instance.
  /// 
  /// {@macro resource_condition}
  const ResourceCondition();

  /// {@template resource_condition_should_apply}
  /// Determines whether the operation should be subjected to a resource policy.
  ///
  /// Returns `true` if the resource control (e.g., cache, rate limit)
  /// should be applied; otherwise returns `false`.
  ///
  /// Implementations may perform asynchronous evaluation when necessary,
  /// for example when querying an external expression resolver or configuration source.
  ///
  /// @param context The [OperationContext] representing the current invocation
  /// @return `true` if the condition is satisfied and the policy should apply
  /// 
  /// {@endtemplate}
  FutureOr<bool> shouldApply(OperationContext context);
}

/// {@template resource_condition_always}
/// A [ResourceCondition] that always evaluates to `true`.
///
/// This condition unconditionally enables the associated resource operation,
/// such as caching, rate limiting, or retrying.  
///
/// It is typically used as a default or fallback condition when no dynamic
/// evaluation is required.
///
/// ## Example
/// ```dart
/// @Cacheable(condition: WhenAlways())
/// Future<User> getUser(String id) async => repository.find(id);
/// ```
///
/// In this case, the caching behavior will *always* apply, regardless of
/// the operation context or input arguments.
/// {@endtemplate}
final class WhenAlways implements ResourceCondition {
  /// Creates an unconditional [WhenAlways] condition.
  /// 
  /// {@macro resource_condition_always}
  const WhenAlways();

  /// Always returns `true`, indicating the operation should apply.
  /// 
  /// {@macro resource_condition_should_apply}
  @override
  FutureOr<bool> shouldApply(OperationContext context) => true;
}

/// {@template resource_condition_never}
/// A [ResourceCondition] that always evaluates to `false`.
///
/// This condition unconditionally prevents the associated resource operation
/// (such as caching, rate limiting, or retrying) from being applied.  
///
/// It is typically used for disabling a specific resource policy in contexts
/// where it would normally apply by default.
///
/// ## Example
/// ```dart
/// @Cacheable(condition: WhenNever())
/// Future<User> getUser(String id) async => repository.find(id);
/// ```
///
/// In this example, the caching behavior is explicitly disabled,
/// regardless of the operation context or input arguments.
/// {@endtemplate}
final class WhenNever extends ResourceCondition {
  /// Creates a condition that always prevents application of the resource operation.
  /// 
  /// {@macro resource_condition_never}
  const WhenNever();

  /// Always returns `false`, indicating the operation should not apply.
  /// 
  /// {@macro resource_condition_should_apply}
  @override
  FutureOr<bool> shouldApply(OperationContext context) => false;
}

/// {@template resource_condition_and}
/// A composite [ResourceCondition] that evaluates to `true` only if **both**
/// the left and right conditions evaluate to `true`.
///
/// This condition enables logical conjunction of two separate conditions,
/// making it useful for scenarios where multiple criteria must all be met
/// before a resource operation (such as caching, rate limiting, or retrying)
/// can be applied.
///
/// ## Example
/// ```dart
/// @Cacheable(condition: WhenAll(WhenExpr('#result != null'), WhenExpr('#result.isActive')))
/// Future<User> fetchUser(String id) async => repository.find(id);
/// ```
///
/// In this example, caching occurs only when the method result is non-null
/// **and** the user is active.
/// {@endtemplate}
final class WhenAll extends ResourceCondition {
  /// The left-hand condition in the logical conjunction.
  final ResourceCondition left;

  /// The right-hand condition in the logical conjunction.
  final ResourceCondition right;

  /// Creates a composite AND condition that requires both [left] and [right]
  /// to evaluate to `true` for the resource operation to apply.
  /// 
  /// {@macro resource_condition_and}
  const WhenAll(this.left, this.right);

  /// Evaluates the combined condition:
  /// - Returns `false` immediately if [left] is `false`.
  /// - Otherwise, returns the result of [right].
  /// 
  /// {@macro resource_condition_should_apply}
  @override
  FutureOr<bool> shouldApply(OperationContext context) async {
    final leftResult = await left.shouldApply(context);
    if (!leftResult) return false;
    return await right.shouldApply(context);
  }
}

/// {@template resource_condition_or}
/// A composite [ResourceCondition] that evaluates to `true` if **either**
/// the left or right condition evaluates to `true`.
///
/// This condition allows flexible conditional logic for resource operations,
/// enabling a resource to be applied when **at least one** of multiple
/// criteria is satisfied.
///
/// ## Example
/// ```dart
/// @RateLimit(condition: WhenAny(WhenExpr('#user.isAdmin'), WhenExpr('#user.isModerator')))
/// Future<void> performAction(User user) async {
///   // Action allowed for admin or moderator users
/// }
/// ```
///
/// In this example, rate limiting is applied only if the user is either
/// an admin **or** a moderator.
/// {@endtemplate}
final class WhenAny extends ResourceCondition {
  /// The left-hand condition in the logical disjunction.
  final ResourceCondition left;

  /// The right-hand condition in the logical disjunction.
  final ResourceCondition right;

  /// Creates a composite OR condition that evaluates to `true` if either
  /// [left] or [right] evaluates to `true`.
  /// 
  /// {@macro resource_condition_or}
  const WhenAny(this.left, this.right);

  /// Evaluates the combined condition:
  /// - Returns `true` immediately if [left] is `true`.
  /// - Otherwise, returns the result of [right].
  /// 
  /// {@macro resource_condition_should_apply}
  @override
  FutureOr<bool> shouldApply(OperationContext context) async {
    final leftResult = await left.shouldApply(context);
    if (leftResult) return true;
    return await right.shouldApply(context);
  }
}

/// {@template resource_condition_not}
/// A negation [ResourceCondition] that inverts the result of another condition.
///
/// This condition evaluates to `true` when the wrapped [condition]
/// evaluates to `false`, and vice versa. It is useful when you want
/// to apply a resource operation **only when** a specific condition
/// is **not met**.
///
/// ## Example
/// ```dart
/// @Cacheable(condition: WhenNone(WhenExpr('#user.isGuest')))
/// Future<UserData> loadProfile(User user) async {
///   // This will cache the result only for non-guest users
/// }
/// ```
///
/// In this example, caching will occur only if the user is **not** a guest.
/// {@endtemplate}
final class WhenNot extends ResourceCondition {
  /// The condition whose result will be negated.
  final ResourceCondition condition;

  /// Creates a negation condition that inverts the result of [condition].
  /// 
  /// {@macro resource_condition_not}
  const WhenNot(this.condition);

  /// Evaluates the condition and returns its logical negation.
  ///
  /// If [condition.shouldApply] returns `true`, this method returns `false`,
  /// and vice versa.
  /// 
  /// {@macro resource_condition_should_apply}
  @override
  FutureOr<bool> shouldApply(OperationContext context) async {
    final result = await condition.shouldApply(context);
    return !result;
  }
}

/// {@template resource_condition_none}
/// A condition that evaluates to `true` only if **both** nested conditions
/// evaluate to `false`.
///
/// This can be seen as a logical NOR operation:
/// ```text
/// WhenNone(A, B) == !(A || B)
/// ```
///
/// ## Example
/// ```dart
/// final condition = WhenNone(
///   WhenExpr('#user.isAdmin'),
///   WhenExpr('#user.isModerator'),
/// );
///
/// // Applies only when neither admin nor moderator
/// ```
///
/// Useful for negating multiple disjunctive conditions in resource-level
/// logic such as caching, rate limiting, or authorization.
/// {@endtemplate}
final class WhenNone extends ResourceCondition {
  /// The left-hand condition in the logical disjunction.
  final ResourceCondition left;

  /// The right-hand condition in the logical disjunction.
  final ResourceCondition right;

  /// Creates a composite OR condition that evaluates to `true` if either
  /// [left] or [right] evaluates to `false`.
  /// 
  /// {@macro resource_condition_none}
  const WhenNone(this.left, this.right);

  /// Creates a composite NOR condition.
  ///
  /// Evaluates to `true` if **neither** [left] nor [right] evaluates to `true`.
  /// 
  /// {@macro resource_condition_should_apply}
  @override
  FutureOr<bool> shouldApply(OperationContext context) async {
    final leftResult = await left.shouldApply(context);
    final rightResult = await right.shouldApply(context);

    return !leftResult && !rightResult;
  }
}

/// A [ResourceCondition] that evaluates based on environment variables.
///
/// {@template resource_condition_env}
/// The [WhenEnv] condition allows activating or skipping resources
/// depending on environment variables.
///
/// It supports multiple match types:
/// - `equals` — variable must equal a given value.
/// - `notEquals` — variable must differ from a given value.
/// - `exists` — variable must be present.
/// - `notExists` — variable must be absent.
/// - `matches` — variable must match a given regex pattern.
///
/// ### Example
/// ```dart
/// // Activate only in production
/// const WhenEnv(key: 'APP_MODE', value: 'production', match: EnvMatchType.equals);
///
/// // Activate if DEBUG flag exists
/// const WhenEnv(key: 'DEBUG', match: EnvMatchType.exists);
///
/// // Activate if environment name matches regex
/// const WhenEnv(key: 'APP_ENV', value: r'^(dev|test)$', match: EnvMatchType.matches);
/// ```
/// {@endtemplate}
final class WhenEnv implements ResourceCondition {
  /// The environment variable key to check.
  final String key;

  /// The optional value to compare with or match against.
  final String? value;

  /// The comparison mode.
  final EnvMatchType match;

  /// Creates a new [WhenEnv] condition.
  ///
  /// The [match] parameter determines how the environment value is evaluated.
  const WhenEnv(this.key, {this.value, this.match = EnvMatchType.EXISTS});

  /// {@macro resource_condition_should_apply}
  @override
  FutureOr<bool> shouldApply(OperationContext context) {
    final env = context.getEnvironment();
    final currentValue = env.getProperty(key);

    switch (match) {
      case EnvMatchType.EQUALS:
        return currentValue != null && currentValue == value;
      case EnvMatchType.NOT_EQUALS:
        return currentValue != null && currentValue != value;
      case EnvMatchType.EXISTS:
        return env.containsProperty(key);
      case EnvMatchType.NOT_EXISTS:
        return !env.containsProperty(key);
      case EnvMatchType.REGEX:
        if (currentValue == null || value == null) return false;
        final regex = RegExp(value!);
        return regex.hasMatch(currentValue);
    }
  }

  @override
  String toString() => 'WhenEnv(key: $key, match: $match, value: $value)';
}

/// Defines how a [WhenEnv] condition compares an environment value.
///
/// {@template env_match_type}
/// - [EQUALS] → exact string equality.
/// - [NOT_EQUALS] → inverse of [EQUALS].
/// - [EXISTS] → key must be present.
/// - [NOT_EXISTS] → key must be absent.
/// - [REGEX] → regex pattern match.
/// {@endtemplate}
enum EnvMatchType {
  EQUALS,
  NOT_EQUALS,
  EXISTS,
  NOT_EXISTS,
  REGEX,
}