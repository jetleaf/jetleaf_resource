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

import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_core/core.dart';
import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_pod/pod.dart';

import '../../base/exceptions.dart';
import '../../config/cache_configuration.dart';
import '../cache_configurer.dart';
import '../storage/default_cache_storage.dart';
import '../storage/cache_storage.dart';
import '../storage/cache_storage_registry.dart';
import 'cache_manager.dart';
import 'cache_manager_registry.dart';

/// {@template jet_composite_cache_manager}
/// A composite registry and coordinator for multiple [CacheManager] implementations within JetLeaf.
///
/// The [SimpleCacheManager] acts as the central orchestrator for all cache
/// managers detected in the JetLeaf dependency context. It serves as both a
/// [CacheManager], [CacheStorageRegistry] and a [CacheManagerRegistry], unifying access, discovery, and
/// lifecycle management across heterogeneous caching infrastructures.
///
/// ### Overview
///
/// JetLeaf supports modular cache infrastructures, where various application
/// modules or plugins may define their own [CacheManager] pods. This composite:
///
/// - **Discovers** all [CacheStorage] and [CacheConfigurer] pods through
///   the [ConfigurableListablePodFactory].
/// - **Registers** them in deterministic order via [AnnotationAwareOrderComparator].
/// - **Delegates** cache operations to an internal [_OrderedCacheManager]
///   to ensure predictable resolution precedence.
///
/// ### Core Responsibilities
///
/// 1. Automatically discovers all [CacheStorage] and [CacheConfigurer] pods
///    from the JetLeaf application context upon initialization.
/// 2. Registers them into a synchronized composite registry via [addManager].
/// 3. Serves as a unified gateway for cache lookup, lifecycle management, and
///    global cache operations such as `clearAll` and `destroy`.
///
/// ### Configuration & Discovery
///
/// The composite leverages the [PodFactoryAware] and [InitializingPod]
/// contracts to perform eager initialization and configuration:
///
/// - On startup, [onReady] locates and orders all [CacheManager] instances.
/// - Any registered [CacheConfigurer] pods are invoked to allow
///   custom programmatic adjustments to the composite itself.
/// - Each manager is wrapped into an [_OrderedCacheManager] delegate to preserve
///   deterministic cache resolution ordering.
///
/// ### Thread Safety
///
/// Manager registration and mutation of the internal registry are performed under
/// [synchronized] blocks to prevent race conditions during concurrent startup
/// or configuration changes.
///
/// ### Example
///
/// ```dart
/// final composite = CompositeCacheManager();
/// composite.setPodFactory(appContext.getPodFactory());
///
/// await composite.onReady();
///
/// final userCache = await composite.getCache('users');
/// await userCache?.put('42', user);
/// ```
///
/// ### Related Components
///
/// - [CacheManager]: The core caching interface implemented by all managers.
/// - [CacheConfigurer]: Allows customization of cache configurations at startup.
/// - [CacheManagerRegistry]: Defines registration behavior for cache managers.
/// - [PodFactoryAware]: Enables factory injection and discovery.
/// - [InitializingPod]: Lifecycle callback for post-construction setup.
/// - [_OrderedCacheManager]: Delegates operations to multiple managers in order.
///
/// {@endtemplate}
final class SimpleCacheManager implements CacheManager, InitializingPod, PodFactoryAware, CacheManagerRegistry, CacheStorageRegistry, ApplicationContextAware {
  // ---------------------------------------------------------------------------
  // Internal State
  // ---------------------------------------------------------------------------

  /// Reference to the [ConfigurableListablePodFactory] used for cache manager discovery.
  ///
  /// This factory allows the composite to introspect all available [CacheManager]
  /// instances defined in the JetLeaf application context. It is automatically
  /// injected through the [setPodFactory] callback.
  ConfigurableListablePodFactory? _configurableListablePodFactory;

  /// Reference to the active [ApplicationContext] associated with this cache.
  ///
  /// The context provides access to environment properties, configuration
  /// sources, and registered pods. It is typically set during initialization
  /// through [setApplicationContext] and used for property resolution or
  /// context-aware cache behavior (e.g., dynamic TTLs or conditional creation).
  ApplicationContext? _applicationContext;

  /// Registry holding all discovered and registered [CacheManager] instances.
  ///
  /// The collection is synchronized during mutation to ensure thread safety
  /// and prevent duplicate registrations. Each manager in this set corresponds
  /// to a distinct cache backend (e.g., in-memory or external systems).
  final Set<CacheManager> _cacheManagers = {};

  /// Registry holding all discovered and registered [CacheStorage] instances.
  ///
  /// The collection is synchronized during mutation to ensure thread safety
  /// and prevent duplicate registrations. Each storage in this set corresponds
  /// to a distinct cache backend (e.g., in-memory or external systems).
  final Set<CacheStorage> _cacheStorages = {};

  /// Registry of dynamically registered [CacheStorageCreator] factories.
  ///
  /// Creators are invoked when a storage lookup fails and JetLeaf needs
  /// to determine whether a user-provided factory can create the missing
  /// storage on demand.  
  ///
  /// Multiple creators may be registered; they are evaluated in insertion order.
  final Set<CacheStorageCreator> _storageCreators = {};

  /// Whether to automatically create a cache when it is not found.
  ///
  /// When `true`, missing cache instances are lazily created upon first access.
  /// This provides resilience in dynamic or on-demand caching scenarios where
  /// caches are not predeclared.
  ///
  /// Defaults to `true`.
  bool _createIfNotFound = true;

  /// Whether to throw an error when a requested cache cannot be found.
  ///
  /// When `true`, attempting to access a non-existent cache results in a
  /// [NoCacheFoundException] (or similar) rather than silently creating one.
  /// Useful for strict configurations where caches must be explicitly declared.
  ///
  /// Defaults to `false`.
  bool _failIfNotFound = false;

  /// {@macro jet_composite_cache_manager}
  SimpleCacheManager();
  
  @override
  void setPodFactory(PodFactory podFactory) {
    if (podFactory is ConfigurableListablePodFactory) {
      _configurableListablePodFactory = podFactory;
    }
  }

  @override
  void setApplicationContext(ApplicationContext applicationContext) {
    _applicationContext = applicationContext;

    final env = applicationContext.getEnvironment();

    final createIfNotFound = env.getPropertyAs<bool>(CacheConfiguration.AUTO_CREATE_WHEN_NOT_FOUND, Class<bool>());
    if (createIfNotFound != null) {
      _createIfNotFound = createIfNotFound;
    }

    final failIfNotFound = env.getPropertyAs<bool>(CacheConfiguration.FAIL_IF_NOT_FOUND, Class<bool>());
    if (failIfNotFound != null) {
      _failIfNotFound = failIfNotFound;
    }
  }
  
  @override
  Future<void> onReady() async {
    if (_configurableListablePodFactory != null) {
      // Discover and register all CacheStorage pods
      final type = Class<CacheStorage>(null, PackageNames.CORE);
      final pods = await _configurableListablePodFactory!.getPodsOf(type, allowEagerInit: true);

      if (pods.isNotEmpty) {
        final storages = List<CacheStorage>.from(pods.values);
        AnnotationAwareOrderComparator.sort(storages);

        for (final storage in storages) {
          addStorage(storage);
        }
      } else {}

      // Discover and apply all CacheConfigurer pods
      final configurer = Class<CacheConfigurer>(null, PackageNames.CORE);
      final configurerMap = await _configurableListablePodFactory!.getPodsOf(configurer, allowEagerInit: true);

      if (configurerMap.isNotEmpty) {
        final configurers = List<CacheConfigurer>.from(configurerMap.values);
        AnnotationAwareOrderComparator.sort(configurers);

        for (final configurer in configurers) {
          configurer.configureCacheManager(this);
          configurer.configureCacheStorage(this);
        }
      } else {}
    }
  }

  @override
  void addManager(CacheManager cacheManager) {
    return synchronized(_cacheManagers, () {
      _cacheManagers.remove(cacheManager);
      _cacheManagers.add(cacheManager);
    });
  }

  @override
  void addStorage(CacheStorage cacheStorage) {
    return synchronized(_cacheStorages, () {
      _cacheStorages.remove(cacheStorage);
      _cacheStorages.add(cacheStorage);
    });
  }

  @override
  void addCreator(CacheStorageCreator createIfNotFound) async {
    return synchronizedAsync(_storageCreators, () async {
      _storageCreators.remove(createIfNotFound);
      _storageCreators.add(createIfNotFound);
    });
  }

  /// Retrieves all configured [CacheManager] instances, sorted according to
  /// JetLeaf's deterministic ordering rules for prioritized and ordered managers.
  ///
  /// This method organizes the available cache managers into three categories:
  /// 1. [PriorityOrdered] → Highest priority managers, sorted first.
  /// 2. [Ordered] → Ordered managers, sorted after prioritized ones.
  /// 3. Simple/default → Managers without explicit ordering.
  ///
  /// Ensuring a deterministic order is crucial for predictable cache management
  /// and consistent behavior across multiple cache managers.
  ///
  /// ### Behavior
  ///
  /// - Iterates over the internal `_cacheManagers` list.
  /// - Classifies each [CacheManager] instance as:
  ///   - [PriorityOrdered]: Added to `prioritizedManagers`.
  ///   - [Ordered]: Added to `orderedManagers`.
  ///   - Others: Added to `simpleManagers`.
  /// - Sorts each category using [AnnotationAwareOrderComparator.sort].
  /// - Concatenates the sorted lists in the following order:
  ///   1. `prioritizedManagers`
  ///   2. `orderedManagers`
  ///   3. `simpleManagers`
  /// - Returns the resulting list of [CacheManager] instances.
  ///
  /// ### Example
  ///
  /// ```dart
  /// final managers = _getCacheManagers();
  /// for (final manager in managers) {
  ///   print('Configured cache manager: ${manager.runtimeType}');
  /// }
  /// ```
  ///
  /// This guarantees that cache management operations respect explicit priority
  /// or order annotations on each manager, producing consistent cache behavior.
  ///
  /// ### Related Components
  ///
  /// - [CacheManager]: Manages caching operations and coordinates [CacheStorage]s.
  /// - [PriorityOrdered]: Marker interface for high-priority managers.
  /// - [Ordered]: Marker interface for ordered but non-priority managers.
  /// - [AnnotationAwareOrderComparator]: Utility for sorting managers
  ///   according to JetLeaf's ordering conventions.
  List<CacheManager> _getCacheManagers() => AnnotationAwareOrderComparator.getOrderedItems(_cacheManagers);

  /// Retrieves all configured [CacheStorage] instances, sorted according to
  /// JetLeaf's deterministic ordering rules for prioritized and ordered storage.
  ///
  /// This method organizes the available cache storages into three categories:
  /// 1. [PriorityOrdered] → Highest priority storages, sorted first.
  /// 2. [Ordered] → Ordered storages, sorted after prioritized ones.
  /// 3. Simple/default → Storages without explicit ordering.
  ///
  /// The method ensures predictable behavior when building cache chains by
  /// enforcing a **deterministic order** for all storage instances.
  ///
  /// ### Behavior
  ///
  /// - Iterates over the internal `_cacheStorages` list.
  /// - Classifies each [CacheStorage] instance as:
  ///   - [PriorityOrdered]: Added to `prioritizedStorages`.
  ///   - [Ordered]: Added to `orderedStorages`.
  ///   - Others: Added to `simpleStorages`.
  /// - Sorts each category using [AnnotationAwareOrderComparator.sort].
  /// - Concatenates the sorted lists in the following order:
  ///   1. `prioritizedStorages`
  ///   2. `orderedStorages`
  ///   3. `simpleStorages`
  /// - Returns the resulting list of [CacheStorage] instances.
  ///
  /// ### Example
  ///
  /// ```dart
  /// final cacheStorages = _getCacheStorages();
  /// for (final storage in cacheStorages) {
  ///   print('Using cache storage: ${storage.runtimeType}');
  /// }
  /// ```
  ///
  /// This guarantees that the cache chain will respect explicit priority or order
  /// annotations on each storage, producing consistent cache behavior.
  ///
  /// ### Related Components
  ///
  /// - [CacheStorage]: Represents an individual cache storage backend.
  /// - [PriorityOrdered]: Marker interface for high-priority storages.
  /// - [Ordered]: Marker interface for ordered but non-priority storages.
  /// - [AnnotationAwareOrderComparator]: Utility for sorting storages
  ///   according to JetLeaf's order conventions.
  List<CacheStorage> _getCacheStorages() => AnnotationAwareOrderComparator.getOrderedItems(_cacheStorages);

  @override
  FutureOr<CacheStorage?> getCache(String name) async {
    // 1. Ask managers
    final cacheManagers = _getCacheManagers();
    for (final manager in cacheManagers) {
      final cache = await manager.getCache(name);
      if (cache != null) return cache;
    }

    // 2. Check local storages
    final cacheStorages = _getCacheStorages();
    for (final storage in cacheStorages) {
      if (name.equals(storage.getName())) {
        return storage;
      }
    }

    // 3. Ask dynamically registered creators
    if (_createIfNotFound && _storageCreators.isNotEmpty) {
      for (final creator in _storageCreators) {
        final storage = await creator(name);
        if (storage != null) {
          return storage;
        }
      }
    }

    // 4. Framework fallback creation
    if (_createIfNotFound && _applicationContext != null) {
      final newStorage = DefaultCacheStorage.named(name);
      newStorage.setApplicationContext(_applicationContext!);
      await newStorage.onSingletonReady();

      addStorage(newStorage);

      return newStorage;
    }
    
    if (_failIfNotFound) {
      throw NoCacheFoundException(name);
    }

    return null;
  }

  @override
  FutureOr<Iterable<String>> getCacheNames() async {
    final names = <String>{};

    final cacheManagers = _getCacheManagers();
    for (final manager in cacheManagers) {
      final managerNames = await manager.getCacheNames();
      names.addAll(managerNames);
    }

    final cacheStorages = _getCacheStorages();
    for (final storage in cacheStorages) {
      names.add(storage.getName());
    }

    return names;
  }

  @override
  FutureOr<void> clearAll() async {
    final cacheManagers = _getCacheManagers();
    for (final manager in cacheManagers) {
      await manager.clearAll();
    }

    final cacheStorages = _getCacheStorages();
    for (final storage in cacheStorages) {
      await storage.clear();
    }
  }

  @override
  FutureOr<void> destroy() async {
    final cacheManagers = _getCacheManagers();
    for (final manager in cacheManagers) {
      await manager.destroy();
    }

    final cacheStorages = _getCacheStorages();
    for (final storage in cacheStorages) {
      await storage.invalidate();
      await storage.clear();
    }
  }
  
  @override
  String getPackageName() => PackageNames.RESOURCE;
}