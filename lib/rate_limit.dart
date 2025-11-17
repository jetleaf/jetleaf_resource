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

/// JetLeaf Rate Limit Library
///
/// Provides declarative and programmatic APIs for rate limiting
/// within JetLeaf applications.
///
/// Enables resource protection, quota control, and usage tracking
/// through configurable rate limit managers and resolvers.
///
/// Exported modules include:
///
/// - `annotations.dart` → rate limit annotations (e.g. `@RateLimited`)  
/// - `rate_limit.dart` → rate limit core interfaces and operations  
/// - `rate_limit_component_registrar.dart` → auto-registers rate limit components  
/// - `rate_limit_configuration.dart` → default rate limit configuration  
/// - `concurrent_map_rate_limit_storage.dart` → in-memory rate limit storage  
/// - `simple_rate_limit_manager.dart` → lightweight manager implementation  
/// - `simple_rate_limit_resolver.dart` → default resolver for rate limit lookups  
///
/// Typically imported as:
/// ```dart
/// import 'package:jetleaf_resource/rate_limit.dart';
/// ```
library;

export 'src/rate_limit/annotations.dart';
export 'src/rate_limit/rate_limit.dart';
export 'src/rate_limit/rate_limit_component_registrar.dart';
export 'src/rate_limit/rate_limit_configuration.dart';
export 'src/rate_limit/concurrent_map_rate_limit_storage.dart';
export 'src/rate_limit/simple_rate_limit_manager.dart';
export 'src/rate_limit/simple_rate_limit_resolver.dart';