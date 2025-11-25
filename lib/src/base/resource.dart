import 'when_matching.dart';

/// {@template resource}
/// Represents the contract for any JetLeaf-backed storage mechanism.
///
/// The [Resource] interface defines the minimal abstraction for all
/// cache-like, map-like, or rate-limit storage mechanisms within JetLeaf.
/// It allows the framework to uniformly reference various in-memory or
/// external resources, regardless of their concrete storage implementation.
///
/// Implementations of [Resource] are expected to be:
/// - Deterministic and consistent across concurrent access.
/// - Serializable or representable for diagnostics and management.
/// - Accessible through higher-level abstractions such as
///   [CacheManager], [RateLimitManager], or configuration pods.
///
/// ### Typical Implementations
///
/// | Implementation | Purpose |
/// |----------------|----------|
/// | [CacheResource] | Backing store for in-memory cache maps |
/// | [RateLimitResource] | In-memory rate limiting store |
/// | PersistentCacheResource | Disk-based or database-backed cache layer |
///
/// ### Example
///
/// ```dart
/// class InMemoryUserResource implements Resource {
///   final Map<String, User> _users = {};
///
///   void addUser(User user) => _users[user.id] = user;
///   User? getUser(String id) => _users[id];
/// }
///
/// final resource = InMemoryUserResource();
/// resource.addUser(User('123', 'Alice'));
/// print(resource.getUser('123')?.name); // → Alice
/// ```
///
/// ### Design Notes
///
/// The [Resource] abstraction separates *data representation* from
/// *management behavior*, enabling JetLeaf’s dependency and caching
/// systems to interoperate across heterogeneous data sources.
///
/// ### Related Interfaces
///
/// - [CacheStorage] – Defines operations for cache-level storage.
/// - [RateLimitStorage] – Defines storage behavior for rate limiting.
/// - [CacheManager] – Consumes [Resource] instances to coordinate caches.
/// - [ConfigurableListablePodFactory] – May inject or manage resources.
/// {@endtemplate}
abstract interface class Resource {
  /// Checks whether a value associated with the given [key] exists in the storage.
  ///
  /// This method provides a minimal, atomic existence check for any
  /// storage implementation, allowing higher-level components like
  /// cache managers or rate-limit managers to quickly verify presence
  /// without retrieving the actual value.
  ///
  /// ### Parameters
  /// - [key]: The identifier for the resource entry being checked.
  ///
  /// ### Returns
  /// - `true` if the key exists in the storage.
  /// - `false` if the key is absent.
  ///
  /// ### Example
  /// ```dart
  /// if (resource.exists('user:123')) {
  ///   print('User is cached.');
  /// }
  /// ```
  bool exists(Object key);

  /// Determines whether the resource entry identified by [key] satisfies
  /// the specified [match] condition.
  ///
  /// This allows dynamic, conditional evaluation of keys, supporting
  /// runtime rules such as environment-based toggles, parameter-based
  /// conditions, or pattern matching.
  ///
  /// ### Parameters
  /// - [match]: The type of comparison to perform (see [WhenMatching]).
  /// - [key]: The resource key to evaluate against the condition.
  ///
  /// ### Returns
  /// - `true` if the key satisfies the condition.
  /// - `false` otherwise.
  ///
  /// ### Example
  /// ```dart
  /// if (resource.matches(WhenMatching.EXISTS, 'session:token')) {
  ///   print('Session token exists.');
  /// }
  /// ```
  bool matches(WhenMatching match, Object key);
}