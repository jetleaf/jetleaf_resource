import 'dart:async';

import '../core/cache_operation_context.dart';

/// {@template jetleaf_cache_operation}
/// Defines the contract for a cache operation within the JetLeaf caching subsystem.
///
/// A [CacheOperation] represents a specific cache behavior such as:
/// - **Read** operations (`@Cacheable`) — retrieving values from cache if present
/// - **Write/Update** operations (`@CachePut`) — updating or inserting cached values
/// - **Eviction** operations (`@CacheEvict`) — removing specific or all cache entries
///
/// Each concrete implementation encapsulates a distinct cache strategy and
/// interacts with the cache layer through a [CacheOperationContext].
///
/// ### Responsibilities
/// Implementations of [CacheOperation] are responsible for:
/// - Evaluating caching conditions and expressions (`condition`, `unless`)
/// - Resolving the appropriate cache instances via the [CacheResolver]
/// - Handling cache read/write/eviction logic
/// - Managing cache-related exceptions using the [CacheOperationContext]
///
/// ### Example
/// ```dart
/// final operation = CacheableOperation(cacheableAnnotation);
/// await operation.execute(context);
/// ```
///
/// In the example above, the [CacheableOperation] attempts to read a cached value
/// from the configured caches, falling back to the target method invocation if
/// the cache miss occurs.
///
/// ### Integration Notes
/// - The [CacheOperationContext] provided to [execute] acts as the carrier for
///   runtime information including method invocation data, expression resolvers,
///   and cache access coordination.
/// - Each [CacheOperation] implementation is typically stateless and reusable
///   across multiple invocations.
/// - The caching infrastructure (e.g., `CacheInterceptor`) determines which
///   operation to invoke based on the detected annotation at runtime.
///
/// ### Error Handling
/// - Use the [CacheOperationContext.CacheErrorHandler] method to safely delegate cache
///   access errors without interrupting method execution.
/// - Operations should never throw directly unless the error indicates a critical
///   framework or configuration issue.
///
/// ### Extensibility
/// Developers can define custom [CacheOperation] implementations for specialized
/// caching logic such as:
/// - Time-based expiration
/// - Hierarchical or multi-tier caching
/// - External service coordination (e.g., distributed cache refresh)
///
/// ### See Also
/// - [CacheableOperation]
/// - [CachePutOperation]
/// - [CacheEvictOperation]
/// - [CacheOperationContext]
/// - [CacheResolver]
/// {@endtemplate}
abstract interface class CacheOperation {
  /// Base constructor for cache operations.
  ///
  /// All concrete cache operations must call this to ensure consistent
  /// initialization semantics.
  const CacheOperation();

  /// Executes this cache operation with the provided [CacheOperationContext].
  ///
  /// Implementations define the full logic of the cache action:
  /// - For read operations, attempt cache lookup before proceeding.
  /// - For write operations, store the computed result after execution.
  /// - For eviction operations, remove affected entries according to configuration.
  ///
  /// @param context The runtime context providing cache metadata and execution state.
  FutureOr<void> execute<T>(CacheOperationContext<T> context);
}