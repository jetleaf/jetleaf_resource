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
import '../cache/core/cache_component_registrar.dart';
import '../cache/error_handler/cache_error_handler.dart';
import '../cache/error_handler/loggable_cache_error_handler.dart';
import '../cache/error_handler/throwable_cache_error_handler.dart';
import '../cache/manager/cache_manager.dart';
import '../cache/manager/simple_cache_manager.dart';
import '../cache/resolver/cache_resolver.dart';
import '../cache/storage/cache_storage.dart';
import '../cache/storage/default_cache_storage.dart';
import '../cache/resolver/simple_cache_resolver.dart';

/// {@template jet_cache_configuration}
/// Primary configuration class for the JetLeaf caching subsystem.
///
/// The [CacheConfiguration] provides the default cache component
/// definitions (pods) for the framework. These definitions are registered
/// into the application context during startup, ensuring that caching
/// behavior is available even when no user-defined implementations are present.
///
/// ### Overview
///
/// This configuration establishes a baseline cache environment by
/// registering essential components such as:
///
/// - [CacheManager] — Manages cache lifecycles and storage backends.
/// - [CacheStorage] — Provides actual cache data storage (in-memory by default).
/// - [CacheResolver] — Resolves cache definitions for annotated methods.
/// - [CacheErrorHandler] — Handles cache operation failures gracefully.
/// - [CacheComponentRegistrar] — Initializes and wires cache infrastructure.
///
/// All pods are registered with conditional annotations such as
/// [ConditionalOnMissingPod] or [ConditionalOnProperty], enabling
/// users to override or replace specific components via configuration
/// or custom pods.
///
/// ### Configuration Properties
///
/// | Key | Description | Default |
/// | --- | ------------ | -------- |
/// | `jetleaf.cache.ttl` | Default time-to-live for cache entries | Unbounded |
/// | `jetleaf.cache.timezone` | Zone for expiration calculations | System default |
/// | `jetleaf.cache.eviction-policy` | Cache eviction strategy (`LRU`, `LFU`, `FIFO`) | `LRU` |
/// | `jetleaf.cache.maxEntries` | Maximum number of entries per cache | Unlimited |
/// | `jetleaf.cache.enable.events` | Enables event emission on cache operations | `false` |
/// | `jetleaf.cache.enable.metrics` | Enables cache metrics collection | `false` |
///
/// ### Example
///
/// ```dart
/// @Configuration("jetleaf.cacheConfiguration")
/// final class CacheConfiguration {
///   @Pod()
///   CacheManager cacheManager() => SimpleCacheManager();
/// }
/// ```
///
/// ### Related Components
/// - [SimpleCacheManager]
/// - [DefaultCacheStorage]
/// - [SimpleCacheResolver]
/// - [CacheComponentRegistrar]
/// - [LoggableCacheErrorHandler], [ThrowableCacheErrorHandler]
///
/// {@endtemplate}
@Configuration(CacheConfiguration.CACHE_CONFIGURATION_POD_NAME)
final class CacheConfiguration {
  // ---------------------------------------------------------------------------
  // Configuration Keys
  // ---------------------------------------------------------------------------

  /// Default property key defining the cache entry time-to-live (TTL) duration.
  ///
  /// Specifies how long an entry remains valid before automatic expiration.
  /// The value is typically expressed in seconds, minutes, or as a duration
  /// string (e.g., `"5m"`, `"1h"`, `"30s"`).
  ///
  /// If not set, the cache may retain entries indefinitely or rely on
  /// the configured [EVICTION_POLICY] to determine expiration.
  static const String TTL = "jetleaf.cache.ttl";

  /// Property key defining the timezone used for expiration timestamps
  /// and cache metrics reporting.
  ///
  /// Useful in distributed systems where consistent temporal context is
  /// required across nodes or services. Defaults to the system timezone
  /// if not explicitly configured.
  static const String TIMEZONE = "jetleaf.cache.timezone";

  /// Property key controlling the cache eviction policy.
  ///
  /// Determines how entries are removed when the cache reaches capacity.
  /// Supported values include:
  /// - `LRU` — Least Recently Used
  /// - `LFU` — Least Frequently Used
  /// - `FIFO` — First In, First Out
  ///
  /// Defaults to `LRU` if unspecified.
  static const String EVICTION_POLICY = "jetleaf.cache.eviction-policy";

  /// Property key defining the maximum number of entries allowed per cache.
  ///
  /// Once the limit is reached, entries are evicted based on the
  /// [EVICTION_POLICY]. A value of `0` or negative disables entry limit enforcement.
  static const String MAX_ENTRIES = "jetleaf.cache.maxEntries";

  /// Property key enabling cache event emission.
  ///
  /// When set to `true`, cache operations (put, evict, clear) trigger
  /// events that can be observed by listeners or metrics collectors.
  /// Disabled by default for performance optimization.
  static const String ENABLE_EVENTS = "jetleaf.cache.enable.events";

  /// Property key enabling cache metrics collection.
  ///
  /// When enabled, runtime statistics such as hit/miss rates, eviction counts,
  /// and latency measurements are recorded and made available through the
  /// monitoring subsystem.
  ///
  /// Defaults to `false` for lightweight operation.
  static const String ENABLE_METRICS = "jetleaf.cache.enable.metrics";

  /// Configuration property key that controls automatic cache creation.
  ///
  /// When set to `true` (e.g., in application configuration), JetLeaf will
  /// automatically create a new cache instance when a requested cache
  /// is not found in any registered [CacheManager] or [CacheStorage].
  ///
  /// When `false`, missing caches might trigger a [NoCacheFoundException].
  ///
  /// Defaults to `false` if unspecified.
  static const String AUTO_CREATE_WHEN_NOT_FOUND = "jetleaf.cache.enable.auto-creation";

  /// Configuration property key that determines failure behavior for missing caches.
  ///
  /// When set to `true`, JetLeaf will throw a [NoCacheFoundException] if a
  /// requested cache cannot be located in any registered [CacheManager] or
  /// [CacheStorage].
  ///
  /// When set to `false`, the system may silently ignore the missing cache
  /// or defer creation based on other configuration flags such as
  /// [AUTO_CREATE_WHEN_NOT_FOUND].
  ///
  /// Defaults to `true` if unspecified.
  static const String FAIL_IF_NOT_FOUND = "jetleaf.cache.enable.fail-on-missing";

  /// {@macro jet_cache_configuration}
  CacheConfiguration();

  /// Pod name for the **CacheConfiguration** module.
  ///
  /// Responsible for setting up Jetleaf's caching layer (CacheManager,
  /// CacheResolver, etc.) during auto-configuration.
  static const String CACHE_CONFIGURATION_POD_NAME = "jetleaf.resource.cacheConfiguration";

  /// Pod name for the **CacheComponentRegistrar**.
  ///
  /// Handles registration of Jetleaf's core cache components into
  /// the application context.
  static const String CACHE_COMPONENT_REGISTRAR_POD_NAME = "jetleaf.resource.cacheComponentRegistrar";

  /// Pod name for the **CacheStorage**.
  ///
  /// Represents the backend storage interface for caches (in-memory,
  /// distributed, etc.).
  static const String CACHE_STORAGE_POD_NAME = "jetleaf.resource.cacheStorage";

  /// Pod name for the **CacheManager**.
  ///
  /// High-level orchestrator for cache lifecycle management and
  /// cache retrieval operations.
  static const String CACHE_MANAGER_POD_NAME = "jetleaf.resource.cacheManager";

  /// Pod name for the **CacheResolver**.
  ///
  /// Responsible for resolving which cache(s) apply to a given invocation
  /// or operation context.
  static const String CACHE_RESOLVER_POD_NAME = "jetleaf.resource.cacheResolver";

  /// Pod name for the **LoggableCacheErrorHandler**.
  ///
  /// Cache error handler that logs all cache operation failures without
  /// interrupting program flow.
  static const String LOGGABLE_CACHE_ERROR_HANDLER_POD_NAME = "jetleaf.resource.loggableCacheErrorHandler";

  /// Pod name for the **ThrowableCacheErrorHandler**.
  ///
  /// Cache error handler that throws encountered exceptions,
  /// used when strict cache consistency is required.
  static const String THROWABLE_CACHE_ERROR_HANDLER_POD_NAME = "jetleaf.resource.throwableCacheErrorHandler";

  // ---------------------------------------------------------------------------
  // Pod Definitions
  // ---------------------------------------------------------------------------

  /// Registers the [CacheComponentRegistrar], the central entry point for cache subsystem initialization.
  ///
  /// This pod is always registered and responsible for discovering all
  /// [CacheConfigurer] and initializing the full cache infrastructure.
  @Pod(value: CACHE_COMPONENT_REGISTRAR_POD_NAME)
  CacheComponentRegistrar cacheComponentRegistrar(KeyGenerator keyGenerator, CacheErrorHandler cacheErrorHandler, CacheResolver resolver) {
    return CacheComponentRegistrar(keyGenerator, cacheErrorHandler, resolver);
  }

  /// Provides the default [CacheStorage] implementation when no custom storage pod is defined.
  ///
  /// Uses [DefaultCacheStorage], an in-memory, thread-safe cache store suitable for
  /// lightweight caching scenarios.
  @Pod(value: CACHE_STORAGE_POD_NAME)
  @ConditionalOnMissingPod(values: [ClassType<CacheStorage>()])
  CacheStorage cacheStorage() => DefaultCacheStorage();

  /// Provides the default [CacheManager] when none is defined by the user.
  ///
  /// This manager coordinates cache instances, handles eviction and expiration policies,
  /// and integrates with metrics and event subsystems.
  @Pod(value: CACHE_MANAGER_POD_NAME)
  @ConditionalOnMissingPod(values: [ClassType<CacheManager>()])
  CacheManager cacheManager() => SimpleCacheManager();

  /// Provides the default [CacheResolver] implementation when none is registered.
  ///
  /// The [SimpleCacheResolver] integrates directly with the [CacheManager]
  /// and handles resolution of cacheable methods into their corresponding caches.
  @Pod(value: CACHE_RESOLVER_POD_NAME)
  @DependsOn([ClassType<SimpleCacheManager>()])
  @ConditionalOnMissingPod(values: [ClassType<CacheResolver>()])
  CacheResolver cacheResolver(CacheManager cacheManager) => SimpleCacheResolver(cacheManager);

  /// Provides a loggable [CacheErrorHandler] if no other handler is configured.
  ///
  /// This handler logs all cache-related errors instead of throwing them,
  /// promoting non-intrusive error handling for production environments.
  @Pod(value: LOGGABLE_CACHE_ERROR_HANDLER_POD_NAME)
  @ConditionalOnMissingPod(values: [ClassType<CacheErrorHandler>()])
  @ConditionalOnProperty(prefix: "jetleaf", names: ['cache.error-handler'], havingValue: "log", matchIfMissing: true)
  CacheErrorHandler loggableCacheErrorHandler() => LoggableCacheErrorHandler();

  /// Provides a throwable [CacheErrorHandler] that rethrows cache operation errors.
  ///
  /// Use this mode for development or debugging environments where visibility
  /// of caching issues is required.
  @Pod(value: THROWABLE_CACHE_ERROR_HANDLER_POD_NAME)
  @ConditionalOnMissingPod(values: [ClassType<CacheErrorHandler>()])
  @ConditionalOnProperty(prefix: "jetleaf", names: ['cache.error-handler'], havingValue: "throw")
  CacheErrorHandler throwableCacheErrorHandler() => ThrowableCacheErrorHandler();
}