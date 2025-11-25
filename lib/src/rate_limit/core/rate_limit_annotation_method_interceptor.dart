import 'dart:async';

import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_core/intercept.dart';
import 'package:jetleaf_lang/lang.dart';

import '../../base/exceptions.dart';
import '../../key_generator/key_generator.dart';
import '../annotations.dart';
import '../rate_limit_result.dart';
import '../resolver/rate_limit_resolver.dart';
import '../storage/rate_limit_storage.dart';
import '../storage/roll_back_capable_rate_limit_storage.dart';
import 'default_rate_limit_operation_context.dart';

/// {@template jet_rate_limit_annotation_method_interceptor}
/// A composite [ConditionalMethodInterceptor] that transparently applies
/// **rate limiting** behavior based on JetLeaf `@RateLimit` annotations.
///
/// This interceptor is automatically invoked by the JetLeaf AOP subsystem
/// whenever a method carries one or more `@RateLimit` annotations. It determines
/// which rate-limit rules apply and orchestrates their lifecycle, including:
/// - Conditional evaluation (`unless` and `condition`)
/// - Key generation
/// - Storage resolution
/// - Consumption tracking
/// - Best-effort rollback
/// - Exception or silent denial handling
///
/// ### Interception Workflow
/// When a method annotated with `@RateLimit` is invoked:
///
/// 1. **Annotation Detection**
///    - The interceptor checks if the method has a direct `@RateLimit` annotation.
///    - If no annotation is found, the method proceeds normally.
///
/// 2. **Conditional Evaluation**
///    - Evaluates `unless` predicate:
///      - If `unless` returns `true`, the rate limit is skipped for this invocation.
///    - Evaluates `condition` predicate:
///      - If `condition` returns `false`, the rate limit is skipped.
///
/// 3. **Key Generation**
///    - The interceptor generates a unique key for the method invocation using
///      the configured [KeyGenerator].
///    - Keys are typically derived from method parameters, target instance, and
///      optional custom logic from the annotation.
///
/// 4. **Storage Resolution**
///    - Resolves the list of [RateLimitStorage] instances where rate-limit
///      counters are maintained.
///    - Uses either:
///      - A custom `rateLimitResolver` from the annotation or context, or
///      - A `RateLimitManager` configured globally.
///
/// 5. **Consumption Attempt**
///    - Calls `tryConsume` on each resolved storage.
///    - Tracks which storages successfully allowed the request.
///
/// 6. **Best-Effort Rollback**
///    - If any storage denies the request, previously successful storages are
///      rolled back using `rollbackConsume`.
///    - Rollback is best-effort; failures are logged or swallowed without affecting
///      application flow.
///
/// 7. **Denial Handling**
///    - If `throwExceptionOnExceeded` is `true`, a [RateLimitExceededException]
///      is thrown with detailed information from the storage result.
///    - If `throwExceptionOnExceeded` is `false`, the denial is recorded silently,
///      allowing the caller to inspect `allowed` and `retryAfter` in the context.
///
/// 8. **Method Execution**
///    - If all storages allow the request, the method proceeds normally.
///    - Otherwise, execution is halted or a fallback mechanism can be triggered.
///
/// ### Ordering Guarantees
/// This interceptor is executed in the order defined by [Ordered] interface,
/// ensuring consistent behavior when multiple interceptors are applied:
/// ```text
/// Conditional Evaluation (unless/condition)
///   → Storage Resolution
///     → Consumption Attempt
///       → Best-Effort Rollback (if needed)
///         → Denial Handling
///           → Method Execution (if allowed)
/// ```
///
/// ### Context Fields
/// - `applicationContext`: The active JetLeaf [ApplicationContext] for
///   resolving dependencies like resolvers, key generators, and storages.
/// - `keyGenerator`: Responsible for generating unique keys for each invocation.
/// - `rateLimitResolver`: Resolves storages by name or annotation metadata.
/// - `throwExceptionOnExceeded`: Controls whether the interceptor throws
///   on exceed events or silently records denial.
///
/// ### Example
/// ```dart
/// class MyRateLimitInterceptor extends RateLimitAnnotationMethodInterceptor {
///   // Add logging, metrics, or fallback integration
/// }
///
/// final interceptor = MyRateLimitInterceptor();
/// final result = await interceptor.intercept(invocation);
/// // The interceptor automatically enforces rate limits based on annotations.
/// ```
///
/// ### Notes
/// - Supports multiple storage backends, including rollback-capable storages.
/// - Rollback is best-effort and does not throw if a previous consume cannot be reverted.
/// - Key generation and storage resolution can be customized per method or globally.
///
/// ### See Also
/// - [RateLimit]
/// - [RateLimitStorage]
/// - [RollbackCapableRateLimitStorage]
/// - [RateLimitOperationContext]
/// - [DefaultRateLimitOperationContext]
/// {@endtemplate}
abstract class RateLimitAnnotationMethodInterceptor implements MethodBeforeInterceptor, AroundMethodInterceptor, AfterThrowingInterceptor, Ordered {
  /// The **active JetLeaf [ApplicationContext]** associated with this registrar.
  ///
  /// Provides access to:
  /// - The application’s environment configuration (e.g., profiles, properties).
  /// - Event publication and subscription mechanisms.
  /// - The global lifecycle scope for rate-limit components.
  ///
  /// Used primarily for cleanup coordination and contextual property lookups
  /// (such as determining rate-limit error handling style).
  late ApplicationContext applicationContext;

  /// The [KeyGenerator] responsible for producing unique and consistent
  /// rate-limit keys for annotated method invocations.
  ///
  /// This component determines how rate-limit entries are identified and retrieved.
  /// By default, JetLeaf uses a [CompositeKeyGenerator] capable of handling
  /// complex method signatures and parameter combinations.
  ///
  /// Custom implementations can be provided to control key generation logic,
  /// such as hashing, parameter filtering, or structured key composition.
  late KeyGenerator keyGenerator;

  /// The resolver responsible for locating target [RateLimitStorage] instances by name.
  ///
  /// This field holds the custom or default [RateLimitResolver] used to map
  /// rate limit annotations or identifiers to the actual storage instances
  /// where counters, windows, and limits are maintained.
  ///
  /// ### Usage
  /// ```dart
  /// final storage = rateLimitResolver.resolve('userLimit');
  /// ```
  ///
  /// ### Notes
  /// - Must be initialized before executing rate-limited operations.
  /// - Typically provided by the application context or a user-defined configuration.
  late RateLimitResolver rateLimitResolver;

  /// Indicates whether the rate-limit operation should throw a
  /// [RateLimitExceededException] when a limit is exceeded.
  ///
  /// - `true`: Exceptions are thrown on exceed events.
  /// - `false`: The operation records the denial and returns control silently,
  ///   allowing the caller to inspect context state via [allowed] or [retryAfter].
  ///
  /// This flag is typically driven by the `throwOnExceeded` property of the
  /// `@RateLimit` annotation or global configuration.
  bool throwExceptionOnExceeded = true;

  /// Lazily-initialized operation context used for evaluating
  /// rate-limit metadata during method invocation.
  ///
  /// This context provides access to the application environment,
  /// key generator, and the active [RateLimitResolver].  
  /// It is created once on first use and then reused for subsequent
  /// evaluations within this component.
  ///
  /// The value remains `null` until a rate-limited operation requires it.
  DefaultRateLimitOperationContext? _operationContext;

  /// Returns the existing [DefaultRateLimitOperationContext] instance,
  /// or creates and caches a new one if none exists.
  ///
  /// ### Behavior
  /// - If `_operationContext` is already initialized, it is returned as-is.
  /// - Otherwise, a new context is created using:
  ///   - the active [ApplicationContext]
  ///   - the configured key generator
  ///   - the [RateLimitResolver] responsible for resolving effective
  ///     rate-limit policies
  /// - The created instance is stored and reused for future calls.
  ///
  /// ### Purpose
  /// This lazy-construction pattern avoids unnecessary allocation and ensures
  /// that all rate-limit resolution steps operate on a shared, consistent
  /// execution context.
  ///
  /// ### Returns
  /// A non-null, fully-configured [DefaultRateLimitOperationContext].
  DefaultRateLimitOperationContext _getOrCreate() => _operationContext ??= DefaultRateLimitOperationContext(applicationContext, keyGenerator, rateLimitResolver);

  @override
  bool canIntercept(Method method) => method.hasDirectAnnotation<RateLimit>();

  @override
  FutureOr<void> beforeInvocation<T>(MethodInvocation<T> invocation) async {
    final rateLimit = invocation.getMethod().getDirectAnnotation<RateLimit>();
    if (rateLimit == null) return;

    final context = _getOrCreate().withInvocation(invocation);

    // STEP 1: Resolve storage and setup resources
    final storages = await context.resolveStorages(rateLimit, invocation);
    context.setResources(storages.map((sto) => sto.getResource()).toList());

    // STEP 2: unless
    final unlessResult = await rateLimit.unless.shouldApply(context);
    if (unlessResult) {
      // Mark to skip actual invocation or store in context if needed
      context.setSkipped(true);
      return;
    }

    // STEP 3: condition
    final conditionResult = await rateLimit.condition.shouldApply(context);
    context.setSkipped(!conditionResult);
  }

  @override
  Future<T?> aroundInvocation<T>(MethodInvocation<T> invocation) async {
    final rateLimit = invocation.getMethod().getDirectAnnotation<RateLimit>();
    if (rateLimit == null) return null;

    final context = _getOrCreate().withInvocation(invocation);

    // Skip invocation if beforeInvocation decided to skip
    if (context.skipped()) return null;

    // STEP 3: resolve storages and key
    final storages = await context.resolveStorages(rateLimit, invocation);
    final key = await context.generateKey(rateLimit.keyGenerator);

    final successfulStorages = <RateLimitStorage>[];
    RateLimitResult? denyingResult;

    for (final storage in storages) {
      final result = await storage.tryConsume(key, rateLimit.limit, rateLimit.window);

      if (result.allowed) {
        successfulStorages.add(storage);
        continue;
      }

      denyingResult = result;

      // Rollback successful storages
      for (final s in successfulStorages.reversed) {
        if (s is RollbackCapableRateLimitStorage) {
          try {
            await s.rollbackConsume(key, rateLimit.window);
          } catch (_) {}
        }
      }

      if (throwExceptionOnExceeded) {
        throw RateLimitExceededException.result(denyingResult);
      } else {
        return null;
      }
    }

    context.successfulStorages = successfulStorages;

    // All storages allowed: proceed
    return null;
  }

  @override
  FutureOr<void> afterThrowing<T>(MethodInvocation<T> invocation, Object exception, Class exceptionClass, StackTrace stackTrace) async {
    final rateLimit = invocation.getMethod().getDirectAnnotation<RateLimit>();
    if (rateLimit == null) return;

    final context = _getOrCreate().withInvocation(invocation);
    final key = await context.generateKey(rateLimit.keyGenerator);

    for (final s in context.successfulStorages.reversed) {
      if (s is RollbackCapableRateLimitStorage) {
        try {
          await s.rollbackConsume(key, rateLimit.window);
        } catch (_) {}
      }
    }
  }
}