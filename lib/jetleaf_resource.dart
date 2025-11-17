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

/// JetLeaf Resource Library
///
/// Provides unified resource management utilities for caching,
/// rate limiting, and key generation in JetLeaf applications.
/// 
/// This library serves as the entry point for resource-related
/// functionality, combining cache and rate limit modules with
/// supporting components such as:
/// 
/// - `conditions.dart` → declarative resource condition handling  
/// - `exceptions.dart` → resource-specific exception types  
/// - `resource.dart` → base resource interfaces  
/// - `key_generator/` → customizable cache key generation strategies  
/// - `resource_auto_configuration.dart` → automatic resource registration  
///
/// Exported modules:
/// - `cache.dart` — cache management API
/// - `rate_limit.dart` — rate limit management API
///
/// Typically imported as:
/// ```dart
/// import 'package:jetleaf_resource/jetleaf_resource.dart';
/// ```
library;

export 'src/conditions.dart';
export 'src/exceptions.dart';
export 'src/resource.dart';
export 'src/key_generator/composite_key_generator.dart';
export 'src/key_generator/simple_key_generator.dart';
export 'src/key_generator/key_generator.dart';
export 'src/resource_auto_configuration.dart';

export 'cache.dart';
export 'rate_limit.dart';