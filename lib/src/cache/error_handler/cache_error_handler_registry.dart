import 'cache_error_handler.dart';

/// A central registry for all cache-related infrastructure components.
///
/// Implementations of [CacheErrorHandlerRegistry] are responsible for collecting and
/// managing all configurable cache subsystems — such as cache managers,
/// key generators, resolvers, and error handlers.
///
/// This interface acts as the integration point for [CacheConfigurer]s
/// that contribute pods to the caching subsystem.
///
/// Typical implementations (like [AbstractCacheSupport]) provide
/// thread-safe storage, ordering, and fallback logic for registered
/// components.
abstract interface class CacheErrorHandlerRegistry {
  /// Sets the global [CacheErrorHandler] for the cache system.
  ///
  /// The registered error handler is invoked whenever a cache operation
  /// (get, put, evict, or clear) throws an exception. Implementations may
  /// choose to log, suppress, or propagate the exception.
  ///
  /// If not explicitly configured, a default error handler (either
  /// logging or throwing, depending on the environment) is used.
  void setErrorHandler(CacheErrorHandler errorHandler);
}