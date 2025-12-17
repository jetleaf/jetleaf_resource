import 'dart:async';
import 'dart:collection';

import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_core/core.dart';
import 'package:jetleaf_core/intercept.dart';
import 'package:jetleaf_env/env.dart';
import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_pod/pod.dart';

import '../../key_generator/key_generator.dart';
import '../annotations.dart';
import '../error_handler/cache_error_handler.dart';
import '../manager/cache_manager.dart';
import '../resolver/cache_resolver.dart';
import '../storage/cache.dart';
import '../storage/cache_storage.dart';
import 'cache_operation_context.dart';

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
/// final context = DefaultCacheOperationContext(
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
/// Each instance of [DefaultCacheOperationContext] is scoped to a single
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
@Generic(DefaultCacheOperationContext)
final class DefaultCacheOperationContext<T> implements CacheOperationContext<T> {
  /// The reflective method invocation associated with this cache context.
  late MethodInvocation<T> _invocation;

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

  /// Internal storage of resources associated with the operation context.
  ///
  /// This list holds all `Resource` objects that have been added to the
  /// context, either via `setResources` or `addResource`. It is used by
  /// interceptors, advisors, or the framework to provide contextual data
  /// for method execution or runtime operations.
  ///
  /// Initialized as an empty list by default.
  List<Resource<Object, Cache>> _resources = [];

  /// Creates a new cache operation context with all required collaborators.
  /// 
  /// {@macro cache_default_cache_operation_context}
  DefaultCacheOperationContext(this._applicationContext, this._keyGenerator, this._errorHandler, this._resolver);

  /// Attaches the given method [invocation] to this cache operation context and
  /// returns the updated instance.
  ///
  /// The provided [MethodInvocation] represents the reflective call being processed,
  /// including:
  /// - the target method
  /// - the target instance
  /// - resolved positional and named arguments
  ///
  /// Associating the invocation allows the caching infrastructure to:
  /// - evaluate cache keys using method arguments  
  /// - inspect method annotations and metadata  
  /// - apply conditional caching rooted in invocation state  
  ///
  /// ### Behavior
  /// - Updates the internal `_invocation` reference.
  /// - Returns the same context instance to support fluent method chaining.
  ///
  /// ### Example
  /// ```dart
  /// final context = operationContext.withInvocation(invocation);
  /// final key = await context.generateCacheKey();
  /// ```
  ///
  /// Returns:
  /// - The modified [DefaultCacheOperationContext] containing the invocation.
  DefaultCacheOperationContext withInvocation(MethodInvocation<T> invocation) {
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

  @override
  Object? getCachedResult() => _cachedResult;

  @override
  Environment getEnvironment() => _applicationContext.getEnvironment();

  @override
  ConfigurableListablePodFactory getPodFactory() => _applicationContext;

  @override
  MethodInvocation<T> getMethodInvocation() => _invocation;

  @override
  Method getMethod() => _invocation.getMethod();

  @override
  Object getTarget() => _invocation.getTarget();

  @override
  ExecutableArgument? getArgument() => _invocation.getArgument();

  @override
  void setResources(List<Resource<Object, Cache>> resources) {
    _resources = resources;
  }

  @override
  void addResource(Resource<Object, Cache> resource) {
    _resources.add(resource);
  }

  @override
  List<Resource<Object, Cache>> getResources() => UnmodifiableListView(_resources);

  @override
  Object? getResult() => _result;

  @override
  bool hasCachedResult() => _cachedResult != null;

  @override
  bool hasResult() => _result != null;

  @override
  bool isCacheMiss() => _cacheMiss;

  @override
  FutureOr<Iterable<CacheStorage>> resolveCaches(Cacheable cacheable, MethodInvocation invocation) async {
    final customManager = cacheable.cacheManager;
    final customResolver = cacheable.cacheResolver;

    if (customResolver != null) {
      final cacheResolver = await _applicationContext.getPod<CacheResolver>(customResolver);
      return await cacheResolver.resolveCaches(cacheable, invocation);
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

    return _resolver.resolveCaches(cacheable, invocation);
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