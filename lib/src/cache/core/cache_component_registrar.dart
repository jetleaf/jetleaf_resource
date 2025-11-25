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
import 'package:jetleaf_pod/pod.dart';

import '../../key_generator/key_generator.dart';
import '../cache_configurer.dart';
import '../error_handler/cache_error_handler.dart';
import '../error_handler/cache_error_handler_registry.dart';
import '../manager/cache_manager.dart';
import '../resolver/cache_resolver.dart';
import 'cache_annotation_method_interceptor.dart';

/// {@template cache_component_registrar}
/// Central entry point for JetLeaf cache subsystem initialization and
/// configuration registration.
///
/// The [CacheComponentRegistrar] orchestrates the integration of cache-related
/// components (managers, resolvers, storages, and key generators) discovered
/// through the JetLeaf dependency injection system. It also participates in
/// the application lifecycle by responding to [ApplicationContextEvent]s,
/// ensuring graceful teardown of cache resources.
///
/// ### Responsibilities
///
/// - Acts as the **main cache registry** by implementing [CacheErrorHandlerRegistry].
/// - Discovers and invokes all [CacheConfigurer] pods during startup.
/// - Coordinates with [ApplicationContext] for contextual property access,
///   event listening, and cleanup.
/// - Ensures deterministic initialization order through
///   [SmartInitializingSingleton].
///
/// ### Lifecycle Overview
///
/// 1. The registrar is created and provided with a [PodFactory].
/// 2. During [onSingletonReady], all [CacheConfigurer] pods are discovered and
///    invoked to populate this registry with configured cache components.
/// 3. On [ContextClosedEvent], all managed cache managers are destroyed,
///    ensuring clean resource disposal.
///
/// ### Example
///
/// ```dart
/// final registrar = CacheComponentRegistrar();
/// registrar.setPodFactory(context.getPodFactory());
///
/// await registrar.onSingletonReady(); // Initializes and configures caches
/// ```
///
/// ### Related Components
///
/// - [CacheConfigurer] — Contributes cache configuration during initialization.
/// - [CacheManager] — Manages cache lifecycle and instances.
/// - [CacheResolver] — Resolves cache definitions from annotations.
/// - [ApplicationContext] — Provides contextual access and event integration.
///
/// {@endtemplate}
@Order(Ordered.HIGHEST_PRECEDENCE)
final class CacheComponentRegistrar extends CacheAnnotationMethodInterceptor implements SmartInitializingSingleton, ApplicationContextAware, ApplicationEventListener<ApplicationContextEvent>, CacheErrorHandlerRegistry {
  // ---------------------------------------------------------------------------
  // Internal State
  // ---------------------------------------------------------------------------

  /// {@macro cache_component_registrar}
  /// 
  /// // Creates a new [CacheComponentRegistrar] instance with the provided
  /// [KeyGenerator].
  ///
  /// The [keyGenerator] is responsible for generating consistent cache keys
  /// across cache operations. It is typically a singleton pod (e.g.
  /// [CompositeKeyGenerator]) registered in the application context.
  ///
  /// Providing a [KeyGenerator] explicitly allows greater control over cache
  /// key composition and enables integration with custom key generation
  /// strategies.
  CacheComponentRegistrar(KeyGenerator keyGenerator, CacheErrorHandler errorHandler, CacheResolver cacheResolver) {
    this.keyGenerator = keyGenerator;
    cacheErrorHandler = errorHandler;
    this.cacheResolver = cacheResolver;
  }
  
  @override
  String getPackageName() => PackageNames.RESOURCE;

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
        final manager = await applicationContext.get(Class<CacheManager>(null, PackageNames.RESOURCE));
        await manager.destroy();
      } catch (_) {}
    }
  }

  @override
  List<Object?> equalizedProperties() => [CacheComponentRegistrar];
  
  @override
  Future<void> onSingletonReady() async {
    final type = Class<CacheConfigurer>(null, PackageNames.RESOURCE);
    final pods = await applicationContext.getPodsOf(type, allowEagerInit: true);

    if (pods.isNotEmpty) {
      final configurers = List<CacheConfigurer>.from(pods.values);
      AnnotationAwareOrderComparator.sort(configurers);

      for (final configurer in configurers) {
        configurer.configureErrorHandler(this);
      }
    } else {}
  }

  @override
  void setErrorHandler(CacheErrorHandler errorHandler) {
    cacheErrorHandler = errorHandler;
  }
}