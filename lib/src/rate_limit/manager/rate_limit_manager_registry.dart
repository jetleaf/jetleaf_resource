import 'rate_limit_manager.dart';

/// {@template rate_limit_manager_registry}
/// Registry for managing and exposing [RateLimitManager] instances.
///
/// The [RateLimitManagerRegistry] coordinates multiple rate limit managers
/// that may each govern their own scope of responsibility — such as
/// different application domains, service layers, or logical partitions.
///
/// ### Purpose
///
/// This registry allows the system to support **multi-manager** setups where
/// each manager might handle a unique set of [RateLimitStorage] instances.
/// It also enables hierarchical configurations or fallback policies.
///
/// ### Use Cases
///
/// - Registering global and tenant-specific rate limit managers.
/// - Supporting composite management strategies across distributed systems.
/// - Providing an extensible registry layer for framework-level plugins.
///
/// ### Example
/// ```dart
/// final manager = DefaultRateLimitManager('core');
/// registry.addManager(manager);
///
/// final names = await manager.getStorageNames();
/// print('Registered storages: $names');
/// ```
///
/// ### Related Components
/// - [RateLimitManager] – The managed entity.
/// - [RateLimitStorage] – Underlying storage used by the manager.
/// - [RateLimitStorageRegistry] – Lower-level registry referenced by managers.
/// {@endtemplate}
abstract interface class RateLimitManagerRegistry {
  /// Adds a new [RateLimitManager] to the registry.
  ///
  /// ### Parameters
  /// - [manager]: The [RateLimitManager] instance to register.
  ///
  /// ### Behavior
  /// - Implementations may reject duplicate names or replace existing entries.
  /// - This method should be idempotent if called multiple times with the same manager.
  ///
  /// ### Example
  /// ```dart
  /// registry.addManager(MyCustomRateLimitManager('tenant-manager'));
  /// ```
  void addManager(RateLimitManager manager);
}