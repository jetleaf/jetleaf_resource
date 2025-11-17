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

import 'key_generator.dart';

/// {@template jet_simple_key_generator}
/// A lightweight [KeyGenerator] implementation that delegates directly to the
/// base key generation strategy defined in [KeyGenerator].
///
/// The [SimpleKeyGenerator] serves as the default or baseline implementation
/// used when no custom key generator pod is configured within the JetLeaf
/// caching infrastructure. It primarily relies on the superclass's logic
/// for producing cache keys based on method context and argument metadata.
///
/// ### Overview
///
/// In JetLeaf, a [KeyGenerator] is responsible for creating unique and
/// deterministic keys for cache operations annotated with [Cacheable],
/// [CachePut], or [CacheEvict]. This ensures consistent lookup behavior and
/// cache correctness.
///
/// The [SimpleKeyGenerator]:
/// - Uses JetLeaf’s default key composition rules (e.g., method name + arguments).
/// - Provides predictable and stable key generation for basic use cases.
/// - Can be replaced by a custom [KeyGenerator] pod for more advanced logic
///   (e.g., hashing, object serialization, composite keys).
///
/// ### Example
///
/// ```dart
/// final generator = SimpleKeyGenerator();
/// final key = generator.generate(
///   myService,
///   Class<MyService>().getMethod("findUserById"),
///   MethodArgument(['id': 42]),
/// );
///
/// print(key); // e.g., "findUserById:42"
/// ```
///
/// ### Extension Points
///
/// Developers may subclass [KeyGenerator] or register a custom implementation
/// as a pod if they require:
///
/// - Consistent key hashing (e.g., MD5, SHA256).
/// - Composite key building strategies.
/// - Conditional or namespaced key generation.
///
/// ### Related Components
///
/// - [KeyGenerator]: Base class defining key generation contract.
/// - [Cacheable], [CachePut], [CacheEvict]: Annotations that rely on key generation.
/// - [MethodArgument]: Represents invocation context used for key computation.
/// - [CompositeKeyGenerator]: Alternative implementation that combines multiple strategies.
///
/// {@endtemplate}
final class SimpleKeyGenerator extends KeyGenerator {
  /// {@macro jet_simple_key_generator}
  SimpleKeyGenerator();
}