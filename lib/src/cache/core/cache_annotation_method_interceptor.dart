import 'dart:async';

import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_core/intercept.dart';
import 'package:jetleaf_lang/lang.dart';

import '../../key_generator/key_generator.dart';
import '../annotations.dart';
import '../error_handler/cache_error_handler.dart';
import '../operation/cache_evict_operation.dart';
import '../operation/cache_put_operation.dart';
import '../operation/cacheable_operation.dart';
import '../resolver/cache_resolver.dart';
import 'default_cache_operation_context.dart';

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
/// - [DefaultCacheOperationContext]
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

  /// Lazily initialized instance of [DefaultCacheOperationContext].
  ///
  /// The context is created only when first required for a cache operation,
  /// ensuring minimal overhead when caching is not used. Once created, the same
  /// instance is reused for the lifetime of this component.
  DefaultCacheOperationContext? _cacheOperationContext;

  /// Returns the existing [DefaultCacheOperationContext] or creates one if absent.
  ///
  /// The context is constructed using:
  /// - [applicationContext] — provides environmental configuration and dependency resolution  
  /// - [keyGenerator] — responsible for generating cache keys  
  /// - [cacheErrorHandler] — handles errors during cache read/write operations  
  /// - [cacheResolver] — resolves which caches apply for a given invocation  
  ///
  /// ### Behavior
  /// - Uses lazy initialization to avoid unnecessary object creation.  
  /// - Stores the constructed context in `_cacheOperationContext` for reuse.  
  /// - Ensures all cache operations during this component’s lifecycle share the
  ///   same configured context.
  ///
  /// ### Example
  /// ```dart
  /// final context = _getOrCreate().withInvocation(invocation);
  /// final key = await context.generateCacheKey();
  /// ```
  DefaultCacheOperationContext _getOrCreate() => _cacheOperationContext ??= DefaultCacheOperationContext(applicationContext, keyGenerator, cacheErrorHandler, cacheResolver);

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
      final context = _getOrCreate().withInvocation(invocation);
      await operation.execute(context);
    }
  }

  @override
  Future<T?> aroundInvocation<T>(MethodInvocation<T> invocation) async {
    final cacheable = invocation.getMethod().getDirectAnnotation<Cacheable>();

    if (cacheable != null) {
      final operation = CacheableOperation(cacheable);
      final context = _getOrCreate().withInvocation(invocation);

      await operation.execute(context);
      if (context.hasCachedResult()) {
        final cachedResult = context.getCachedResult();
        if (cachedResult is T?) {
          return cachedResult;
        }
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
      final context = _getOrCreate().withInvocation(invocation);
      context.setResult(returnValue);

      await operation.execute(context);
    }

    // Cacheable: cache result on miss after method execution
    final cacheable = invocation.getMethod().getDirectAnnotation<Cacheable>();

    if (cacheable != null) {
      final operation = CacheableOperation(cacheable);
      final context = _getOrCreate().withInvocation(invocation);
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
      final context = _getOrCreate().withInvocation(invocation);

      await operation.execute(context);
    }
  }
}