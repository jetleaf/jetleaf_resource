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

/// JetLeaf Cache Library
///
/// Provides declarative caching infrastructure for JetLeaf,
/// including annotations, configuration, and storage implementations.
///
/// This module enables fine-grained cache control and customization
/// through components like:
///
/// - `annotations.dart` → cache-related annotations (e.g. `@Cacheable`, `@CachePut`)  
/// - `cache.dart` → cache interfaces and operations  
/// - `cache_component_registrar.dart` → auto-registers cache components  
/// - `cache_configuration.dart` → default cache configuration setup  
/// - `concurrent_map_cache_storage.dart` → thread-safe in-memory cache storage  
/// - `cache_error_handler.dart` → handles cache-related errors gracefully  
/// - `simple_cache_manager.dart` → lightweight cache manager implementation  
/// - `simple_cache_resolver.dart` → default resolver for cache lookups  
///
/// Typically imported as:
/// ```dart
/// import 'package:jetleaf_resource/cache.dart';
/// ```
library;

export 'src/cache/annotations.dart';
export 'src/cache/cache.dart';
export 'src/cache/cache_component_registrar.dart';
export 'src/cache/cache_configuration.dart';
export 'src/cache/concurrent_map_cache_storage.dart';
export 'src/cache/cache_error_handler.dart';
export 'src/cache/simple_cache_manager.dart';
export 'src/cache/simple_cache_resolver.dart';