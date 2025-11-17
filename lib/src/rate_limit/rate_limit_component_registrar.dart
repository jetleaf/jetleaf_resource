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

import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_core/core.dart';
import 'package:jetleaf_core/intercept.dart';
import 'package:jetleaf_env/env.dart';
import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_pod/pod.dart';

import '../exceptions.dart';
import '../key_generator/key_generator.dart';
import 'annotations.dart';
import 'concurrent_map_rate_limit_storage.dart';
import 'rate_limit.dart';

/// {@template jet_rate_limit_component_registrar}
/// A specialized [RateLimitAnnotationMethodInterceptor] that integrates
/// rate-limit enforcement with the **JetLeaf application lifecycle**.
///
/// This registrar performs two main roles:
/// 1. **Method Interception**  
///    Inherits from [RateLimitAnnotationMethodInterceptor] to intercept methods
///    annotated with `@RateLimit` and apply rate-limiting logic automatically.
///
/// 2. **Lifecycle Management**  
///    Implements [ApplicationContextAware] and
///    [ApplicationEventListener<ApplicationContextEvent>] to perform
///    cleanup of rate-limit resources when the application context is closed.
///
/// ### Construction
/// ```dart
/// final registrar = RateLimitComponentRegistrar(keyGenerator, rateLimitResolver);
/// ```
/// - `keyGenerator`: Responsible for generating unique keys for rate-limited methods.
/// - `rateLimitResolver`: Resolves storages by annotation metadata or names.
///
/// ### Interception Workflow
/// Inherited from [RateLimitAnnotationMethodInterceptor]:
/// 1. Detect `@RateLimit` annotation on the method.
/// 2. Evaluate `unless` and `condition` predicates.
/// 3. Generate a unique key for the method invocation.
/// 4. Resolve target [RateLimitStorage] instances.
/// 5. Attempt to consume quota from each storage.
/// 6. Perform best-effort rollback if any storage denies.
/// 7. Throw [RateLimitExceededException] or record denial based on
///    `throwExceptionOnExceeded`.
///
/// ### Lifecycle Workflow
/// 1. When the application context is set via [setApplicationContext],
///    the registrar stores a reference to the active context.
/// 2. The registrar listens for [ApplicationContextEvent] events.
/// 3. On [ContextClosedEvent], it retrieves the global [RateLimitManager]
///    and calls `destroy` to clean up all managed [RateLimitStorage] instances,
///    releasing memory and any external resources.
///
/// ### Ordering
/// The registrar executes at the lowest precedence to ensure that other
/// interceptors (logging, transaction, caching) run first:
/// ```dart
/// registrar.getOrder() == Ordered.LOWEST_PRECEDENCE
/// ```
///
/// ### Example
/// ```dart
/// final keyGen = CompositeKeyGenerator();
/// final resolver = SimpleRateLimitResolver();
/// final registrar = RateLimitComponentRegistrar(keyGen, resolver);
///
/// // During application startup:
/// registrar.setApplicationContext(applicationContext);
///
/// // When annotated methods are called, rate limits are enforced automatically.
/// ```
///
/// ### Notes
/// - Best-effort cleanup ensures that even if storages fail to destroy,
///   the application context shutdown proceeds without throwing critical errors.
/// - The registrar relies on the application context to retrieve the
///   [RateLimitManager] for global destruction.
/// - Works seamlessly with rollback-capable storages to ensure quota integrity.
///
/// ### See Also
/// - [RateLimitAnnotationMethodInterceptor]
/// - [RateLimitManager]
/// - [RateLimitStorage]
/// - [ContextClosedEvent]
/// {@endtemplate}
final class RateLimitComponentRegistrar extends RateLimitAnnotationMethodInterceptor implements ApplicationContextAware, ApplicationEventListener<ApplicationContextEvent> {
  /// Creates a new [RateLimitComponentRegistrar] with the given
  /// [KeyGenerator] and [RateLimitResolver].
  /// 
  /// {@macro jet_rate_limit_component_registrar}
  RateLimitComponentRegistrar(KeyGenerator keyGenerator, RateLimitResolver rateLimitResolver) {
    this.keyGenerator = keyGenerator;
    this.rateLimitResolver = rateLimitResolver;
  }

  @override
  int getOrder() => Ordered.LOWEST_PRECEDENCE;

  @override
  void setApplicationContext(ApplicationContext applicationContext) {
    this.applicationContext = applicationContext;
  }

  @override
  bool supportsEventOf(ApplicationEvent event) => event is ContextClosedEvent;

  @override
  Future<void> onApplicationEvent(ApplicationContextEvent event) async {
    if (event.getApplicationContext() == applicationContext && event is ContextClosedEvent) {
      try {
        final manager = await applicationContext.get(Class<RateLimitManager>(null, PackageNames.RESOURCE));
        await manager.destroy();
      } catch (_) {}
    }
  }

  @override
  List<Object?> equalizedProperties() => [RateLimitComponentRegistrar];
}

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
/// - [_RateLimitOperationContext]
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

  @override
  bool canIntercept(Method method) => method.hasDirectAnnotation<RateLimit>();

  @override
  FutureOr<void> beforeInvocation<T>(MethodInvocation<T> invocation) async {
    final rateLimit = invocation.getMethod().getDirectAnnotation<RateLimit>();
    if (rateLimit == null) return;

    final context = _RateLimitOperationContext(invocation, applicationContext, keyGenerator, rateLimitResolver);

    // STEP 1: unless
    final unlessResult = await rateLimit.unless.shouldApply(context);
    if (unlessResult) {
      // Mark to skip actual invocation or store in context if needed
      context.setSkipped(true);
      return;
    }

    // STEP 2: condition
    final conditionResult = await rateLimit.condition.shouldApply(context);
    if (!conditionResult) {
      context.setSkipped(true);
    }
  }

  @override
  Future<T?> aroundInvocation<T>(MethodInvocation<T> invocation) async {
    final rateLimit = invocation.getMethod().getDirectAnnotation<RateLimit>();
    if (rateLimit == null) return null;

    final context = _RateLimitOperationContext(invocation, applicationContext, keyGenerator, rateLimitResolver);

    // Skip invocation if beforeInvocation decided to skip
    if (context.skipped()) return null;

    // STEP 3: resolve storages and key
    final storages = await context.resolveStorages(rateLimit);
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

    final context = _RateLimitOperationContext(invocation, applicationContext, keyGenerator, rateLimitResolver);
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

/// {@template _rate_limit_operation_context}
/// Internal implementation of [RateLimitOperationContext] used to encapsulate
/// runtime metadata, dependency access, and execution context for a rate-limited
/// method invocation.
///
/// This class provides the glue layer between the annotation-driven rate limit
/// system (`@RateLimit`) and JetLeaf’s dependency injection and resolution
/// infrastructure.
///
/// ### Purpose
/// - Maintain all contextual information required for executing a rate-limit operation.
/// - Provide access to the [ApplicationContext] for dependency resolution.
/// - Generate consistent rate-limit keys for the current invocation.
/// - Resolve appropriate [RateLimitStorage] instances via registered
///   [RateLimitResolver] or [RateLimitManager].
/// - Record whether a request was allowed or denied, and manage retry semantics.
///
/// ### Key Responsibilities
/// - **Key Generation:** Delegates to a [KeyGenerator] (or a named one from the
///   context) to produce consistent and unique rate-limit identifiers.
/// - **Resolver Management:** Lazily resolves the active [RateLimitResolver]
///   from the application context if none is provided.
/// - **Storage Resolution:** Determines which storages apply for a given rate
///   limit based on configuration (resolver/manager/annotation overrides).
/// - **Context Tracking:** Records allowance state, remaining quota, and retry timing.
///
/// ### Lifecycle
/// 1. Created by the rate-limit interceptor before invoking a target method.
/// 2. Used during `RateLimitAnnotationOperation.execute()` to:
///    - Generate keys
///    - Resolve storages
///    - Communicate allowed/denied results
/// 3. Disposed automatically when the operation completes.
///
/// ### Example
/// ```dart
/// final context = _RateLimitOperationContext(
///   invocation,
///   appContext,
///   defaultKeyGenerator,
///   defaultResolver,
///   true, // throwExceptionOnExceeded
/// );
///
/// final key = await context.generateKey();
/// final storages = await context.resolveStorages(rateLimit);
/// ```
///
/// {@endtemplate}
final class _RateLimitOperationContext<T> implements RateLimitOperationContext<T> {
  /// The reflective method invocation associated with this rateLimit context.
  final MethodInvocation<T> _invocation;

  /// {@template rateLimit_support.pod_factory}
  /// The [ApplicationContext] responsible for managing and
  /// providing dependency instances within the rateLimit infrastructure.
  ///
  /// This factory serves as the central mechanism for resolving and
  /// instantiating rateLimit-related components such as [RateLimitResolver] and [KeyGenerator]. It integrates with the
  /// Jetleaf dependency injection container to ensure proper lifecycle
  /// management and configuration consistency.
  ///
  /// ### Example:
  /// ```dart
  /// final resolver = await applicationContext.get(Class<RateLimitResolver>(null, PackageNames.RESOURCE));
  /// ```
  ///
  /// This reference is initialized by the application context and should not
  /// be reassigned at runtime.
  /// {@endtemplate}
  final ApplicationContext _applicationContext;
  
  /// The [KeyGenerator] responsible for producing unique and consistent
  /// rateLimit keys for annotated method invocations.
  ///
  /// This component determines how rateLimit entries are identified and retrieved.
  /// By default, JetLeaf uses a [CompositeKeyGenerator] capable of handling
  /// complex method signatures and parameter combinations.
  ///
  /// Custom implementations can be provided to control key generation logic,
  /// such as hashing, parameter filtering, or structured key composition.
  final KeyGenerator _keyGenerator;

  /// The resolver used to find target rateLimits by name.
  final RateLimitResolver _rateLimitResolver;

  /// Indicates whether the method invocation should be skipped.
  /// 
  /// Defaults to `true`. If set to `false`, the invocation will be processed.
  bool _skipped = true;

  /// Tracks all [RateLimitStorage] instances that successfully allowed
  /// a consumption for the current invocation.
  /// 
  /// Useful for rolling back consumption in case a later storage denies
  /// the request or an unexpected error occurs.
  List<RateLimitStorage> successfulStorages = [];

  /// Creates a new [_RateLimitOperationContext] for the given method invocation,
  /// dependency context, and configuration.
  ///
  /// - [_invocation]: Represents the reflective invocation being rate-limited.
  /// - [_applicationContext]: Provides dependency resolution and environment access.
  /// - [_keyGenerator]: The default key generator used for rate-limit key derivation.
  /// - [_rateLimitResolver]: The resolver responsible for locating applicable storages.
  ///
  /// The context is immutable with respect to dependencies and configuration
  /// once constructed.
  /// 
  /// {@macro _rate_limit_operation_context}
  _RateLimitOperationContext(this._invocation, this._applicationContext, this._keyGenerator, this._rateLimitResolver);
  
  @override
  FutureOr<Object> generateKey([String? preferredKeyGeneratorName]) async {
    if (preferredKeyGeneratorName != null) {
      final keyGenerator = await _applicationContext.getPod<KeyGenerator>(preferredKeyGeneratorName);
      return keyGenerator.generate(_invocation.getTarget(), _invocation.getMethod(), _invocation.getArgument());
    }

    return _keyGenerator.generate(_invocation.getTarget(), _invocation.getMethod(), _invocation.getArgument());
  }

  void setSkipped(bool skipped) => _skipped = skipped;
  bool skipped() => _skipped;

  @override
  Environment getEnvironment() => _applicationContext.getEnvironment();

  @override
  MethodInvocation<T> getMethodInvocation() => _invocation;

  @override
  ConfigurableListablePodFactory getPodFactory() => _applicationContext;

  @override
  FutureOr<Iterable<RateLimitStorage>> resolveStorages(RateLimit rateLimit) async {
    final customManager = rateLimit.rateLimitManager;
    final customResolver = rateLimit.rateLimitResolver;

    if (customResolver != null) {
      final rateLimitResolver = await _applicationContext.getPod<RateLimitResolver>(customResolver);
      return await rateLimitResolver.resolveStorages(rateLimit);
    }

    if (customManager != null) {
      final rateLimitManager = await _applicationContext.getPod<RateLimitManager>(customManager);
      
      final storages = <RateLimitStorage>[];
      for (final name in await rateLimitManager.getStorageNames()) {
        final rateLimit = await rateLimitManager.getStorage(name);
        if (rateLimit != null) {
          storages.add(rateLimit);
        }
      }

      return storages;
    }

    return _rateLimitResolver.resolveStorages(rateLimit);
  }
}