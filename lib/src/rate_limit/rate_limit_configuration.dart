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

import 'package:jetleaf_core/annotation.dart';
import 'package:jetleaf_lang/lang.dart';

import '../key_generator/key_generator.dart';
import 'concurrent_map_rate_limit_storage.dart';
import 'rate_limit.dart';
import 'rate_limit_component_registrar.dart';
import 'simple_rate_limit_manager.dart';
import 'simple_rate_limit_resolver.dart';

/// {@template rate_limit_configuration}
/// Central configuration class for the **JetLeaf Rate-Limit subsystem**.
///
/// This class defines configuration properties, default storage, manager,
/// resolver, and component registration pods. It serves as the main
/// entry point for initializing and customizing rate-limit behavior.
///
/// ### Configuration Properties
/// - [TIMEZONE]: Defines the timezone for rate-limit windows and metrics.
/// - [ENABLE_EVENTS]: Enables event emission for rate-limit actions.
/// - [ENABLE_METRICS]: Enables metrics collection for monitoring rate-limit usage.
/// - [AUTO_CREATE_WHEN_NOT_FOUND]: Automatically create missing rate-limit instances.
/// - [FAIL_IF_NOT_FOUND]: Fail when a rate-limit cannot be located.
///
/// ### Default Pods
/// JetLeaf uses these default implementations when no user-provided pod exists:
/// 1. [rateLimitComponentRegistrar]: Registers and initializes the entire rate-limit subsystem.
/// 2. [rateLimitStorage]: Default in-memory, thread-safe [ConcurrentMapRateLimitStorage].
/// 3. [rollbackRateLimitStorage]: Optional rollback-capable in-memory storage.
/// 4. [rateLimitManager]: Default [SimpleRateLimitManager] coordinating all rate-limit storage.
/// 5. [rateLimitResolver]: Default [SimpleRateLimitResolver] resolving storages by name or annotation.
///
/// ### Example
/// ```dart
/// final config = RateLimitConfiguration();
/// final registrar = config.rateLimitComponentRegistrar(myKeyGenerator, myResolver);
/// final storage = config.rateLimitStorage();
/// final manager = config.rateLimitManager();
/// final resolver = config.rateLimitResolver(manager);
/// ```
///
/// ### Notes
/// - Users may override any of the default pods by providing their own implementation.
/// - Conditional annotations (`@ConditionalOnMissingPod`, `@ConditionalOnProperty`) control
///   automatic registration of default pods.
/// - The registrar handles discovery of [RateLimitConfigurer] and ensures
///   the full subsystem is initialized with lifecycle-aware cleanup.
/// {@endtemplate}
@Configuration(RateLimitConfiguration.RATE_LIMIT_CONFIGURATION_POD_NAME)
final class RateLimitConfiguration {
  /// Property key defining the timezone used for expiration timestamps
  /// and rate-limit metrics reporting.
  ///
  /// Useful in distributed systems where consistent temporal context is
  /// required across nodes or services. Defaults to the system timezone
  /// if not explicitly configured.
  static const String TIMEZONE = "jetleaf.rate-limit.timezone";

  /// Property key enabling rate-limit event emission.
  ///
  /// When set to `true`, rate-limit operations trigger
  /// events that can be observed by listeners or metrics collectors.
  /// Disabled by default for performance optimization.
  static const String ENABLE_EVENTS = "jetleaf.rate-limit.enable.events";

  /// Property key enabling rate-limit metrics collection.
  ///
  /// When enabled, runtime statistics are recorded and made available through the
  /// monitoring subsystem.
  ///
  /// Defaults to `false` for lightweight operation.
  static const String ENABLE_METRICS = "jetleaf.rate-limit.enable.metrics";

  /// Configuration property key that controls automatic rate-limit creation.
  ///
  /// When set to `true` (e.g., in application configuration), JetLeaf will
  /// automatically create a new rate-limit instance when a requested rate-limit
  /// is not found in any registered [RateLimitManager] or [RateLimitStorage].
  ///
  /// When `false`, missing rateLimits might trigger a [NoRateLimitFoundException].
  ///
  /// Defaults to `false` if unspecified.
  static const String AUTO_CREATE_WHEN_NOT_FOUND = "jetleaf.rate-limit.enable.auto-creation";

  /// Configuration property key that determines failure behavior for missing rateLimits.
  ///
  /// When set to `true`, JetLeaf will throw a [NoRateLimitFoundException] if a
  /// requested rate-limit cannot be located in any registered [RateLimitManager] or
  /// [RateLimitStorage].
  ///
  /// When set to `false`, the system may silently ignore the missing rate-limit
  /// or defer creation based on other configuration flags such as
  /// [AUTO_CREATE_WHEN_NOT_FOUND].
  ///
  /// Defaults to `true` if unspecified.
  static const String FAIL_IF_NOT_FOUND = "jetleaf.rate-limit.enable.fail-on-missing";

  /// {@macro rate_limit_configuration}
  RateLimitConfiguration();

  /// Pod name for the **RateLimitConfiguration**.
  ///
  /// Configures Jetleaf's rate limiting subsystem, including
  /// resolver strategies and storage bindings.
  static const String RATE_LIMIT_CONFIGURATION_POD_NAME = "jetleaf.resource.rateLimitConfiguration";

  /// Pod name for the **RateLimitComponentRegistrar**.
  ///
  /// Responsible for registering all rate limit–related pods (manager,
  /// resolver, storage) into the context during initialization.
  static const String RATE_LIMIT_COMPONENT_REGISTRAR_POD_NAME = "jetleaf.resource.rateLimitComponentRegistrar";

  /// Pod name for the **RateLimitStorage**.
  ///
  /// Defines the persistence layer for rate limit counters and state.
  /// Implementations may include in-memory, Redis, or database-backed stores.
  static const String RATE_LIMIT_STORAGE_POD_NAME = "jetleaf.resource.rateLimitStorage";

  /// Pod name for the **RollBackRateLimitStorage**.
  ///
  /// Provides rollback-safe rate limit storage, ensuring counters
  /// can revert if an operation fails mid-transaction.
  static const String ROLLBACK_RATE_LIMIT_STORAGE_POD_NAME = "jetleaf.resource.rollBackRateLimitStorage";

  /// Pod name for the **RateLimitManager**.
  ///
  /// Central manager orchestrating rate limit checks, token consumption,
  /// and limit enforcement logic.
  static const String RATE_LIMIT_MANAGER_POD_NAME = "jetleaf.resource.rateLimitManager";

  /// Pod name for the **RateLimitResolver**.
  ///
  /// Determines the applicable rate limit key or policy based on request
  /// context (e.g., endpoint, IP, user, etc.).
  static const String RATE_LIMIT_RESOLVER_POD_NAME = "jetleaf.resource.rateLimitResolver";

  /// Registers the [RateLimitComponentRegistrar], the central entry point for rateLimit subsystem initialization.
  ///
  /// This pod is always registered and responsible for discovering all
  /// [RateLimitConfigurer] and initializing the full rateLimit infrastructure.
  @Pod(value: RATE_LIMIT_COMPONENT_REGISTRAR_POD_NAME)
  RateLimitComponentRegistrar rateLimitComponentRegistrar(KeyGenerator keyGenerator, RateLimitResolver resolver) {
    return RateLimitComponentRegistrar(keyGenerator, resolver);
  }

  /// Provides the default [RateLimitStorage] implementation when no custom storage pod is defined.
  ///
  /// Uses [ConcurrentMapRateLimitStorage], an in-memory, thread-safe rateLimit store suitable for
  /// lightweight caching scenarios.
  @Pod(value: RATE_LIMIT_STORAGE_POD_NAME)
  @ConditionalOnMissingPod(values: [ClassType<RateLimitStorage>()])
  @ConditionalOnProperty(prefix: "jetleaf", names: ['rate-limit.storage'], havingValue: "default", matchIfMissing: true)
  RateLimitStorage rateLimitStorage() => ConcurrentMapRateLimitStorage();

  @Pod(value: ROLLBACK_RATE_LIMIT_STORAGE_POD_NAME)
  @ConditionalOnMissingPod(values: [ClassType<RateLimitStorage>()])
  @ConditionalOnProperty(prefix: "jetleaf", names: ['rate-limit.storage'], havingValue: "rollback")
  RateLimitStorage rollbackRateLimitStorage() => RollbackCapableRateLimitStorage();

  /// Provides the default [RateLimitManager] when none is defined by the user.
  ///
  /// This manager coordinates rateLimit instances, handles eviction and expiration policies,
  /// and integrates with metrics and event subsystems.
  @Pod(value: RATE_LIMIT_MANAGER_POD_NAME)
  @ConditionalOnMissingPod(values: [ClassType<RateLimitManager>()])
  RateLimitManager rateLimitManager() => SimpleRateLimitManager();

  /// Provides the default [RateLimitResolver] implementation when none is registered.
  ///
  /// The [SimpleRateLimitResolver] integrates directly with the [RateLimitManager]
  /// and handles resolution of rateLimit methods into their corresponding rateLimits.
  @Pod(value: RATE_LIMIT_RESOLVER_POD_NAME)
  @DependsOn([ClassType<SimpleRateLimitManager>()])
  @ConditionalOnMissingPod(values: [ClassType<RateLimitResolver>()])
  RateLimitResolver rateLimitResolver(RateLimitManager rateLimitManager) => SimpleRateLimitResolver(rateLimitManager);
}