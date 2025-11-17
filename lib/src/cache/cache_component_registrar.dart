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

import '../key_generator/key_generator.dart';
import 'annotations.dart';
import 'cache.dart';
import 'cache_operations.dart';

/// {@template cache_component_registrar}
/// Central entry point for JetLeaf cache subsystem initialization and
/// configuration registration.
///
/// The [CacheComponentRegistrar] orchestrates the integration of cache-related
/// components (managers, resolvers, storages, and key generators) discovered
/// through the JetLeaf dependency injection system. It also participates in
/// the application lifecycle by responding to [ApplicationContextEvent]s,
/// ensuring graceful teardown of cache resources.
///
/// ### Responsibilities
///
/// - Acts as the **main cache registry** by implementing [CacheErrorHandlerRegistry].
/// - Discovers and invokes all [CacheConfigurer] pods during startup.
/// - Coordinates with [ApplicationContext] for contextual property access,
///   event listening, and cleanup.
/// - Ensures deterministic initialization order through
///   [SmartInitializingSingleton].
///
/// ### Lifecycle Overview
///
/// 1. The registrar is created and provided with a [PodFactory].
/// 2. During [onSingletonReady], all [CacheConfigurer] pods are discovered and
///    invoked to populate this registry with configured cache components.
/// 3. On [ContextClosedEvent], all managed cache managers are destroyed,
///    ensuring clean resource disposal.
///
/// ### Example
///
/// ```dart
/// final registrar = CacheComponentRegistrar();
/// registrar.setPodFactory(context.getPodFactory());
///
/// await registrar.onSingletonReady(); // Initializes and configures caches
/// ```
///
/// ### Related Components
///
/// - [CacheConfigurer] — Contributes cache configuration during initialization.
/// - [CacheManager] — Manages cache lifecycle and instances.
/// - [CacheResolver] — Resolves cache definitions from annotations.
/// - [ApplicationContext] — Provides contextual access and event integration.
///
/// {@endtemplate}
final class CacheComponentRegistrar extends CacheAnnotationMethodInterceptor implements SmartInitializingSingleton, ApplicationContextAware, ApplicationEventListener<ApplicationContextEvent>, CacheErrorHandlerRegistry {
  // ---------------------------------------------------------------------------
  // Internal State
  // ---------------------------------------------------------------------------

  /// {@macro cache_component_registrar}
  /// 
  /// // Creates a new [CacheComponentRegistrar] instance with the provided
  /// [KeyGenerator].
  ///
  /// The [keyGenerator] is responsible for generating consistent cache keys
  /// across cache operations. It is typically a singleton pod (e.g.
  /// [CompositeKeyGenerator]) registered in the application context.
  ///
  /// Providing a [KeyGenerator] explicitly allows greater control over cache
  /// key composition and enables integration with custom key generation
  /// strategies.
  CacheComponentRegistrar(KeyGenerator keyGenerator, CacheErrorHandler errorHandler, CacheResolver cacheResolver) {
    this.keyGenerator = keyGenerator;
    cacheErrorHandler = errorHandler;
    this.cacheResolver = cacheResolver;
  }
  
  @override
  String getPackageName() => PackageNames.RESOURCE;

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
        final manager = await applicationContext.get(Class<CacheManager>(null, PackageNames.RESOURCE));
        await manager.destroy();
      } catch (_) {}
    }
  }

  @override
  List<Object?> equalizedProperties() => [CacheComponentRegistrar];
  
  @override
  Future<void> onSingletonReady() async {
    final type = Class<CacheConfigurer>(null, PackageNames.RESOURCE);
    final pods = await applicationContext.getPodsOf(type, allowEagerInit: true);

    if (pods.isNotEmpty) {
      final configurers = List<CacheConfigurer>.from(pods.values);
      AnnotationAwareOrderComparator.sort(configurers);

      for (final configurer in configurers) {
        configurer.configureErrorHandler(this);
      }
    } else {}
  }

  @override
  void setErrorHandler(CacheErrorHandler errorHandler) {
    cacheErrorHandler = errorHandler;
  }
}

/// {@template jet_cache_annotation_method_interceptor}
/// A composite [ConditionalMethodInterceptor] that transparently applies
/// caching behavior based on JetLeaf cache annotations such as
/// [Cacheable], [CachePut], and [CacheEvict].
///
/// This interceptor is automatically invoked by the JetLeaf AOP subsystem
/// whenever a method carries one or more cache annotations. It determines
/// which type of cache operation(s) should run and orchestrates their
/// lifecycle in a consistent order.
///
/// ### Interception Workflow
/// When a method is invoked:
///
/// 1. **Before Invocation**
///    - If the method is annotated with `@CacheEvict(beforeInvocation: true)`,
///      the interceptor triggers the [CacheEvictOperation] before executing
///      the actual method.
///    - If the method is annotated with `@Cacheable`, the interceptor checks
///      for existing cached data using [CacheableOperation]. If a cached value
///      is found, it is returned immediately, bypassing method execution.
///
/// 2. **Method Execution**
///    - If no cached result is found (a cache miss), the method proceeds
///      normally and its result is captured.
///
/// 3. **After Invocation**
///    - If the method is annotated with `@CachePut`, the result is stored in
///      the cache through a [CachePutOperation].
///    - If the method is annotated with `@Cacheable`, and a cache miss
///      occurred, the result is cached.
///    - If the method is annotated with `@CacheEvict(beforeInvocation: false)`,
///      the [CacheEvictOperation] executes after method completion.
///
/// ### Ordering Guarantees
/// The interceptor ensures consistent execution order:
/// ```text
/// CacheEvict(beforeInvocation)
///   → Cacheable
///     → Method
///       → CachePut
///         → Cacheable (on miss)
///           → CacheEvict(afterInvocation)
/// ```
///
/// ### Example
/// ```dart
/// final interceptor = MyCacheInterceptor();
///
/// final result = await interceptor.intercept(invocation);
/// // The interceptor will automatically handle caching semantics
/// // based on the annotations present on `invocation.method`.
/// ```
///
/// ### See Also
/// - [CacheOperation]
/// - [Cacheable]
/// - [CachePut]
/// - [CacheEvict]
/// - [CacheOperationContext]
/// - [_CacheOperationContext]
/// {@endtemplate}
abstract class CacheAnnotationMethodInterceptor implements MethodBeforeInterceptor, AfterInvocationInterceptor, AfterReturningInterceptor, AroundMethodInterceptor {
  /// The **active JetLeaf [ApplicationContext]** associated with this registrar.
  ///
  /// Provides access to:
  /// - The application’s environment configuration (e.g., profiles, properties).
  /// - Event publication and subscription mechanisms.
  /// - The global lifecycle scope for cache components.
  ///
  /// Used primarily for cleanup coordination and contextual property lookups
  /// (such as determining cache error handling style).
  late ApplicationContext applicationContext;

  /// The [KeyGenerator] responsible for producing unique and consistent
  /// cache keys for annotated method invocations.
  ///
  /// This component determines how cache entries are identified and retrieved.
  /// By default, JetLeaf uses a [CompositeKeyGenerator] capable of handling
  /// complex method signatures and parameter combinations.
  ///
  /// Custom implementations can be provided to control key generation logic,
  /// such as hashing, parameter filtering, or structured key composition.
  late KeyGenerator keyGenerator;

  /// {@template cache_support.cache_error_handler}
  /// The configured error handler responsible for managing cache-related exceptions.
  ///
  /// This handler defines how runtime errors within cache operations
  /// (such as retrieval, eviction, or serialization failures) are processed.
  /// Depending on the implementation, errors may be logged, suppressed,
  /// or rethrown to propagate through the application context.
  ///
  /// ### Example:
  /// ```dart
  /// cacheErrorHandler = LoggingCacheErrorHandler();
  /// ```
  ///
  /// A `null` value indicates that no custom error handler is configured,
  /// and default error propagation will apply.
  /// {@endtemplate}
  late CacheErrorHandler cacheErrorHandler;

  /// The user-provided resolver responsible for locating caches by name.
  ///
  /// This resolver is typically registered via [CacheConfigurer] or
  /// explicitly set during cache system configuration. It determines
  /// how cache names map to actual [CacheStorage] or [Cache] instances.
  ///
  /// ### Usage
  /// ```dart
  /// _cacheResolver = SimpleCacheResolver(MyCacheManager());
  /// final cache = _cacheResolver.resolve('users');
  /// ```
  ///
  /// ### Notes
  /// - Must be set before any cache retrieval operations are performed.
  /// - Used internally by [CacheOperationContext] to find the target cache(s)
  ///   for a given key or method invocation.
  late CacheResolver cacheResolver;

  @override
  bool canIntercept(Method method) => _cached<CacheEvict>(method)
    || _cached<CachePut>(method) || _cached<Cacheable>(method) ;

  /// {@template abstract_cache_support.cached_method_check}
  /// Determines whether the given [method] is directly annotated
  /// with a specific cache-related annotation of type [T].
  ///
  /// This utility is used internally to identify methods that should
  /// participate in caching behavior (e.g., [Cacheable], [CachePut],
  /// [CacheEvict]).
  ///
  /// It performs a direct annotation check — inherited or meta-annotations
  /// are **not** considered.
  ///
  /// ### Example:
  /// ```dart
  /// final isCacheable = _cached<Cacheable>(method);
  /// if (isCacheable) {
  ///   // Apply cache interception logic
  /// }
  /// ```
  ///
  /// Returns `true` if the method has a direct annotation of type [T],
  /// otherwise `false`.
  /// {@endtemplate}
  bool _cached<T>(Method method) => method.hasDirectAnnotation<T>();

  @override
  FutureOr<void> beforeInvocation<T>(MethodInvocation<T> invocation) async {
    // Pre-eviction: CacheEvict with beforeInvocation = true
    final cacheEvict = invocation.getMethod().getDirectAnnotation<CacheEvict>();
    if (cacheEvict != null && cacheEvict.beforeInvocation) {
      final operation = CacheEvictOperation(cacheEvict);
      final context = _CacheOperationContext(invocation, applicationContext, keyGenerator, cacheErrorHandler, cacheResolver);

      await operation.execute(context);
    }
  }

  @override
  Future<T?> aroundInvocation<T>(MethodInvocation<T> invocation) async {
    final cacheable = invocation.getMethod().getDirectAnnotation<Cacheable>();
    if (cacheable != null) {
      final operation = CacheableOperation(cacheable);
      final context = _CacheOperationContext(invocation, applicationContext, keyGenerator, cacheErrorHandler, cacheResolver);

      await operation.execute(context);
      if (context.hasCachedResult()) {
        return context.getCachedResult() as T?;
      }
    }

    return null;
  }

  @override
  FutureOr<void> afterReturning<T>(MethodInvocation<T> invocation, Object? returnValue, Class? returnClass) async {
    // CachePut: store the result
    final cachePut = invocation.getMethod().getDirectAnnotation<CachePut>();
    if (cachePut != null) {
      final operation = CachePutOperation(cachePut);
      final context = _CacheOperationContext(invocation, applicationContext, keyGenerator, cacheErrorHandler, cacheResolver);
      context.setResult(returnValue);

      await operation.execute(context);
    }

    // Cacheable: cache result on miss after method execution
    final cacheable = invocation.getMethod().getDirectAnnotation<Cacheable>();
    if (cacheable != null) {
      final operation = CacheableOperation(cacheable);
      final context = _CacheOperationContext(invocation, applicationContext, keyGenerator, cacheErrorHandler, cacheResolver);
      context.setResult(returnValue);

      if (context.isCacheMiss()) {
        await operation.execute(context);
      }
    }
  }

  @override
  FutureOr<void> afterInvocation<T>(MethodInvocation<T> invocation) async {
    final cacheEvict = invocation.getMethod().getDirectAnnotation<CacheEvict>();
  
    // 6. After Invocation: handle post-eviction
    if (cacheEvict != null && !cacheEvict.beforeInvocation) {
      final operation = CacheEvictOperation(cacheEvict);
      final context = _CacheOperationContext(invocation, applicationContext, keyGenerator, cacheErrorHandler, cacheResolver);

      await operation.execute(context);
    }
  }
}

/// {@template cache_default_cache_operation_context}
/// The default implementation of [CacheOperationContext], providing a
/// comprehensive execution context for cache-related operations such as
/// `@Cacheable`, `@CachePut`, and `@CacheEvict`.
///
/// This class serves as the central runtime bridge between cache annotations,
/// cache resolution, key generation, expression evaluation, and error handling.
/// It encapsulates all metadata, state, and helper components required for a
/// single cacheable method invocation.
///
/// ### Responsibilities
/// - Generate cache keys via the configured [KeyGenerator].
/// - Resolve target caches using the [CacheResolver].
/// - Store and retrieve cached results.
/// - Manage cache-miss and result states.
/// - Delegate cache-related errors to the [CacheErrorHandler].
/// - Support expression-based evaluation through [PodExpressionResolver].
///
/// ### Example
/// ```dart
/// final context = _CacheOperationContext(
///   invocation: invocation,
///   operation: operation,
///   keyGenerator: keyGenerator,
///   cacheResolver: resolver,
///   errorHandler: errorHandler,
///   expressionContext: PodExpressionContext.of(invocation),
/// );
///
/// final key = await context.generateKey();
/// final caches = await context.resolveCaches(cacheableAnnotation);
///
/// for (final cache in caches) {
///   final value = await cache.get(key);
///   if (value != null) {
///     context.setCachedResult(value);
///     return value;
///   }
/// }
///
/// context.setCacheMiss();
/// final result = await invocation.proceed();
/// context.setResult(result);
/// await caches.first.put(key, result);
/// ```
///
/// ### Integration Notes
/// - This class is automatically created by JetLeaf’s cache interceptor chain
///   and typically not instantiated manually.
/// - It is designed to be reusable across different cache operations (get, put,
///   evict) and consistent across asynchronous or synchronous contexts.
/// - All exception handling for cache I/O is delegated to the configured
///   [CacheErrorHandler].
///
/// ### Thread Safety
/// Each instance of [_CacheOperationContext] is scoped to a single
/// method invocation and is **not** shared across threads or isolates.
///
/// ### See Also
/// - [CacheOperation]
/// - [Cacheable]
/// - [KeyGenerator]
/// - [CacheResolver]
/// - [CacheErrorHandler]
/// - [PodExpressionResolver]
/// {@endtemplate}
final class _CacheOperationContext<T> implements CacheOperationContext<T> {
  /// The reflective method invocation associated with this cache context.
  final MethodInvocation<T> _invocation;

  /// {@template cache_support.pod_factory}
  /// The [ApplicationContext] responsible for managing and
  /// providing dependency instances within the cache infrastructure.
  ///
  /// This factory serves as the central mechanism for resolving and
  /// instantiating cache-related components such as [CacheResolver],
  /// [CacheErrorHandler], and [KeyGenerator]. It integrates with the
  /// Jetleaf dependency injection container to ensure proper lifecycle
  /// management and configuration consistency.
  ///
  /// ### Example:
  /// ```dart
  /// final resolver = await applicationContext.get(Class<CacheResolver>(null, PackageNames.RESOURCE));
  /// ```
  ///
  /// This reference is initialized by the application context and should not
  /// be reassigned at runtime.
  /// {@endtemplate}
  final ApplicationContext _applicationContext;

  /// The [KeyGenerator] responsible for producing unique and consistent
  /// cache keys for annotated method invocations.
  ///
  /// This component determines how cache entries are identified and retrieved.
  /// By default, JetLeaf uses a [CompositeKeyGenerator] capable of handling
  /// complex method signatures and parameter combinations.
  ///
  /// Custom implementations can be provided to control key generation logic,
  /// such as hashing, parameter filtering, or structured key composition.
  final KeyGenerator _keyGenerator;

  /// The error handler that processes any cache operation failures.
  final CacheErrorHandler _errorHandler;

  /// Holds the actual method result (after execution).
  T? _result;

  /// Indicates whether a cache miss has occurred.
  bool _cacheMiss = false;

  /// Stores a cached result retrieved from one of the caches.
  Object? _cachedResult;

  /// The resolver used to find target caches by name.
  final CacheResolver _resolver;

  /// Creates a new cache operation context with all required collaborators.
  /// 
  /// {@macro cache_default_cache_operation_context}
  _CacheOperationContext(this._invocation, this._applicationContext, this._keyGenerator, this._errorHandler, this._resolver);

  @override
  FutureOr<Object> generateKey([String? preferredKeyGeneratorName]) async {
    if (preferredKeyGeneratorName != null) {
      final keyGenerator = await _applicationContext.getPod<KeyGenerator>(preferredKeyGeneratorName);
      return keyGenerator.generate(_invocation.getTarget(), _invocation.getMethod(), _invocation.getArgument());
    }

    return _keyGenerator.generate(_invocation.getTarget(), _invocation.getMethod(), _invocation.getArgument());
  }

  @override
  Object? getCachedResult() => _cachedResult;

  @override
  Environment getEnvironment() => _applicationContext.getEnvironment();

  @override
  ConfigurableListablePodFactory getPodFactory() => _applicationContext;

  @override
  MethodInvocation<T> getMethodInvocation() => _invocation;

  @override
  Object? getResult() => _result;

  @override
  bool hasCachedResult() => _cachedResult != null;

  @override
  bool hasResult() => _result != null;

  @override
  bool isCacheMiss() => _cacheMiss;

  @override
  FutureOr<Iterable<CacheStorage>> resolveCaches(Cacheable cacheable) async {
    final customManager = cacheable.cacheManager;
    final customResolver = cacheable.cacheResolver;

    if (customResolver != null) {
      final cacheResolver = await _applicationContext.getPod<CacheResolver>(customResolver);
      return await cacheResolver.resolveCaches(cacheable);
    }

    if (customManager != null) {
      final cacheManager = await _applicationContext.getPod<CacheManager>(customManager);
      
      final storages = <CacheStorage>[];
      for (final name in await cacheManager.getCacheNames()) {
        final cache = await cacheManager.getCache(name);
        if (cache != null) {
          storages.add(cache);
        }
      }

      return storages;
    }

    return _resolver.resolveCaches(cacheable);
  }

  @override
  void setCacheMiss() => _cacheMiss = true;

  @override
  void setCachedResult(Object? result) => _cachedResult = result;

  @override
  void setResult(Object? result) {
    if (result is T) {
      _result = result;
    }
  }

  @override
  FutureOr<void> onClear(Object exception, StackTrace stackTrace, CacheStorage cache) async {
    return _errorHandler.onClear(exception, stackTrace, cache);
  }


  @override
  FutureOr<void> onEvict(Object exception, StackTrace stackTrace, CacheStorage cache, Object key) async {
    return _errorHandler.onEvict(exception, stackTrace, cache, key);
  }

  @override
  FutureOr<void> onGet(Object exception, StackTrace stackTrace, CacheStorage cache, Object key) async {
    return _errorHandler.onGet(exception, stackTrace, cache, key);
  }

  @override
  FutureOr<void> onPut(Object exception, StackTrace stackTrace, CacheStorage cache, Object key, Object? value) async {
    return _errorHandler.onPut(exception, stackTrace, cache, key, value);
  }
}