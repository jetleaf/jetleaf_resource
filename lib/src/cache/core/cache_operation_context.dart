import 'dart:async';

import 'package:jetleaf_core/intercept.dart';
import 'package:jetleaf_lang/lang.dart';

import '../../base/operation_context.dart';
import '../error_handler/cache_error_handler.dart';
import '../resolver/cache_resolver.dart';
import '../storage/cache.dart';

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
@Generic(CacheOperationContext)
abstract interface class CacheOperationContext<T> implements ConfigurableOperationContext<Object, Cache>, CacheResolver, CacheErrorHandler {
  /// Generates a unique cache key for the current method invocation.
  ///
  /// The generated key uniquely identifies the invocation and is typically
  /// derived from:
  /// - The target object instance
  /// - The invoked method signature
  /// - The resolved argument values
  ///
  /// The actual key generation strategy is delegated to a [KeyGenerator].
  ///
  /// If [preferredKeyGeneratorName] is provided, the cache system will attempt
  /// to resolve and use a custom key generator with that name. If no matching
  /// generator is found, the default generator is used.
  ///
  /// Returns either:
  /// - A synchronously generated key, or
  /// - A [Future] that completes with the generated key
  ///
  /// The returned key must be stable and suitable for use as a cache lookup
  /// identifier.
  FutureOr<Object> generateKey([String? preferredKeyGeneratorName]);

  /// Records a value retrieved from the cache for the current invocation.
  ///
  /// Calling this method marks the context as having successfully resolved
  /// a cached result. This state is observable via [hasCachedResult].
  ///
  /// The provided [result] may be `null` if the cache explicitly stores
  /// `null` values.
  void setCachedResult(Object? result);

  /// Marks the current invocation as a cache miss.
  ///
  /// This indicates that no entry was found in the cache for the generated key.
  /// Once marked, [isCacheMiss] will return `true`.
  ///
  /// This method does not affect the invocation result produced by the
  /// underlying method.
  void setCacheMiss();

  /// Returns `true` if the current invocation resulted in a cache miss.
  ///
  /// A cache miss indicates that no cached value was available for the
  /// generated key.
  bool isCacheMiss();

  /// Returns `true` if the target method invocation has produced a result.
  ///
  /// This reflects the presence of a computed or assigned result value,
  /// independent of whether it originated from the cache or from method
  /// execution.
  bool hasResult();

  /// Retrieves the result produced by the target method invocation.
  ///
  /// Returns the method result if available, or `null` if the method has not
  /// yet been executed or no result has been assigned.
  Object? getResult();

  /// Sets the result produced by the target method invocation.
  ///
  /// This method is typically called after successful execution of the
  /// underlying method. The assigned result may later be stored in the
  /// cache by cache put or update operations.
  ///
  /// The [result] may be `null` if the method legitimately returns `null`.
  void setResult(T? result);

  /// Returns `true` if a cached result has been successfully resolved.
  ///
  /// A cached result is considered present if [setCachedResult] has been
  /// called for the current invocation context.
  bool hasCachedResult();

  /// Retrieves the cached result associated with the current invocation.
  ///
  /// Returns the cached value if present, or `null` if no cached result
  /// has been recorded.
  Object? getCachedResult();

  /// Returns the reflective method invocation associated with this context.
  ///
  /// The returned [MethodInvocation] provides access to:
  /// - The target instance
  /// - Method metadata
  /// - Invocation arguments
  /// - Result handling state
  ///
  /// This invocation object is shared across cache resolution,
  /// error handling, and execution pipelines.
  MethodInvocation<T> getMethodInvocation();
}