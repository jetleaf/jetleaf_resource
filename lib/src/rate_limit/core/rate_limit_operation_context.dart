import 'dart:async';

import 'package:jetleaf_core/intercept.dart';
import 'package:jetleaf_lang/lang.dart';

import '../../base/operation_context.dart';
import '../resolver/rate_limit_resolver.dart';

/// {@template rate_limit_operation_context}
/// Context object representing the state and behavior of a rate-limited
/// method invocation or resource access.
///
/// This interface encapsulates the current request, its identifier, the
/// applicable rate limit configuration, and supports recording results
/// (allowed, denied) as well as computing retry times.
///
/// Implementations should provide mechanisms for:
/// - Generating a unique key for the rate-limited entity.
/// - Checking and recording whether the request is allowed.
/// - Accessing or updating rate limit metadata.
/// {@endtemplate}
@Generic(RateLimitOperationContext)
abstract interface class RateLimitOperationContext<T> implements ConfigurableOperationContext, RateLimitResolver {
  /// Generates a unique key for the current rate-limited entity.
  ///
  /// This is typically based on the target object, method signature,
  /// and arguments (or custom key generator if applicable).
  /// 
  /// [preferredKeyGeneratorName] can be used to select a custom key generator.
  FutureOr<Object> generateKey([String? preferredKeyGeneratorName]);

  /// Returns the underlying method invocation metadata (target, arguments, etc.).
  MethodInvocation<T> getMethodInvocation();
}