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

import 'package:jetleaf_core/core.dart';
import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_pod/pod.dart';

import 'annotations.dart';
import 'cache.dart';

/// {@template jet_simple_cache_resolver}
/// Default JetLeaf implementation of the [CacheResolver] interface, providing
/// a simple yet extensible mechanism for resolving [Cacheable] annotations
/// to their corresponding [CacheStorage] instances.
///
/// The [SimpleCacheResolver] integrates closely with the JetLeaf dependency
/// injection system by leveraging a [ConfigurableListablePodFactory] to
/// automatically discover and configure [CacheResolver] and [CacheConfigurer]
/// pods within the application context. This allows it to dynamically extend
/// its resolution chain based on active modules or framework components.
///
/// ### Overview
///
/// The resolver maintains an **ordered, composite chain** of delegate
/// [CacheResolver]s. Each resolver in the chain is sorted and prioritized
/// using the [AnnotationAwareOrderComparator], ensuring deterministic and
/// predictable resolution order.
///
/// If no registered resolver can handle a particular [Cacheable] annotation,
/// the [SimpleCacheResolver] falls back to the provided [CacheManager] to
/// resolve caches by name.
///
/// ### Lifecycle & Initialization
///
/// During startup, the resolver:
///
/// 1. Receives a [PodFactory] reference via [setPodFactory].
/// 2. Discovers [CacheConfigurer] pods via the factory.
/// 3. Invokes their [CacheConfigurer.configureCacheResolver] methods to
///    dynamically register additional [CacheResolver] instances.
/// 4. Sorts and chains all registered resolvers for runtime use.
///
/// This behavior enables modular configuration of cache resolution logic across
/// different JetLeaf packages or application layers.
///
/// ### Example
///
/// ```dart
/// final resolver = SimpleCacheResolver(defaultCacheManager);
/// await resolver.onReady();
///
/// final caches = await resolver.resolveCaches(Cacheable('users'));
/// for (final cache in caches) {
///   print('Resolved cache: ${cache.getName()}');
/// }
/// ```
///
/// ### Related Components
///
/// - [CacheResolver]: The interface this class implements.
/// - [CacheManager]: Used as a fallback for direct cache lookups.
/// - [CacheStorage]: The concrete cache storage type returned by the resolver.
/// - [CacheConfigurer]: For dynamic resolver configuration.
/// - [CompositeCacheResolver]: The more complex, composite alternative.
///
/// {@endtemplate}
final class SimpleCacheResolver implements CacheResolver, InitializingPod, PodFactoryAware, CacheResolverRegistry {
  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  /// The primary [CacheManager] used as a fallback for cache resolution.
  ///
  /// If no registered [CacheResolver] successfully resolves a cache, this
  /// manager is queried to locate caches by their declared names.
  final CacheManager _cacheManager;

  // ---------------------------------------------------------------------------
  // Internal State
  // ---------------------------------------------------------------------------

  /// Internal ordered set of [CacheResolver] pods participating in this composite chain.
  ///
  /// The collection ensures each resolver is unique and registration is synchronized
  /// to guarantee thread-safe updates during initialization or dynamic configuration.
  final Set<CacheResolver> _cacheResolvers = {};

  /// Reference to the [ConfigurableListablePodFactory] used for resolver discovery.
  ///
  /// This factory is injected via [setPodFactory] and is used to locate all
  /// [CacheResolver] and [CacheConfigurer] pods within the JetLeaf application context.
  ConfigurableListablePodFactory? _configurableListablePodFactory;

  /// {@macro jet_simple_cache_resolver}
  SimpleCacheResolver(this._cacheManager);

  @override
  void setPodFactory(PodFactory podFactory) {
    if (podFactory is ConfigurableListablePodFactory) {
      _configurableListablePodFactory = podFactory;
    }
  }

  @override
  Future<void> onReady() async {
    if (_configurableListablePodFactory != null) {
      // Discover and apply all CacheConfigurer pods
      final configurer = Class<CacheConfigurer>(null, PackageNames.CORE);
      final configurerMap = await _configurableListablePodFactory!.getPodsOf(configurer, allowEagerInit: true);

      if (configurerMap.isNotEmpty) {
        final configurers = List<CacheConfigurer>.from(configurerMap.values);
        AnnotationAwareOrderComparator.sort(configurers);

        for (final configurer in configurers) {
          configurer.configureCacheResolver(this);
        }
      } else {}
    }
  }

  @override
  void addResolver(CacheResolver cacheResolver) {
    _cacheResolvers.remove(cacheResolver);
    _cacheResolvers.add(cacheResolver);
  }

  @override
  String getPackageName() => PackageNames.RESOURCE;

  // ---------------------------------------------------------------------------
  // Resolver Chain Construction
  // ---------------------------------------------------------------------------

  /// Constructs a deterministically ordered list of [CacheResolver]s.
  ///
  /// The method groups resolvers into three categories:
  /// - [PriorityOrdered] — executed first.
  /// - [Ordered] — executed second.
  /// - Unordered — executed last.
  ///
  /// This ensures predictable chain composition and consistent resolution behavior.
  List<CacheResolver> _getResolvers() => AnnotationAwareOrderComparator.getOrderedItems(_cacheResolvers);
  
  @override
  FutureOr<Iterable<CacheStorage>> resolveCaches(Cacheable cacheable) async {
    final caches = <String, CacheStorage>{};

    for (final resolver in _getResolvers()) {
      try {
        final resolved = await resolver.resolveCaches(cacheable);
        caches.addAll(resolved.toMap((store) => store.getName(), (store) => store));
      } catch (e) {
        // Continue with next resolver on error to preserve resilience.
        continue;
      }
    }

    final currentNames = cacheable.cacheNames;

    for (final name in currentNames) {
      final managedCache = await _cacheManager.getCache(name);
      if (managedCache != null) {
        caches.add(managedCache.getName(), managedCache);
      }
    }

    for (final name in currentNames) {
      final managedCache = await _cacheManager.getCache(name);
      if (managedCache != null) {
        caches.add(managedCache.getName(), managedCache);
      }
    }

    return caches.values;
  }
}