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

/// 🗄️ **JetLeaf Caching Library**
///
/// This library provides a comprehensive caching system for JetLeaf applications,
/// including annotations, storage, eviction policies, operations, metrics, and
/// error handling.
///
/// It supports declarative caching with method interceptors, programmatic cache
/// management, and extensible backends.
///
///
/// ## 🔑 Key Concepts
///
/// - **Cache Operations**: define actions like `put`, `evict`, `expire`, and `cacheable`.
/// - **Cache Storage**: backends for storing cached data (in-memory, configurable stores, etc.).
/// - **Eviction Policies**: LRU, LFU, FIFO strategies for automatic cache pruning.
/// - **Error Handling**: robust handling of cache errors with pluggable handlers.
/// - **Events & Metrics**: observe cache activity and gather statistics.
///
///
/// ## 📦 Exports Overview
///
/// ### ⚙ Core
/// - `CacheAnnotationMethodInterceptor` — intercepts annotated methods for caching  
/// - `CacheComponentRegistrar` — registers cache components  
/// - `CacheOperationContext` / `DefaultCacheOperationContext` — runtime operation metadata
///
///
/// ### ⚠ Error Handlers
/// - `CacheErrorHandler` — base interface  
/// - `CacheErrorHandlerRegistry` — manages multiple handlers  
/// - `LoggableCacheErrorHandler` — logs errors instead of throwing  
/// - `ThrowableCacheErrorHandler` — propagates exceptions
///
///
/// ### 🏷 Events
/// - `CacheEvent` — base class  
/// - `CacheHitEvent`, `CacheMissEvent`, `CachePutEvent`, `CacheEvictEvent`, `CacheExpireEvent`, `CacheClearEvent`  
/// Allows observing cache lifecycle activities.
///
///
/// ### 🗑 Eviction Policies
/// - `CacheEvictionPolicy` — base interface  
/// - `FifoEvictionPolicy`, `LfuEvictionPolicy`, `LruEvictionPolicy`
///
///
/// ### 🏗 Managers
/// - `CacheManager` — primary cache orchestrator  
/// - `CacheManagerRegistry` — registry for multiple managers  
/// - `SimpleCacheManager` — default implementation
///
///
/// ### 📊 Metrics
/// - `CacheMetrics` — metrics collection interface  
/// - `SimpleCacheMetrics` — basic implementation for monitoring
///
///
/// ### 💾 Cache Operations
/// - `CacheOperation` — base interface for all operations  
/// - `CachePutOperation`, `CacheEvictOperation`, `CacheableOperation`
///
///
/// ### 🔍 Resolver
/// - `CacheResolver` — resolves cache targets dynamically  
/// - `CacheResolverRegistry` — manages multiple resolvers  
/// - `SimpleCacheResolver` — default implementation
///
///
/// ### 🗄 Storage
/// - `CacheStorage` — interface for cache stores  
/// - `CacheStorageRegistry` — manage multiple stores  
/// - `Cache` / `DefaultCache` — standard cache abstraction  
/// - `ConfigurableCacheStorage` — customizable backends  
/// - `CacheResource` — resource abstraction  
/// - `DefaultCacheStorage` — default in-memory storage
///
///
/// ### 📝 Annotations & Config
/// - `annotations.dart` — declarative caching via method-level annotations  
/// - `CacheConfigurer` — programmatic configuration of caches
///
///
/// ## 🎯 Intended Usage
///
/// Import this library to enable full caching capabilities in JetLeaf:
/// ```dart
/// import 'package:jetleaf_resource/cache.dart';
///
/// @Cacheable('myCache')
/// String fetchData(String key) {
///   return computeData(key);
/// }
/// ```
///
/// Supports pluggable storage, metrics, events, and error handling.
///
///
/// © 2025 Hapnium & JetLeaf Contributors
library;

export 'src/cache/core/cache_annotation_method_interceptor.dart';
export 'src/cache/core/cache_component_registrar.dart';
export 'src/cache/core/cache_operation_context.dart';
export 'src/cache/core/default_cache_operation_context.dart';

export 'src/cache/error_handler/cache_error_handler.dart';
export 'src/cache/error_handler/cache_error_handler_registry.dart';
export 'src/cache/error_handler/loggable_cache_error_handler.dart';
export 'src/cache/error_handler/throwable_cache_error_handler.dart';

export 'src/cache/event/cache_clear_event.dart';
export 'src/cache/event/cache_event.dart';
export 'src/cache/event/cache_evict_event.dart';
export 'src/cache/event/cache_expire_event.dart';
export 'src/cache/event/cache_hit_event.dart';
export 'src/cache/event/cache_miss_event.dart';
export 'src/cache/event/cache_put_event.dart';

export 'src/cache/eviction_policy/cache_eviction_policy.dart';
export 'src/cache/eviction_policy/fifo_eviction_policy.dart';
export 'src/cache/eviction_policy/lfu_eviction_policy.dart';
export 'src/cache/eviction_policy/lru_eviction_policy.dart';

export 'src/cache/manager/cache_manager.dart';
export 'src/cache/manager/cache_manager_registry.dart';
export 'src/cache/manager/simple_cache_manager.dart';

export 'src/cache/metrics/cache_metrics.dart';
export 'src/cache/metrics/simple_cache_metrics.dart';

export 'src/cache/operation/cache_evict_operation.dart';
export 'src/cache/operation/cache_operation.dart';
export 'src/cache/operation/cache_put_operation.dart';
export 'src/cache/operation/cacheable_operation.dart';

export 'src/cache/resolver/cache_resolver.dart';
export 'src/cache/resolver/cache_resolver_registry.dart';
export 'src/cache/resolver/simple_cache_resolver.dart';

export 'src/cache/storage/cache.dart';
export 'src/cache/storage/cache_resource.dart';
export 'src/cache/storage/cache_storage.dart';
export 'src/cache/storage/cache_storage_registry.dart';
export 'src/cache/storage/configurable_cache_storage.dart';
export 'src/cache/storage/default_cache.dart';
export 'src/cache/storage/default_cache_storage.dart';

export 'src/cache/annotations.dart';
export 'src/cache/cache_configurer.dart';