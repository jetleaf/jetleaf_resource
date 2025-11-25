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
import '../rate_limit_configurer.dart';
import '../storage/default_rate_limit_storage.dart';
import '../../config/rate_limit_configuration.dart';
import '../storage/rate_limit_storage.dart';
import '../storage/rate_limit_storage_registry.dart';
import 'rate_limit_manager.dart';
import 'rate_limit_manager_registry.dart';

/// {@template simple_rate_limit_manager}
/// A composite [RateLimitManager] implementation that manages discovery,
/// registration, and resolution of [RateLimitStorage] instances.
///
/// The [SimpleRateLimitManager] serves as the central hub for coordinating
/// multiple rate-limit backends (e.g., in-memory, distributed caches, or
/// external systems). It supports automatic discovery of storages and configurers
/// from the application context and provides fallback behaviors when storages
/// are not found.
///
/// ### Purpose
///
/// - Maintain a synchronized registry of all [RateLimitStorage] and [RateLimitManager] pods.
/// - Auto-discover and initialize storages and configurers via
///   [ConfigurableListablePodFactory].
/// - Provide deterministic ordering for storages and managers through
///   [PriorityOrdered] and [Ordered] interfaces.
/// - Support fallback storage creation and configurable failure behavior.
/// - Expose management operations such as [clearAll] and [destroy].
///
/// ### Lifecycle
///
/// 1. Instantiate [SimpleRateLimitManager].
/// 2. Set the pod factory via [setPodFactory].
/// 3. Set the [ApplicationContext] via [setApplicationContext] — this populates
///    environment-based properties like auto-create or fail-on-missing.
/// 4. Call [onReady] to initialize and register discovered storages and configurers.
/// 5. Use [getStorage] or [getStorageNames] to retrieve managed storages.
///
/// ### Configuration Flags
///
/// | Flag | Environment Key | Default | Description |
/// |------|-----------------|----------|--------------|
/// | `_createIfNotFound` | `RateLimitConfiguration.AUTO_CREATE_WHEN_NOT_FOUND` | `true` | Whether to automatically create a new in-memory storage when none exists. |
/// | `_failIfNotFound` | `RateLimitConfiguration.FAIL_IF_NOT_FOUND` | `false` | Whether to throw [NoRateLimitFoundException] instead of silently returning `null`. |
///
/// ### Example
///
/// ```dart
/// final manager = SimpleRateLimitManager();
/// manager.setPodFactory(appContext.getPodFactory());
/// manager.setApplicationContext(appContext);
/// await manager.onReady();
///
/// final storage = await manager.getStorage('default');
/// if (storage != null) {
///   await storage.tryConsume('user:42', 10, Duration(minutes: 1));
/// }
/// ```
///
/// ### Notes
///
/// - Thread-safe registration of storages and managers using synchronized sections.
/// - Deterministic ordering ensures predictable composition of multi-backend
///   rate-limit systems.
/// - Automatically applies discovered [RateLimitConfigurer]s to customize
///   both manager and storage registries.
/// {@endtemplate}
final class SimpleRateLimitManager implements RateLimitManager, InitializingPod, PodFactoryAware, RateLimitManagerRegistry, RateLimitStorageRegistry, ApplicationContextAware {
  // ---------------------------------------------------------------------------
  // Internal State
  // ---------------------------------------------------------------------------

  /// Registry holding all discovered and registered [RateLimitManager] instances.
  ///
  /// The collection is synchronized during mutation to ensure thread safety
  /// and prevent duplicate registrations. Each manager in this set corresponds
  /// to a distinct rate-limit backend (e.g., in-memory or external systems).
  final Set<RateLimitManager> _rateLimitManagers = {};

  /// Reference to the [ConfigurableListablePodFactory] used for discovering
  /// and instantiating [RateLimitStorage] and [RateLimitConfigurer] pods.
  ///
  /// When available, this factory enables auto-discovery of storages defined
  /// in the application context, supporting eager initialization and ordered
  /// registration during [onReady].
  ConfigurableListablePodFactory? _configurableListablePodFactory;

  /// Reference to the active [ApplicationContext] associated with this manager.
  ///
  /// The application context provides:
  /// - Environment properties used to configure behavior (e.g., auto-create or fail-on-missing),
  /// - Access to the pod factory for lifecycle integration,
  /// - Awareness callbacks for storages created dynamically.
  ///
  /// This value is populated through [setApplicationContext] before [onReady].
  ApplicationContext? _applicationContext;

  /// Thread-safe registry containing all discovered and manually registered
  /// [RateLimitStorage] instances.
  ///
  /// All storages stored here participate in lookup, resolution, ordering,
  /// and lifecycle callbacks. The manager ensures synchronized access during
  /// mutation to prevent race conditions across async contexts.
  final Set<RateLimitStorage> _rateLimitStorages = {};

  /// Registry of dynamically registered [RateLimitStorageCreator] factories.
  ///
  /// Creators are invoked when a storage lookup fails and JetLeaf needs
  /// to determine whether a user-provided factory can create the missing
  /// storage on demand.  
  ///
  /// Multiple creators may be registered; they are evaluated in insertion order.
  final Set<RateLimitStorageCreator> _storageCreators = {};

  /// Whether the manager should automatically create a new storage when
  /// a requested one cannot be found.
  ///
  /// Controlled via the environment property
  /// [RateLimitConfiguration.AUTO_CREATE_WHEN_NOT_FOUND].
  ///
  /// When enabled:
  /// - A new [DefaultRateLimitStorage] instance is created using the
  ///   requested name.
  /// - The instance is registered and initialized.
  bool _createIfNotFound = true;

  /// Whether the manager should throw a [NoRateLimitFoundException]
  /// when a requested storage does not exist and cannot be created.
  ///
  /// Controlled via the environment property
  /// [RateLimitConfiguration.FAIL_IF_NOT_FOUND].
  ///
  /// When enabled:
  /// - Storage lookup failure becomes fatal.
  /// - Auto-creation and creator-based generation are bypassed.
  bool _failIfNotFound = false;

  /// {@macro simple_rate_limit_manager}
  SimpleRateLimitManager();

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

    final createIfNotFound = env.getPropertyAs<bool>(RateLimitConfiguration.AUTO_CREATE_WHEN_NOT_FOUND, Class<bool>());
    if (createIfNotFound != null) {
      _createIfNotFound = createIfNotFound;
    }

    final failIfNotFound = env.getPropertyAs<bool>(RateLimitConfiguration.FAIL_IF_NOT_FOUND, Class<bool>());
    if (failIfNotFound != null) {
      _failIfNotFound = failIfNotFound;
    }
  }

  @override
  Future<void> onReady() async {
    if (_configurableListablePodFactory != null) {
      // Discover and register all RateLimitStorage pods
      final type = Class<RateLimitStorage>(null, PackageNames.CORE);
      final pods = await _configurableListablePodFactory!.getPodsOf(type, allowEagerInit: true);

      if (pods.isNotEmpty) {
        final storages = List<RateLimitStorage>.from(pods.values);
        AnnotationAwareOrderComparator.sort(storages);

        for (final storage in storages) {
          addStorage(storage);
        }
      }

      // Discover and apply all RateLimitConfigurer pods
      final configurer = Class<RateLimitConfigurer>(null, PackageNames.CORE);
      final configurerMap = await _configurableListablePodFactory!.getPodsOf(configurer, allowEagerInit: true);

      if (configurerMap.isNotEmpty) {
        final configurers = List<RateLimitConfigurer>.from(configurerMap.values);
        AnnotationAwareOrderComparator.sort(configurers);

        for (final configurer in configurers) {
          configurer.configureRateLimitManager(this);
          configurer.configureRateLimitStorage(this);
        }
      }
    }
  }

  @override
  void addCreator(RateLimitStorageCreator createIfNotFound) async {
    return synchronizedAsync(_storageCreators, () async {
      _storageCreators.remove(createIfNotFound);
      _storageCreators.add(createIfNotFound);
    });
  }

  @override
  void addStorage(RateLimitStorage storage) {
    return synchronized(_rateLimitStorages, () {
      _rateLimitStorages.remove(storage);
      _rateLimitStorages.add(storage);
    });
  }

  @override
  void addManager(RateLimitManager manager) {
    return synchronized(_rateLimitManagers, () {
      _rateLimitManagers.remove(manager);
      _rateLimitManagers.add(manager);
    });
  }

  /// Returns all registered [RateLimitStorage] instances in deterministic order.
  ///
  /// Storages are sorted using the [AnnotationAwareOrderComparator], which
  /// respects:
  /// - `@Order` and `@PriorityOrdered` annotations,
  /// - Implementation of the [Ordered] or [PriorityOrdered] interfaces.
  ///
  /// This ensures predictable and stable evaluation order across all
  /// storages, which is essential when multiple backends participate in
  /// rate-limit resolution (e.g., memory + Redis).
  ///
  /// The returned list is a snapshot and not tied to internal mutation.
  List<RateLimitStorage> _getStorages() => AnnotationAwareOrderComparator.getOrderedItems(_rateLimitStorages);

  /// Returns all registered [RateLimitManager] instances in deterministic order.
  ///
  /// Managers discovered from the pod factory or registered manually are
  /// sorted using [AnnotationAwareOrderComparator], ensuring:
  /// - Consistent chaining order,
  /// - Predictable resolution behavior when multiple managers participate
  ///   in the lookup process.
  ///
  /// The list reflects the effective global ordering of all managers
  /// participating in the rate-limit system.
  List<RateLimitManager> _getRateLimitManagers() => AnnotationAwareOrderComparator.getOrderedItems(_rateLimitManagers);

  @override
  FutureOr<RateLimitStorage?> getStorage(String name) async {
    // 1. Ask managers
    final rateLimitManagers = _getRateLimitManagers();
    for (final manager in rateLimitManagers) {
      final rateLimit = await manager.getStorage(name);
      if (rateLimit != null) return rateLimit;
    }

    // 2. Check local storages
    final storages = _getStorages();
    for (final storage in storages) {
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
      final newStorage = DefaultRateLimitStorage.named(name);
      newStorage.setApplicationContext(_applicationContext!);
      await newStorage.onSingletonReady();

      addStorage(newStorage);

      return newStorage;
    }

    if (_failIfNotFound) {
      throw NoRateLimitFoundException(name);
    }

    return null;
  }

  @override
  FutureOr<Iterable<String>> getStorageNames() async {
    final names = <String>{};

    final rateLimitManagers = _getRateLimitManagers();
    for (final manager in rateLimitManagers) {
      final managerNames = await manager.getStorageNames();
      names.addAll(managerNames);
    }

    final storages = _getStorages();
    for (final storage in storages) {
      names.add(storage.getName());
    }

    return names;
  }

  @override
  FutureOr<void> clearAll() async {
    final storages = _getStorages();
    for (final storage in storages) {
      await storage.clear();
    }
  }

  @override
  FutureOr<void> destroy() async {
    final storages = _getStorages();
    for (final storage in storages) {
      await storage.invalidate();
      await storage.clear();
    }
  }

  @override
  String getPackageName() => PackageNames.RESOURCE;
}