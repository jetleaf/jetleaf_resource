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

/// 🔑 **JetLeaf Resource Library**
///
/// This library provides a set of core utilities and configuration abstractions
/// for JetLeaf resource applications, including key generation, resource management,
/// conditional execution, and prebuilt configuration for caching and
/// rate-limiting.
///
/// It also re-exports the main `cache` and `rate_limit` modules for
/// convenient access to those subsystems.
///
///
/// ## 🔑 Key Concepts
///
/// ### 🗝 Key Generation
/// Provides abstractions for generating unique keys for caching or
/// resource identification:
/// - `KeyGenerator` — interface for key generation strategies  
/// - `SimpleKeyGenerator` — default implementation for basic scenarios  
/// - `CompositeKeyGenerator` — combines multiple key parts into a single key
///
///
/// ### ⚙ Configuration
/// Provides auto-configuration support for JetLeaf subsystems:
/// - `ResourceAutoConfiguration` — automatically configures resources  
/// - `CacheConfiguration` — predefined cache setup  
/// - `RateLimitConfiguration` — predefined rate-limit setup
///
///
/// ### 🧱 Base Utilities
/// Core framework helpers:
/// - `conditions.dart` — declarative condition utilities  
/// - `exceptions.dart` — base exception types  
/// - `operation_context.dart` — context for executing operations  
/// - `resource.dart` — abstraction for managed resources  
/// - `when_matching.dart` — pattern-based conditional execution
///
///
/// ### 🛠 Utilities
/// - `resource_utils.dart` — helper functions for working with resources
///
///
/// ### 📦 Subsystem Re-exports
/// - `cache.dart` — complete JetLeaf caching system  
/// - `rate_limit.dart` — complete JetLeaf rate-limiting system
///
///
/// ## 🎯 Intended Usage
///
/// Import this library to leverage key generation, conditional execution,
/// resource management, and pre-configured caching and rate-limiting:
/// ```dart
/// import 'package:jetleaf_resource/jetleaf_resource.dart';
///
/// final key = SimpleKeyGenerator().generate('user', 42);
/// ```
///
/// Combines both utility and configuration entry points for convenient access.
///
///
/// © 2025 Hapnium & JetLeaf Contributors
library;

export 'src/key_generator/composite_key_generator.dart';
export 'src/key_generator/simple_key_generator.dart';
export 'src/key_generator/key_generator.dart';

export 'src/config/resource_auto_configuration.dart';
export 'src/config/cache_configuration.dart';
export 'src/config/rate_limit_configuration.dart';

export 'src/base/conditions.dart';
export 'src/base/exceptions.dart';
export 'src/base/operation_context.dart';
export 'src/base/resource.dart';
export 'src/base/when_matching.dart';

export 'src/util/resource_utils.dart';

export 'cache.dart';
export 'rate_limit.dart';