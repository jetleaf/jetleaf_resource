import 'dart:async';

import 'package:jetleaf_core/intercept.dart';

import '../../base/operation_context.dart';
import '../error_handler/cache_error_handler.dart';
import '../resolver/cache_resolver.dart';

/// {@template jet_cache_operation_context}
/// Defines the execution context for a cache operation within JetLeaf’s
/// caching subsystem.
///
/// A [CacheOperationContext] represents the complete state of a cacheable
/// method invocation, providing access to method metadata, generated cache
/// keys, operation definitions, and resolved cache instances.  
///
/// This interface bridges the gap between **runtime cache operations**
/// (like `Cacheable`, `CachePut`, `CacheEvict`) and their **execution logic**
/// (implemented by [CacheOperation] objects).
///
/// ### Responsibilities
/// - Generating and storing the **cache key** for the current method invocation.
/// - Tracking and managing **cached results** and **execution results**.
/// - Serving as a unified view of method invocation metadata through
///   [MethodInvocation].
/// - Handling cache-related errors and resolving applicable caches.
///
/// ### Lifecycle Overview
/// 1. A cacheable method is invoked.
/// 2. A [CacheOperationContext] is created by the cache interceptor.
/// 3. The operation (e.g., `CacheableOperation`) calls [generateKey] and
///    [resolveCaches] to locate or modify caches.
/// 4. Results or errors are recorded using [setCachedResult],
///    [setResult], or [CacheErrorHandler].
/// 5. The context may then be reused for post-execution processing.
///
/// ### Example
/// ```dart
/// final context = MyCacheOperationContext(invocation, cacheOperation);
///
/// // Generate a cache key
/// final key = await context.generateKey(annotation.keyGenerator);
///
/// // Fetch or store results
/// if (context.hasCachedResult()) {
///   return context.getCachedResult();
/// }
///
/// final result = await invocation.proceed();
/// context.setResult(result);
///
/// await cache.put(key, result);
/// ```
///
/// ### Implementations
/// Custom implementations may be created for advanced caching behavior,
/// such as distributed cache contexts, asynchronous cache coordination,
/// or context-aware error policies.
///
/// ### Thread Safety
/// Implementations should ensure thread safety, particularly when caching
/// is performed concurrently or in reactive execution models.
///
/// ### See Also
/// - [CacheOperation]
/// - [Cacheable]
/// - [CacheResolver]
/// - [CacheErrorHandler]
/// - [MethodInvocation]
/// {@endtemplate}
abstract interface class CacheOperationContext<T> implements ConfigurableOperationContext, CacheResolver, CacheErrorHandler {
  /// Generates a unique cache key for the current method invocation.
  ///
  /// This key is typically based on the target object, method signature,
  /// and argument values (see [KeyGenerator]).
  /// 
  /// - param [preferredKeyGeneratorName] is for any custom generator the developer prefers to use
  FutureOr<Object> generateKey([String? preferredKeyGeneratorName]);

  /// Records a retrieved value from the cache.
  ///
  /// This marks the current invocation as having a cached result,
  /// allowing subsequent checks through [hasCachedResult].
  void setCachedResult(Object? result);

  /// Marks the context as a cache miss.
  ///
  /// Indicates that no cached value was found for the generated key.
  void setCacheMiss();

  /// Returns `true` if the current invocation resulted in a cache miss.
  bool isCacheMiss();

  /// Returns `true` if the target method produced a result.
  bool hasResult();

  /// Retrieves the actual result from the target method invocation.
  ///
  /// Returns `null` if no result is yet available.
  Object? getResult();

  /// Sets the result produced by the target method.
  ///
  /// This allows caching operations (e.g., [CachePutOperation]) to store
  /// the method result into cache layers.
  void setResult(T? result);

  /// Returns `true` if a cached result was found.
  bool hasCachedResult();

  /// Retrieves the cached result associated with the current context.
  ///
  /// Returns `null` if no cached result is available.
  Object? getCachedResult();

  /// Returns the reflective method invocation associated with this context.
  ///
  /// Contains method metadata and invocation state such as arguments,
  /// target instance, and return value handling.
  MethodInvocation<T> getMethodInvocation();
}