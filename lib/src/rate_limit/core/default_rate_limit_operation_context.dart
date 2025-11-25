import 'dart:async';
import 'dart:collection';

import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_core/intercept.dart';
import 'package:jetleaf_env/env.dart';
import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_pod/pod.dart';

import '../../base/resource.dart';
import '../../key_generator/key_generator.dart';
import '../annotations.dart';
import '../manager/rate_limit_manager.dart';
import '../resolver/rate_limit_resolver.dart';
import '../storage/rate_limit_storage.dart';
import 'rate_limit_operation_context.dart';

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
/// final context = DefaultRateLimitOperationContext(
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
@Generic(DefaultRateLimitOperationContext)
final class DefaultRateLimitOperationContext<T> implements RateLimitOperationContext<T> {
  /// The reflective method invocation associated with this rateLimit context.
  late MethodInvocation<T> _invocation;

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

  /// Internal storage of resources associated with the operation context.
  ///
  /// This list holds all `Resource` objects that have been added to the
  /// context, either via `setResources` or `addResource`. It is used by
  /// interceptors, advisors, or the framework to provide contextual data
  /// for method execution or runtime operations.
  ///
  /// Initialized as an empty list by default.
  List<Resource> _resources = [];

  /// Creates a new [DefaultRateLimitOperationContext] for the given method invocation,
  /// dependency context, and configuration.
  ///
  /// - [_applicationContext]: Provides dependency resolution and environment access.
  /// - [_keyGenerator]: The default key generator used for rate-limit key derivation.
  /// - [_rateLimitResolver]: The resolver responsible for locating applicable storages.
  ///
  /// The context is immutable with respect to dependencies and configuration
  /// once constructed.
  ///
  /// {@macro _rate_limit_operation_context}
  DefaultRateLimitOperationContext(this._applicationContext, this._keyGenerator, this._rateLimitResolver);

  /// Binds the given [invocation] to this operation context and returns the
  /// updated instance.
  ///
  /// This method attaches the active [MethodInvocation] for the current
  /// rate-limited operation. The invocation contains:
  ///
  /// - the method being executed  
  /// - the target instance  
  /// - named and positional argument values  
  ///
  /// This enables rate-limit logic to:
  /// - inspect parameters referenced by dynamic limit keys  
  /// - determine the method signature and metadata  
  /// - read argument-derived identifiers for key generation  
  ///
  /// ### Behavior
  /// - The internal `_invocation` reference is updated.
  /// - The same context instance is returned for fluent chaining.
  ///
  /// ### Example
  /// ```dart
  /// final context = operationContext.withInvocation(invocation);
  /// final key = await context.generateKey(generator);
  /// ```
  ///
  /// Returns the modified context for further use.
  DefaultRateLimitOperationContext withInvocation(MethodInvocation<T> invocation) {
    _invocation = invocation;
    return this;
  }
  
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
  Method getMethod() => _invocation.getMethod();

  @override
  Object getTarget() => _invocation.getTarget();

  @override
  MethodArgument? getArgument() => _invocation.getArgument();

  @override
  void setResources(List<Resource> resources) {
    _resources = resources;
  }

  @override
  void addResource(Resource resource) {
    _resources.add(resource);
  }

  @override
  List<Resource> getResources() => UnmodifiableListView(_resources);

  @override
  ConfigurableListablePodFactory getPodFactory() => _applicationContext;

  @override
  FutureOr<Iterable<RateLimitStorage>> resolveStorages(RateLimit rateLimit, MethodInvocation invocation) async {
    final customManager = rateLimit.rateLimitManager;
    final customResolver = rateLimit.rateLimitResolver;

    if (customResolver != null) {
      final rateLimitResolver = await _applicationContext.getPod<RateLimitResolver>(customResolver);
      return await rateLimitResolver.resolveStorages(rateLimit, invocation);
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

    return _rateLimitResolver.resolveStorages(rateLimit, invocation);
  }
}