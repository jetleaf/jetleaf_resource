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
import 'rate_limit.dart';

/// {@template simple_rate_limit_resolver}
/// A simple, composite [RateLimitResolver] implementation that delegates
/// storage resolution to a chain of configured resolvers and a primary
/// [RateLimitManager] fallback.
///
/// This resolver supports automatic discovery of [RateLimitConfigurer] pods
/// at initialization and allows dynamic addition of custom resolvers. It
/// orders resolvers deterministically based on priority interfaces such as
/// [PriorityOrdered] and [Ordered].
///
/// ### Purpose
///
/// - Resolve [RateLimitStorage] instances for a given [RateLimit] annotation.
/// - Compose multiple [RateLimitResolver]s into an ordered chain for layered
///   resolution logic.
/// - Fallback to the primary [RateLimitManager] for storage resolution if
///   no resolver produces a result.
/// - Support runtime registration of additional resolvers.
///
/// ### Key Responsibilities
///
/// - Maintain an internal set of [RateLimitResolver]s with deterministic ordering.
/// - Discover and apply all [RateLimitConfigurer] pods via [ConfigurableListablePodFactory].
/// - Resolve storages by iterating through all resolvers in priority order,
///   falling back to the [RateLimitManager] when necessary.
/// - Ensure storage resolution exceptions in one resolver do not prevent
///   other resolvers from executing.
///
/// ### Lifecycle
///
/// 1. Instantiate [SimpleRateLimitResolver].
/// 2. Set the pod factory via [setPodFactory].
/// 3. Call [onReady] to initialize and configure resolvers.
/// 4. Use [resolveStorages] to obtain resolved [RateLimitStorage] instances
///    for a given [RateLimit].
///
/// ### Example
///
/// ```dart
/// final resolver = SimpleRateLimitResolver();
/// resolver.setPodFactory(appContext.getPodFactory());
/// await resolver.onReady();
///
/// final storages = await resolver.resolveStorages(rateLimitAnnotation);
/// for (final storage in storages) {
///   print('Resolved storage: ${storage.getName()}');
/// }
/// ```
///
/// {@endtemplate}
final class SimpleRateLimitResolver implements RateLimitResolver, InitializingPod, PodFactoryAware, RateLimitResolverRegistry {
  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  /// The primary [RateLimitManager] used as a fallback for storage resolution.
  final RateLimitManager _rateLimitManager;

  // ---------------------------------------------------------------------------
  // Internal State
  // ---------------------------------------------------------------------------

  /// Internal ordered set of [RateLimitResolver] pods in the composite chain.
  final Set<RateLimitResolver> _rateLimitResolvers = {};

  /// Reference to the [ConfigurableListablePodFactory] for resolver discovery.
  ConfigurableListablePodFactory? _configurableListablePodFactory;

  /// {@macro simple_rate_limit_resolver}
  SimpleRateLimitResolver(this._rateLimitManager);

  @override
  void setPodFactory(PodFactory podFactory) {
    if (podFactory is ConfigurableListablePodFactory) {
      _configurableListablePodFactory = podFactory;
    }
  }

  @override
  Future<void> onReady() async {
    if (_configurableListablePodFactory != null) {
      // Discover and apply all RateLimitConfigurer pods
      final configurer = Class<RateLimitConfigurer>(null, PackageNames.CORE);
      final configurerMap = await _configurableListablePodFactory!.getPodsOf(configurer, allowEagerInit: true);

      if (configurerMap.isNotEmpty) {
        final configurers = List<RateLimitConfigurer>.from(configurerMap.values);
        AnnotationAwareOrderComparator.sort(configurers);

        for (final configurer in configurers) {
          configurer.configureRateLimitResolver(this);
        }
      }
    }
  }

  @override
  void addResolver(RateLimitResolver rateLimitResolver) {
    _rateLimitResolvers.remove(rateLimitResolver);
    _rateLimitResolvers.add(rateLimitResolver);
  }

  @override
  String getPackageName() => PackageNames.RESOURCE;

  /// Constructs a deterministically ordered list of [RateLimitResolver]s.
  List<RateLimitResolver> _getResolvers() => AnnotationAwareOrderComparator.getOrderedItems(_rateLimitResolvers);

  @override
  FutureOr<Iterable<RateLimitStorage>> resolveStorages(RateLimit rateLimit) async {
    final storages = <String, RateLimitStorage>{};

    for (final resolver in _getResolvers()) {
      try {
        final resolved = await resolver.resolveStorages(rateLimit);
        storages.addAll(resolved.toMap((store) => store.getName(), (store) => store));
      } catch (e) {
        continue;
      }
    }

    final storageNames = rateLimit.storageNames;

    for (final name in storageNames) {
      final managedStorage = await _rateLimitManager.getStorage(name);
      if (managedStorage != null) {
        storages[managedStorage.getName()] = managedStorage;
      }
    }

    return storages.values;
  }
}