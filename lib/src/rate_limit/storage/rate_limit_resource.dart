import 'package:jetleaf_core/core.dart';
import 'package:jetleaf_lang/lang.dart';

import 'rate_limit_entry.dart';

/// {@template rate_limit_resource}
/// A thread-safe in-memory resource for storing rate limit entries.
///
/// This implementation uses a `HashMap<Object, RateLimitEntry>` as the underlying
/// storage mechanism. Each key represents a unique identifier (e.g., user ID, API key),
/// and each value is a [RateLimitEntry] that tracks usage counts, timestamps,
/// and reset information.
///
/// This class implements [Resource], making it compatible with JetLeaf's
/// resource and pod management system.
///
/// ### Behavior
///
/// - Stores and retrieves [RateLimitEntry] instances in memory.
/// - Keys are arbitrary objects but typically strings or integers.
/// - Designed for fast, concurrent access within a single application instance.
/// - Not distributed; for clustered environments, a distributed rate limit storage
///   should be used instead.
///
/// ### Example
///
/// ```dart
/// final storage = ConcurrentMapRateLimitResource();
/// storage['user:123'] = RateLimitEntryImpl();
/// final entry = storage['user:123'];
/// ```
///
/// ### Related Components
///
/// - [RateLimitEntry]: Represents individual rate limit data for a key.
/// - [Resource]: Base interface for JetLeaf resources.
/// {@endtemplate}
final class RateLimitResource extends HashMap<Object, RateLimitEntry> implements Resource<Object, RateLimitEntry> {
  /// {@macro rate_limit_resource}
  RateLimitResource();

  @override
  bool exists(Object key) => this[key] != null;

  @override
  RateLimitEntry? get(Object key) => this[key];
}