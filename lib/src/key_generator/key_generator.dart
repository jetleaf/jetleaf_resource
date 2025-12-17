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

import 'package:jetleaf_lang/lang.dart';

/// {@template jetleaf_key_generator}
/// ## KeyGenerator — Strategy for Cache Key Generation
///
/// The [KeyGenerator] defines a strategy for producing unique, stable, and
/// deterministic keys that represent specific method invocations.  
/// These keys serve as identifiers for cache lookups, insertions, and evictions.
///
/// ### 🔍 Purpose
/// In any caching mechanism, a **key** determines how cached entries are stored
/// and retrieved. The role of [KeyGenerator] is to translate a method invocation
/// — including its target object, the reflective [Method] representation, and
/// the runtime [MethodArgument] values — into a single canonical key object.
///
/// This abstraction allows for flexible strategies:
/// - Default keying behavior for simple cases
/// - Domain-specific key formats (e.g., string concatenation, hashing, encoding)
/// - Integration with frameworks that require consistent key generation semantics
///
/// ### ⚙️ Default Behavior
/// The base implementation provides a deterministic fallback strategy:
///
/// | Case | Condition | Resulting Key |
/// |------|------------|---------------|
/// | 1 | No arguments | [_SimpleKey.EMPTY] |
/// | 2 | Single argument (named or positional) | The single argument itself |
/// | 3 | Multiple arguments | A [_SimpleKey] composite containing all arguments |
///
/// ```dart
/// // Example usage:
/// final keyGen = DefaultKeyGenerator();
///
/// // Produces _SimpleKey.EMPTY
/// final key1 = keyGen.generate(target, method, MethodArgument.empty());
///
/// // Produces direct argument as key
/// final key2 = keyGen.generate(target, method, MethodArgument.positional(['user123']));
///
/// // Produces composite _SimpleKey
/// final key3 = keyGen.generate(target, method, MethodArgument.positional(['user123', 42]));
/// ```
///
/// ### 🧩 Extension and Customization
/// Developers can subclass [KeyGenerator] to override [generate] and implement
/// custom strategies. This is common when integrating with:
///
/// - Domain identifiers (e.g., user IDs, tenant IDs)
/// - Cryptographic hashes or canonical string keys
/// - JSON-serializable key forms for distributed caching
///
/// Example:
/// ```dart
/// final class JsonKeyGenerator extends KeyGenerator {
///   @override
///   Object generate(Object target, Method method, MethodArgument? argument) {
///     final args = argument?.toJson() ?? {};
///     return jsonEncode({'method': method.getName(), 'args': args});
///   }
/// }
/// ```
///
/// ### 📜 Contract and Design Rules
/// To ensure cache consistency and correctness:
///
/// 1. **Determinism:** The same inputs must always produce the same key.
/// 2. **Equality:** Generated keys must properly implement `==` and `hashCode`.
/// 3. **Non-null guarantee:** The generator must never return `null`.
/// 4. **Performance:** Key generation should be lightweight — no expensive I/O or computation.
/// 5. **Stability:** The key format should remain stable across library versions.
///
/// ### 🚫 Common Pitfalls
/// - Returning mutable key objects that change after insertion
/// - Using `toString()` for complex objects without ensuring stability
/// - Ignoring named arguments in favor of positional-only logic
///
/// ### 🔗 Related Components
/// - [SimpleKey] — Default composite key type used for multi-argument invocations.
/// - [ConditionalKeyGenerator] — Extended form that decides applicability dynamically.
/// - [Cacheable], [CachePut], [CacheEvict] — Annotations that rely on key generation
///   for cache operation resolution.
/// {@endtemplate}
///
/// {@macro jetleaf_key_generator}
abstract interface class KeyGenerator with EqualsAndHashCode {
  /// Generates a unique and deterministic cache key for the given
  /// method invocation.
  ///
  /// The returned key identifies a specific execution of the [method]
  /// on the [target] instance with the supplied [argument] values.
  /// Implementations must ensure that logically equivalent invocations
  /// yield equal keys.
  ///
  /// **Parameters:**
  /// - [target] — The object instance on which the method is invoked.
  /// - [method] — The reflective representation of the invoked method.
  /// - [argument] — The runtime arguments of the method call (may be `null`).
  Object generate(Object target, Method method, ExecutableArgument? argument);
}

/// {@template jetleaf_conditional_key_generator}
/// A specialized [KeyGenerator] that can conditionally participate in key generation
/// based on runtime or reflective characteristics of a method invocation.
///
/// This interface extends [KeyGenerator] by introducing an additional capability:
/// the ability to determine whether it **can** generate a cache key for a specific
/// target and method before actually performing the generation.
///
/// ### Purpose
/// [ConditionalKeyGenerator] allows the JetLeaf caching system to support multiple
/// coexisting key generators in a flexible and extensible way. This is particularly
/// useful when:
/// - Different generators are responsible for different annotations or method types.
/// - Generators should only apply to certain classes, packages, or naming conventions.
/// - Custom logic is required to decide which key generator to use at runtime.
///
/// ### Method Overview
/// - [canGenerate] — Determines if this generator should handle the given method
///   and target object.
/// - [generate] — Performs actual key generation when applicable.
///
/// ### Example
/// ```dart
/// final class RepositoryKeyGenerator implements ConditionalKeyGenerator {
///   const RepositoryKeyGenerator();
///
///   @override
///   bool canGenerate(Method method, Object target) {
///     // Only handle repository classes or methods annotated with @RepositoryCache
///     return target.runtimeType.toString().endsWith('Repository') ||
///            method.hasAnnotation<RepositoryCache>();
///   }
///
///   @override
///   Object generate(Object target, Method method, MethodArgument argument) {
///     final argsHash = argument.values.join('-');
///     return '${target.runtimeType}.${method.name}:$argsHash';
///   }
/// }
/// ```
///
/// ### Use Case
/// In complex caching configurations, JetLeaf may maintain a **chain** or **registry**
/// of available [ConditionalKeyGenerator]s. The caching infrastructure queries each
/// generator in sequence via [canGenerate] until one affirms it can handle the method.
///
/// ### Performance Note
/// Since [canGenerate] may be invoked frequently, it should be efficient and avoid
/// heavy reflection or I/O operations.
///
/// ### Extensibility
/// Custom frameworks or library extensions can register multiple conditional
/// generators to enable fine-grained, context-aware key generation behavior.
///
/// ### See Also
/// - [KeyGenerator]
/// - [Cacheable]
/// - [CachePut]
/// - [CacheEvict]
/// - [CacheOperationContext]
/// {@endtemplate}
abstract class ConditionalKeyGenerator extends KeyGenerator {
  /// Determines whether this key generator can handle the given [method]
  /// for the specified [target].
  ///
  /// Returning `true` indicates that this generator is applicable for
  /// key generation; otherwise, the caching framework may delegate to
  /// another registered [KeyGenerator].
  ///
  /// @param method The reflective representation of the method being invoked.
  /// @param target The target instance on which the method is invoked.
  /// @return Whether this generator can produce a key for the given invocation.
  bool canGenerate(Method method, Object target);
}

/// {@template jet_cache_key_generator_registry}
/// Central registry interface for managing [KeyGenerator] pods within the
/// JetLeaf caching subsystem.
///
/// A [KeyGeneratorRegistry] defines the contract for registering one or
/// more [KeyGenerator] implementations responsible for producing cache keys
/// from annotated method invocations (e.g., those using [Cacheable],
/// [CachePut], or [CacheEvict]).
///
/// ### Overview
///
/// In JetLeaf, a [KeyGenerator] converts method invocation data—such as the
/// target instance, [Method] reference, and [MethodArgument] metadata—into a
/// unique, reproducible key suitable for cache lookup or mutation.
///
/// The registry allows multiple generators to coexist within the same
/// application context. Composite or chained resolvers (like
/// [CompositeKeyGenerator]) can use this registry to determine the active
/// generator at runtime, typically based on cache annotations or contextual
/// hints.
///
/// ### Responsibilities
///
/// - Maintain a collection of registered [KeyGenerator] pods.
/// - Provide an extension point for frameworks and modules to contribute
///   custom key generators.
/// - Ensure consistent and deterministic key generation across cache
///   operations.
///
/// ### Example
///
/// ```dart
/// final registry = DefaultCacheKeyGeneratorRegistry();
/// registry.addKeyGenerator(SimpleKeyGenerator());
/// registry.addKeyGenerator(ExpressionKeyGenerator());
/// ```
///
/// In this setup, the registry holds multiple key generators that can be
/// selected dynamically during cache resolution.
///
/// ### Related Components
///
/// - [KeyGenerator]: Core interface defining cache key generation behavior.
/// - [Cacheable], [CachePut], [CacheEvict]: Annotations relying on key
///   generation.
/// - [CompositeKeyGenerator]: Example of a composite strategy using this
///   registry.
/// - [CacheManagerRegistry], [CacheResolverRegistry]: Complementary registries
///   within the JetLeaf caching infrastructure.
///
/// {@endtemplate}
abstract interface class KeyGeneratorRegistry {
  /// Registers a [KeyGenerator] responsible for producing cache keys from
  /// annotated method invocations.
  ///
  /// Multiple [KeyGenerator] instances can be added, enabling chained or
  /// context-aware resolution strategies.
  ///
  /// Example:
  /// ```dart
  /// registry.addKeyGenerator(SimpleKeyGenerator());
  /// registry.addKeyGenerator(ExpressionKeyGenerator());
  /// ```
  void addKeyGenerator(KeyGenerator keyGenerator);
}