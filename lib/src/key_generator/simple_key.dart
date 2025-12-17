import 'package:jetleaf_lang/lang.dart';

/// {@template jet_cache_simple_key}
/// A lightweight, immutable representation of a method invocation key.
///
/// The [SimpleKey] class serves as the **default composite cache key** used by
/// JetLeaf’s caching infrastructure. It provides a deterministic, equality-
/// comparable key representation suitable for use in cache lookups, especially
/// when multiple method arguments need to be combined.
///
/// ### Design Overview
/// - Each instance wraps an optional [MethodArgument], which holds both
///   positional and named parameters passed to a method.
/// - The class implements equality and hashing via the `EqualsAndHashCode` mixin,
///   ensuring that two `SimpleKey` instances representing identical method
///   invocations are considered equal.
/// - When no arguments are present, the static singleton [SimpleKey.EMPTY]
///   is used to represent the canonical “empty” key.
///
/// ### Example
/// ```dart
/// final key1 = SimpleKey();                 // Equivalent to SimpleKey.EMPTY
/// final key2 = SimpleKey(MethodArgument([42], {}));
/// final key3 = SimpleKey(MethodArgument([42, 'foo'], {'flag': true}));
///
/// print(key1 == SimpleKey.EMPTY); // true
///
/// // Equality is based on the wrapped MethodArgument
/// final key4 = SimpleKey(MethodArgument([42], {}));
/// print(key2 == key4); // true
/// ```
///
/// ### Equality and Hashing
/// The equality comparison includes:
/// - The [MethodArgument] (if present)
/// - The [runtimeType] (for cross-type safety)
///
/// This ensures that subclasses or extended variants of `SimpleKey` do not
/// collide in hash-based collections (e.g., maps or sets).
///
/// ### Usage
/// `SimpleKey` is primarily used by [DefaultKeyGenerator] and custom cache
/// implementations that require a consistent composite key mechanism.
///
/// ### Thread Safety
/// - `SimpleKey` is immutable and therefore **thread-safe**.
/// - The [SimpleKey.EMPTY] instance can be safely reused across threads.
///
/// ### See Also
/// - [DefaultKeyGenerator]
/// - [KeyGenerator]
/// - [Cacheable]
/// - [MethodArgument]
/// {@endtemplate}
final class SimpleKey with EqualsAndHashCode {
  /// An empty, canonical [SimpleKey] instance representing no parameters.
  static final SimpleKey EMPTY = SimpleKey();

  /// The method argument associated with this key, or `null` if empty.
  final ExecutableArgument? _argument;

  /// {@macro jet_cache_simple_key}
  const SimpleKey([this._argument]);

  @override
  List<Object?> equalizedProperties() => _argument != null ? [_argument, runtimeType] : [runtimeType];

  @override
  String toString() {
    if (_argument == null) {
      return "SimpleKey";
    }

    final builder = StringBuilder();
    List<Object?> positional = _argument.getPositionalArguments();
    Map<String, Object?> named = _argument.getNamedArguments();

    builder.append("SimpleKey(");

    // Write positional arguments
    if (positional.isNotEmpty) {
      builder.append(positional.map((e) => e.toString()).join(", "));
    }

    // Add comma if both positional and named exist
    if (positional.isNotEmpty && named.isNotEmpty) {
      builder.append(", ");
    }

    // Write named arguments
    if (named.isNotEmpty) {
      builder.append(named.entries.map((e) => "${e.key}: ${e.value}").join(", "));
    }

    builder.append(")");

    return builder.toString();
  }
}