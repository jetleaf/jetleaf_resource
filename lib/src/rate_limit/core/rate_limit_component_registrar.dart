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

import 'dart:async';

import 'package:jetleaf_core/annotation.dart';
import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_core/core.dart';
import 'package:jetleaf_lang/lang.dart';

import '../../base/exceptions.dart';
import '../../key_generator/key_generator.dart';
import '../manager/rate_limit_manager.dart';
import '../resolver/rate_limit_resolver.dart';
import 'rate_limit_annotation_method_interceptor.dart';

/// {@template jet_rate_limit_component_registrar}
/// A specialized [RateLimitAnnotationMethodInterceptor] that integrates
/// rate-limit enforcement with the **JetLeaf application lifecycle**.
///
/// This registrar performs two main roles:
/// 1. **Method Interception**  
///    Inherits from [RateLimitAnnotationMethodInterceptor] to intercept methods
///    annotated with `@RateLimit` and apply rate-limiting logic automatically.
///
/// 2. **Lifecycle Management**  
///    Implements [ApplicationContextAware] and
///    [ApplicationEventListener<ApplicationContextEvent>] to perform
///    cleanup of rate-limit resources when the application context is closed.
///
/// ### Construction
/// ```dart
/// final registrar = RateLimitComponentRegistrar(keyGenerator, rateLimitResolver);
/// ```
/// - `keyGenerator`: Responsible for generating unique keys for rate-limited methods.
/// - `rateLimitResolver`: Resolves storages by annotation metadata or names.
///
/// ### Interception Workflow
/// Inherited from [RateLimitAnnotationMethodInterceptor]:
/// 1. Detect `@RateLimit` annotation on the method.
/// 2. Evaluate `unless` and `condition` predicates.
/// 3. Generate a unique key for the method invocation.
/// 4. Resolve target [RateLimitStorage] instances.
/// 5. Attempt to consume quota from each storage.
/// 6. Perform best-effort rollback if any storage denies.
/// 7. Throw [RateLimitExceededException] or record denial based on
///    `throwExceptionOnExceeded`.
///
/// ### Lifecycle Workflow
/// 1. When the application context is set via [setApplicationContext],
///    the registrar stores a reference to the active context.
/// 2. The registrar listens for [ApplicationContextEvent] events.
/// 3. On [ContextClosedEvent], it retrieves the global [RateLimitManager]
///    and calls `destroy` to clean up all managed [RateLimitStorage] instances,
///    releasing memory and any external resources.
///
/// ### Ordering
/// The registrar executes at the lowest precedence to ensure that other
/// interceptors (logging, transaction, caching) run first:
/// ```dart
/// registrar.getOrder() == Ordered.LOWEST_PRECEDENCE
/// ```
///
/// ### Example
/// ```dart
/// final keyGen = CompositeKeyGenerator();
/// final resolver = SimpleRateLimitResolver();
/// final registrar = RateLimitComponentRegistrar(keyGen, resolver);
///
/// // During application startup:
/// registrar.setApplicationContext(applicationContext);
///
/// // When annotated methods are called, rate limits are enforced automatically.
/// ```
///
/// ### Notes
/// - Best-effort cleanup ensures that even if storages fail to destroy,
///   the application context shutdown proceeds without throwing critical errors.
/// - The registrar relies on the application context to retrieve the
///   [RateLimitManager] for global destruction.
/// - Works seamlessly with rollback-capable storages to ensure quota integrity.
///
/// ### See Also
/// - [RateLimitAnnotationMethodInterceptor]
/// - [RateLimitManager]
/// - [RateLimitStorage]
/// - [ContextClosedEvent]
/// {@endtemplate}
@Order(1)
final class RateLimitComponentRegistrar extends RateLimitAnnotationMethodInterceptor implements ApplicationContextAware, ApplicationEventListener<ApplicationContextEvent> {
  /// Creates a new [RateLimitComponentRegistrar] with the given
  /// [KeyGenerator] and [RateLimitResolver].
  /// 
  /// {@macro jet_rate_limit_component_registrar}
  RateLimitComponentRegistrar(KeyGenerator keyGenerator, RateLimitResolver rateLimitResolver) {
    this.keyGenerator = keyGenerator;
    this.rateLimitResolver = rateLimitResolver;
  }

  @override
  int getOrder() => Ordered.LOWEST_PRECEDENCE;

  @override
  void setApplicationContext(ApplicationContext applicationContext) {
    this.applicationContext = applicationContext;
  }

  @override
  bool supportsEventOf(ApplicationEvent event) => event is ContextClosedEvent;

  @override
  Future<void> onApplicationEvent(ApplicationContextEvent event) async {
    if (event.getApplicationContext() == applicationContext && event is ContextClosedEvent) {
      try {
        final manager = await applicationContext.get(Class<RateLimitManager>(null, PackageNames.RESOURCE));
        await manager.destroy();
      } catch (_) {}
    }
  }

  @override
  List<Object?> equalizedProperties() => [RateLimitComponentRegistrar];
}