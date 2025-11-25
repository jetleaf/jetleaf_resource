import 'rate_limit_resolver.dart';

/// {@template rate_limit_resolver_registry}
/// Registry for managing [RateLimitResolver] instances.
///
/// The [RateLimitResolverRegistry] acts as the discovery and orchestration
/// point for resolver components that determine how rate limit annotations
/// map to actual storage providers at runtime.
///
/// ### Purpose
///
/// It allows different [RateLimitResolver] implementations to coexist,
/// enabling layered or composite resolution strategies.
/// For instance, one resolver may interpret annotation metadata,
/// while another might apply contextual filtering based on environment
/// or runtime configuration.
///
/// ### Typical Use Cases
///
/// - Registering multiple resolver strategies (annotation-based, rule-based, etc.)
/// - Enabling pluggable extensions for custom rate-limiting resolution.
/// - Supporting environment-specific resolution logic.
///
/// ### Example
/// ```dart
/// registry.addResolver(DefaultRateLimitResolver());
///
/// final storages = await registry.resolveStorages(
///   RateLimit(limit: 100, window: Duration(minutes: 1))
/// );
/// ```
///
/// ### Related Components
/// - [RateLimitResolver] – The entities managed by this registry.
/// - [RateLimitStorage] – The resolved output target.
/// - [RateLimitManager] – Coordinates resolution results into the limiter chain.
/// {@endtemplate}
abstract interface class RateLimitResolverRegistry {
  /// Adds a [RateLimitResolver] to the registry.
  ///
  /// ### Parameters
  /// - [resolver]: The resolver to register for later use.
  ///
  /// ### Behavior
  /// - Multiple resolvers can coexist and may be chained depending
  ///   on the implementation strategy.
  /// - Implementations should ensure thread-safe registration if used
  ///   in concurrent environments.
  ///
  /// ### Example
  /// ```dart
  /// registry.addResolver(EnvironmentAwareRateLimitResolver());
  /// ```
  void addResolver(RateLimitResolver resolver);
}