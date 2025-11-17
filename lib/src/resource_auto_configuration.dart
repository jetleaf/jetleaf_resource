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
import 'package:meta/meta_meta.dart';

import '../rate_limit.dart';
import 'cache/cache_configuration.dart';
import 'key_generator/composite_key_generator.dart';
import 'key_generator/key_generator.dart';
import 'key_generator/simple_key_generator.dart';

/// {@template jet_resource_auto_configuration}
/// Auto-configuration entry point for JetLeaf **resource and key generation infrastructure**.
///
/// The [ResourceAutoConfiguration] defines the default [KeyGenerator]
/// pods used by the JetLeaf resource and caching subsystems.  
/// This configuration is automatically loaded during application startup
/// when resource caching or annotation-driven caching is enabled.
///
/// ### Overview
///
/// This configuration provides automatic registration of key generator
/// implementations depending on the active environment or configuration
/// properties.  
/// It uses JetLeaf’s conditional pod resolution annotations such as
/// [ConditionalOnMissingPod] and [ConditionalOnProperty] to determine
/// which generator is instantiated.
///
/// ### Provided Pods
///
/// | Pod | Description | Condition |
/// | --- | ------------ | ---------- |
/// | [SimpleKeyGenerator] | Default key generator producing keys based on method and argument metadata | When `jetleaf.resource.key-generator=default` |
/// | [CompositeKeyGenerator] | Composes multiple [KeyGenerator]s into a chain for advanced resolution | When `jetleaf.resource.key-generator=composite` or missing |
///
/// ### Related Components
/// - [KeyGenerator]
/// - [SimpleKeyGenerator]
/// - [CompositeKeyGenerator]
/// - [CacheConfiguration]
///
/// ### Example
/// ```dart
/// @AutoConfiguration()
/// final class ResourceAutoConfiguration {
///   @Pod()
///   KeyGenerator keyGenerator() => SimpleKeyGenerator();
/// }
/// ```
///
/// {@endtemplate}
@AutoConfiguration()
@Named(ResourceAutoConfiguration.RESOURCE_AUTO_CONFIGURATION_POD_NAME)
final class ResourceAutoConfiguration {
  /// {@macro jet_resource_auto_configuration}
  ResourceAutoConfiguration();

  /// Pod name for the **ResourceAutoConfiguration** module.
  ///
  /// Responsible for initializing and wiring Jetleaf's resource-level
  /// components (rate limiting, caching, etc.) during startup.
  static const String RESOURCE_AUTO_CONFIGURATION_POD_NAME = "jetleaf.resource.resourceAutoConfiguration";

  /// Pod name for the **SimpleKeyGenerator**.
  ///
  /// Provides default key generation logic used in caching and rate-limiting
  /// operations when no custom key generator is defined.
  static const String KEY_GENERATOR_POD_NAME = "jetleaf.resource.simpleKeyGenerator";

  /// Pod name for the **CompositeKeyGenerator**.
  ///
  /// Used when multiple parameters or metadata values must be combined into
  /// a single unique cache or rate-limit key.
  static const String COMPOSITE_KEY_GENERATOR_POD_NAME = "jetleaf.resource.compositeKeyGenerator";

  // ---------------------------------------------------------------------------
  // Pod Definitions
  // ---------------------------------------------------------------------------

  /// Registers the [SimpleKeyGenerator] as the active [KeyGenerator] when
  /// no custom generator is present and the configuration property
  /// `jetleaf.resource.key-generator` is set to `"default"`.
  ///
  /// This generator produces deterministic keys based on the target
  /// object, invoked method, and method arguments.
  @Pod(value: KEY_GENERATOR_POD_NAME)
  @ConditionalOnMissingPod(values: [ClassType<KeyGenerator>()])
  @ConditionalOnProperty(prefix: "jetleaf", names: ['resource.key-generator'], havingValue: "default")
  KeyGenerator simpleKeyGenerator() => SimpleKeyGenerator();

  /// Registers the [CompositeKeyGenerator] as the active [KeyGenerator]
  /// when the configuration property `jetleaf.resource.key-generator`
  /// is set to `"composite"` or is missing.
  ///
  /// The composite generator coordinates multiple registered
  /// [KeyGenerator]s (including conditional generators) into a
  /// deterministic chain, ensuring flexible and extensible key
  /// resolution.
  @Pod(value: COMPOSITE_KEY_GENERATOR_POD_NAME)
  @ConditionalOnMissingPod(values: [ClassType<KeyGenerator>()])
  @ConditionalOnProperty(prefix: "jetleaf", names: ['resource.key-generator'], havingValue: "composite", matchIfMissing: true)
  KeyGenerator compositeKeyGenerator() => CompositeKeyGenerator();
}

/// {@template jet_enable_resource}
/// Annotation used to **enable JetLeaf resource and caching infrastructure**
/// within an application context.
///
/// When applied to a JetLeaf application entry point or configuration class,
/// this annotation automatically imports and activates both the
/// [ResourceAutoConfiguration] and [CacheConfiguration] modules, wiring up
/// all default pods related to resource management, key generation,
/// and cache lifecycle handling.
///
/// ### Overview
///
/// Applying `@EnableResource` ensures that the following subsystems are
/// initialized:
///
/// - JetLeaf **ResourceAutoConfiguration** → provides key generator pods  
///   (e.g., [SimpleKeyGenerator], [CompositeKeyGenerator])  
/// - JetLeaf **CacheConfiguration** → provides default caching components  
///   (e.g., [CacheManager], [CacheResolver], [CacheStorage])
///
/// ### Example
///
/// ```dart
/// @EnableResource()
/// final class MyApplication {
/// }
/// ```
///
/// ### Related Components
/// - [ResourceAutoConfiguration]
/// - [CacheConfiguration]
/// - [SimpleKeyGenerator]
/// - [CompositeKeyGenerator]
///
/// {@endtemplate}
@Target({TargetKind.classType})
@Import([
  ClassType<ResourceAutoConfiguration>(),
  ClassType<CacheConfiguration>(),
  ClassType<RateLimitConfiguration>()
])
final class EnableResource extends ReflectableAnnotation {
  /// {@macro jet_enable_resource}
  const EnableResource();

  /// Returns the type of this annotation.
  ///
  /// Used by JetLeaf’s reflection system to identify and process
  /// `@EnableResource` during application bootstrapping.
  @override
  Type get annotationType => EnableResource;
}