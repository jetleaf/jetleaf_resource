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

import 'package:jetleaf_env/env.dart';
import 'package:jetleaf_pod/pod.dart';

/// {@template jetleaf_operation_context}
/// A central contract in **JetLeaf** representing the operational context
/// available to runtime components, interceptors, and infrastructure extensions.
///
/// The `OperationContext` serves as a unified entry point for obtaining
/// references to the **application environment** and the **configurable pod
/// factory**, enabling advanced runtime behaviors such as contextual
/// configuration, dependency lookups, and dynamic pod creation.
///
/// ### Purpose
/// `OperationContext` provides low-level access to:
///
/// - The [`Environment`], which exposes configuration properties,
///   active profiles, and runtime metadata.
/// - The [`ConfigurableListablePodFactory`], which manages pod
///   definitions, lifecycle scopes, and dependency resolution.
///
/// Components such as interceptors, advisors, or custom annotations
/// often rely on this context to resolve pods dynamically or to inspect
/// environmental properties during execution.
///
/// ### Typical Usage
/// When implementing an operation (for example, a rate limit or cache operation),
/// the context is used to:
///
/// 1. **Read Configuration:**
///    ```dart
///    final timezone = context.getEnvironment().getProperty(
///      'jetleaf.rate-limit.timezone',
///      Class<String>(),
///    );
///    ```
///
/// 2. **Access or Instantiate Pods Dynamically:**
///    ```dart
///    final storage = context.getPodFactory().getPod<RateLimitStorage>();
///    ```
///
/// 3. **Perform Contextual Resolution:**
///    - Inspect current environment profiles (`dev`, `prod`, `test`, etc.).
///    - Look up conditional pods based on property values.
///    - Reconfigure or lazily initialize pod instances.
///
/// ### Extension Points
/// Framework subsystems or extensions that rely on the operational context include:
/// - **Rate Limiting:** `_RateLimitOperationContext` extends this interface to
///   access rate-limit definitions and storage backends.
/// - **Caching:** Cache interceptors use the context to resolve cache managers.
/// - **Transaction Management:** Transaction interceptors inspect the context to
///   integrate with persistence pods.
///
/// ### Example
/// ```dart
/// class MyOperationContext implements OperationContext {
///   final Environment _env;
///   final ConfigurableListablePodFactory _factory;
///
///   MyOperationContext(this._env, this._factory);
///
///   @override
///   Environment getEnvironment() => _env;
///
///   @override
///   ConfigurableListablePodFactory getPodFactory() => _factory;
/// }
/// ```
///
/// ### See Also
/// - [Environment]
/// - [ConfigurableListablePodFactory]
/// - [ApplicationContext]
/// - [RateLimitOperationContext]
/// - [CacheOperationContext]
///
/// ### Notes
/// - This interface is intended to be minimal and environment-agnostic.
/// - Implementations should be lightweight and thread-safe where applicable.
/// - Access through this context should be preferred over static lookups,
///   ensuring consistent runtime scoping within the JetLeaf container.
/// {@endtemplate}
abstract interface class OperationContext {
  /// Returns the active [Environment] associated with the current operation.
  ///
  /// The environment provides access to configuration properties,
  /// profiles, and contextual metadata. Useful for reading dynamic
  /// configuration during runtime.
  Environment getEnvironment();

  /// Returns the [ConfigurableListablePodFactory] associated with this context.
  ///
  /// The pod factory manages the lifecycle, instantiation, and dependency
  /// injection of pods within the current application context.
  ///
  /// This allows advanced components or interceptors to dynamically resolve,
  /// inspect, or create pods at runtime.
  ConfigurableListablePodFactory getPodFactory();
}

/// {@template resource}
/// Represents the contract for any JetLeaf-backed storage mechanism.
///
/// The [Resource] interface defines the minimal abstraction for all
/// cache-like, map-like, or rate-limit storage mechanisms within JetLeaf.
/// It allows the framework to uniformly reference various in-memory or
/// external resources, regardless of their concrete storage implementation.
///
/// Implementations of [Resource] are expected to be:
/// - Deterministic and consistent across concurrent access.
/// - Serializable or representable for diagnostics and management.
/// - Accessible through higher-level abstractions such as
///   [CacheManager], [RateLimitManager], or configuration pods.
///
/// ### Typical Implementations
///
/// | Implementation | Purpose |
/// |----------------|----------|
/// | [ConcurrentMapCacheResource] | Backing store for in-memory cache maps |
/// | [ConcurrentMapRateLimitResource] | In-memory rate limiting store |
/// | PersistentCacheResource | Disk-based or database-backed cache layer |
///
/// ### Example
///
/// ```dart
/// class InMemoryUserResource implements Resource {
///   final Map<String, User> _users = {};
///
///   void addUser(User user) => _users[user.id] = user;
///   User? getUser(String id) => _users[id];
/// }
///
/// final resource = InMemoryUserResource();
/// resource.addUser(User('123', 'Alice'));
/// print(resource.getUser('123')?.name); // → Alice
/// ```
///
/// ### Design Notes
///
/// The [Resource] abstraction separates *data representation* from
/// *management behavior*, enabling JetLeaf’s dependency and caching
/// systems to interoperate across heterogeneous data sources.
///
/// ### Related Interfaces
///
/// - [CacheStorage] – Defines operations for cache-level storage.
/// - [RateLimitStorage] – Defines storage behavior for rate limiting.
/// - [CacheManager] – Consumes [Resource] instances to coordinate caches.
/// - [ConfigurableListablePodFactory] – May inject or manage resources.
/// {@endtemplate}
abstract interface class Resource {}