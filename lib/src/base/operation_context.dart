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

import 'package:jetleaf_core/core.dart';
import 'package:jetleaf_env/env.dart';
import 'package:jetleaf_lang/lang.dart';
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
@Generic(OperationContext)
abstract interface class OperationContext<Key, Value> {
  /// Returns the active [Environment] associated with the current operation.
  ///
  /// The environment provides access to configuration properties,
  /// profiles, and contextual metadata. Useful for reading dynamic
  /// configuration during runtime.
  Environment getEnvironment();

  /// Returns the [Method] currently being invoked or associated with
  /// this operation context.
  ///
  /// This allows components, interceptors, or advisors to:
  /// - Inspect the method’s metadata, annotations, or parameters
  /// - Determine the method’s return type and signature
  /// - Perform reflective invocation if necessary
  ///
  /// Useful for runtime behaviors that depend on the method being executed,
  /// such as conditional logic, parameter resolution, or exception handling.
  Method getMethod();

  /// Represents the arguments passed to a method invocation within JetLeaf’s interception system.
  ExecutableArgument? getArgument();

  /// Returns the target object associated with the current operation or handler.
  ///
  /// The "target" is typically the instance on which a method is invoked, such as:
  /// - A pod instance in JetLeaf
  /// - A controller or service object
  ///
  /// This allows interceptors, advisors, or runtime utilities to:
  /// - Reflectively invoke methods
  /// - Access instance fields or properties
  /// - Apply cross-cutting logic like logging, validation, or exception handling
  ///
  /// Example usage:
  /// ```dart
  /// final target = operationContext.getTarget();
  /// target.someMethod(); // invoke directly or via reflection
  /// ```
  Object getTarget();

  /// Returns the list of resources associated with the current operation.
  ///
  /// Resources are typically metadata objects, payloads, or auxiliary objects
  /// required for the execution of a method. They can be used by interceptors,
  /// advisors, or the framework to:
  /// - Provide contextual data for method invocation
  /// - Supply input or configuration to handlers
  /// - Facilitate resource injection or resolution at runtime
  ///
  /// Example:
  /// ```dart
  /// final resources = operationContext.getResources();
  /// for (final resource in resources) {
  ///   // process or inspect resource
  /// }
  /// ```
  List<Resource<Key, Value>> getResources();

  /// Returns the [ConfigurableListablePodFactory] associated with this context.
  ///
  /// The pod factory manages the lifecycle, instantiation, and dependency
  /// injection of pods within the current application context.
  ///
  /// This allows advanced components or interceptors to dynamically resolve,
  /// inspect, or create pods at runtime.
  ConfigurableListablePodFactory getPodFactory();
}

/// Extension of [OperationContext] that allows modification of resources
/// during runtime.
///
/// `ConfigurableOperationContext` provides mutable access to the resources
/// associated with the operation. This is useful for:
/// - Adding resources dynamically
/// - Overriding existing resources before method invocation
/// - Managing operation-specific contextual objects
@Generic(ConfigurableOperationContext)
abstract interface class ConfigurableOperationContext<Key, Value> extends OperationContext<Key, Value> {
  /// Replaces the current list of resources with [resources].
  ///
  /// This allows the caller to reset or configure all resources at once.
  void setResources(List<Resource<Key, Value>> resources);

  /// Adds a single [resource] to the current list of resources.
  ///
  /// Useful for dynamically augmenting the operation context with additional
  /// resources without replacing the existing ones.
  void addResource(Resource<Key, Value> resource);
}