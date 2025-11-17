# 💾 JetLeaf Resource — Caching & Rate Limiting

[![pub package](https://img.shields.io/badge/version-1.0.0-blue)](https://pub.dev/packages/jetleaf_resource)
[![License](https://img.shields.io/badge/license-JetLeaf-green)](#license)
[![Dart SDK](https://img.shields.io/badge/sdk-%3E%3D3.9.0-blue)](https://dart.dev)

Unified resource management utilities for caching, rate limiting, and key generation in JetLeaf applications with declarative conditions and automatic pod integration.

## 📋 Overview

`jetleaf_resource` provides resource management features:

- **Caching** — In-memory cache with TTL and automatic expiration
- **Rate Limiting** — Request throttling with multiple strategies
- **Key Generators** — Customizable cache key generation
- **Conditions** — Declarative cache/rate-limit conditions
- **Pod Integration** — Automatic resource registration as pods
- **Performance** — Improved response times and reduced load

## 🚀 Quick Start

### Installation

```yaml
dependencies:
  jetleaf_resource:
    path: ./jetleaf_resource
```

### Basic Caching

```dart
import 'package:jetleaf_resource/jetleaf_resource.dart';

class UserService {
  final Map<String, User> _cache = {};

  Future<User> getUser(String id) async {
    // Check cache first
    if (_cache.containsKey(id)) {
      print('Cache hit for user $id');
      return _cache[id]!;
    }

    // Fetch from database
    print('Fetching user $id from database');
    final user = await _fetchFromDatabase(id);
    
    // Store in cache
    _cache[id] = user;
    return user;
  }

  Future<User> _fetchFromDatabase(String id) async {
    // Simulate database call
    await Future.delayed(Duration(milliseconds: 100));
    return User(id: id, name: 'User $id');
  }
}

class User {
  final String id;
  final String name;
  User({required this.id, required this.name});
}

void main() async {
  final service = UserService();
  
  // First call: fetches from database
  var user = await service.getUser('123');
  print('User: ${user.name}');
  
  // Second call: from cache
  user = await service.getUser('123');
  print('User: ${user.name}');
}
```

### Basic Rate Limiting

```dart
import 'package:jetleaf_resource/jetleaf_resource.dart';

class ApiLimiter {
  int _requestCount = 0;
  DateTime _windowStart = DateTime.now();
  final int _maxRequests = 10;
  final Duration _windowDuration = Duration(minutes: 1);

  bool canMakeRequest() {
    final now = DateTime.now();
    
    // Reset window if expired
    if (now.difference(_windowStart) > _windowDuration) {
      _requestCount = 0;
      _windowStart = now;
    }

    if (_requestCount < _maxRequests) {
      _requestCount++;
      return true;
    }

    return false;
  }
}

void main() {
  final limiter = ApiLimiter();

  for (int i = 0; i < 15; i++) {
    if (limiter.canMakeRequest()) {
      print('Request $i allowed');
    } else {
      print('Request $i blocked (rate limit exceeded)');
    }
  }
}
```

## 📚 Key Features

### 1. Cache Management

**Flexible in-memory caching**:

```dart
import 'package:jetleaf_resource/jetleaf_resource.dart';

class CacheExample {
  final Map<String, CacheEntry> _cache = {};

  void set<T>(String key, T value, {Duration? ttl}) {
    _cache[key] = CacheEntry(
      value: value,
      expiresAt: ttl != null ? DateTime.now().add(ttl) : null,
    );
  }

  T? get<T>(String key) {
    final entry = _cache[key];
    
    // Check if expired
    if (entry != null && entry.expiresAt != null) {
      if (DateTime.now().isAfter(entry.expiresAt!)) {
        _cache.remove(key);
        return null;
      }
    }

    return entry?.value as T?;
  }

  void invalidate(String key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }

  int get size => _cache.length;
}

class CacheEntry {
  final Object? value;
  final DateTime? expiresAt;
  
  CacheEntry({required this.value, this.expiresAt});
}

void main() {
  final cache = CacheExample();

  // Set with 1 minute TTL
  cache.set('user:123', {'name': 'John'}, ttl: Duration(minutes: 1));
  
  // Get value
  var value = cache.get('user:123');
  print('Cached: $value');

  // Invalidate specific key
  cache.invalidate('user:123');
  value = cache.get('user:123');
  print('After invalidate: $value');
}
```

### 2. Cache Key Generation

**Customizable key generation strategies**:

```dart
import 'package:jetleaf_resource/jetleaf_resource.dart';

abstract class KeyGenerator {
  String generate(String prefix, List<dynamic> params);
}

class SimpleKeyGenerator implements KeyGenerator {
  @override
  String generate(String prefix, List<dynamic> params) {
    return '$prefix:${params.join(':')}';
  }
}

class CompositeKeyGenerator implements KeyGenerator {
  final String Function(dynamic value) converter;
  
  CompositeKeyGenerator({required this.converter});

  @override
  String generate(String prefix, List<dynamic> params) {
    final converted = params.map(converter).join(':');
    return '$prefix:$converted';
  }
}

void main() {
  final simpleGen = SimpleKeyGenerator();
  
  // Generate cache keys
  var key1 = simpleGen.generate('user', [123, 'profile']);
  print('Key: $key1');  // user:123:profile

  // Composite with custom converter
  final compositeGen = CompositeKeyGenerator(
    converter: (value) => value is User ? value.id : value.toString(),
  );

  final user = User(id: '456', name: 'Alice');
  var key2 = compositeGen.generate('user', [user, 'details']);
  print('Key: $key2');  // user:456:details
}

class User {
  final String id;
  final String name;
  User({required this.id, required this.name});
}
```

### 3. Rate Limiting Strategies

**Multiple rate limiting approaches**:

```dart
import 'package:jetleaf_resource/jetleaf_resource.dart';

// Fixed window counter
class FixedWindowLimiter {
  final int maxRequests;
  final Duration window;
  DateTime _windowStart = DateTime.now();
  int _count = 0;

  FixedWindowLimiter({required this.maxRequests, required this.window});

  bool allowRequest() {
    final now = DateTime.now();
    
    if (now.difference(_windowStart) > window) {
      _windowStart = now;
      _count = 0;
    }

    if (_count < maxRequests) {
      _count++;
      return true;
    }
    return false;
  }
}

// Token bucket algorithm
class TokenBucketLimiter {
  final double tokensPerSecond;
  double _tokens;
  DateTime _lastRefill;

  TokenBucketLimiter({required this.tokensPerSecond})
    : _tokens = tokensPerSecond,
      _lastRefill = DateTime.now();

  bool allowRequest({int tokensNeeded = 1}) {
    _refillTokens();
    
    if (_tokens >= tokensNeeded) {
      _tokens -= tokensNeeded;
      return true;
    }
    return false;
  }

  void _refillTokens() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefill).inMilliseconds / 1000.0;
    _tokens = (_tokens + elapsed * tokensPerSecond).clamp(0, tokensPerSecond);
    _lastRefill = now;
  }
}

void main() {
  // Fixed window: max 10 requests per minute
  final fwLimiter = FixedWindowLimiter(
    maxRequests: 10,
    window: Duration(minutes: 1),
  );

  // Token bucket: 5 requests per second
  final tbLimiter = TokenBucketLimiter(tokensPerSecond: 5);

  print('Fixed window test:');
  for (int i = 0; i < 12; i++) {
    print('Request $i: ${fwLimiter.allowRequest()}');
  }

  print('\nToken bucket test:');
  for (int i = 0; i < 7; i++) {
    print('Request $i: ${tbLimiter.allowRequest()}');
  }
}
```

### 4. Conditional Caching

**Cache only under specific conditions**:

```dart
import 'package:jetleaf_resource/jetleaf_resource.dart';

class ConditionalCache<T> {
  final Map<String, CacheEntry<T>> _cache = {};
  final bool Function(T value)? condition;

  ConditionalCache({this.condition});

  void set(String key, T value) {
    // Only cache if condition passes
    if (condition == null || condition!(value)) {
      _cache[key] = CacheEntry(
        value: value,
        createdAt: DateTime.now(),
      );
    }
  }

  T? get(String key) => _cache[key]?.value;

  void clear() => _cache.clear();
}

class CacheEntry<T> {
  final T value;
  final DateTime createdAt;
  
  CacheEntry({required this.value, required this.createdAt});
}

class User {
  final String id;
  final String name;
  final bool isActive;

  User({
    required this.id,
    required this.name,
    required this.isActive,
  });
}

void main() {
  // Only cache active users
  final userCache = ConditionalCache<User>(
    condition: (user) => user.isActive,
  );

  final activeUser = User(id: '1', name: 'Alice', isActive: true);
  final inactiveUser = User(id: '2', name: 'Bob', isActive: false);

  userCache.set('user:1', activeUser);
  userCache.set('user:2', inactiveUser);

  print('Active user cached: ${userCache.get('user:1') != null}');      // true
  print('Inactive user cached: ${userCache.get('user:2') != null}');    // false
}
```

### 5. Pod Integration

**Automatic resource registration as pods**:

```dart
import 'package:jetleaf_resource/jetleaf_resource.dart';
import 'package:jetleaf_pod/jetleaf_pod.dart';

@Service()
class CachedUserService {
  final Map<String, User> _cache = {};

  Future<User> getUser(String id) async {
    if (_cache.containsKey(id)) {
      return _cache[id]!;
    }

    final user = await _fetchUser(id);
    _cache[id] = user;
    return user;
  }

  void invalidateUser(String id) {
    _cache.remove(id);
  }

  Future<User> _fetchUser(String id) async {
    // Database call
    await Future.delayed(Duration(milliseconds: 50));
    return User(id: id, name: 'User $id');
  }
}

class User {
  final String id;
  final String name;
  User({required this.id, required this.name});
}

// Auto-configured in pod
void main() async {
  final factory = DefaultListablePodFactory();

  factory.registerDefinition(
    PodDefinition(
      name: 'userService',
      create: () => CachedUserService(),
      scope: Scope.singleton,
    ),
  );

  final service = factory.getPod<CachedUserService>('userService');
  final user = await service.getUser('123');
  print('User: ${user.name}');
}
```

## 🎯 Common Patterns

### Pattern 1: Service with Cache Layer

```dart
import 'package:jetleaf_resource/jetleaf_resource.dart';

class UserRepository {
  Future<User> getUserById(String id) async {
    // Simulate database query
    await Future.delayed(Duration(milliseconds: 200));
    return User(id: id, name: 'User $id');
  }
}

class CachedUserService {
  final UserRepository _repository;
  final Map<String, CacheEntry> _cache = {};
  static const _cacheTTL = Duration(minutes: 5);

  CachedUserService(this._repository);

  Future<User> getUser(String id) async {
    final cached = _checkCache(id);
    if (cached != null) {
      print('Cache HIT for $id');
      return cached;
    }

    print('Cache MISS for $id, fetching from DB');
    final user = await _repository.getUserById(id);
    _cache[id] = CacheEntry(user, _cacheTTL);
    return user;
  }

  User? _checkCache(String id) {
    final entry = _cache[id];
    if (entry != null && !entry.isExpired) {
      return entry.value as User;
    }
    _cache.remove(id);
    return null;
  }
}

class CacheEntry {
  final Object? value;
  final DateTime expiresAt;

  CacheEntry(this.value, Duration ttl)
    : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class User {
  final String id;
  final String name;
  User({required this.id, required this.name});
}

void main() async {
  final repo = UserRepository();
  final service = CachedUserService(repo);

  // First call: 200ms from database
  var start = DateTime.now();
  var user = await service.getUser('1');
  print('First call took: ${DateTime.now().difference(start).inMilliseconds}ms');

  // Second call: instant from cache
  start = DateTime.now();
  user = await service.getUser('1');
  print('Second call took: ${DateTime.now().difference(start).inMilliseconds}ms');
}
```

### Pattern 2: API Rate Limiting

```dart
import 'package:jetleaf_resource/jetleaf_resource.dart';

class ApiRateLimiter {
  final int maxRequests;
  final Duration timeWindow;
  final Map<String, List<DateTime>> _requests = {};

  ApiRateLimiter({
    required this.maxRequests,
    required this.timeWindow,
  });

  bool isAllowed(String clientId) {
    final now = DateTime.now();
    final windowStart = now.subtract(timeWindow);

    // Get or create request list for client
    final requests = _requests[clientId] ?? [];
    
    // Remove old requests outside window
    requests.removeWhere((time) => time.isBefore(windowStart));

    // Check limit
    if (requests.length < maxRequests) {
      requests.add(now);
      _requests[clientId] = requests;
      return true;
    }

    return false;
  }

  int getRemainingRequests(String clientId) {
    final requests = _requests[clientId] ?? [];
    return maxRequests - requests.length;
  }
}

void main() {
  final limiter = ApiRateLimiter(
    maxRequests: 5,
    timeWindow: Duration(minutes: 1),
  );

  const clientId = 'client-123';

  for (int i = 0; i < 7; i++) {
    final allowed = limiter.isAllowed(clientId);
    final remaining = limiter.getRemainingRequests(clientId);
    print('Request $i: ${allowed ? 'ALLOWED' : 'BLOCKED'} (remaining: $remaining)');
  }
}
```

## ⚠️ Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Cache grows unbounded | No TTL or eviction | Set TTL and implement LRU eviction |
| Rate limit too strict | Window too small | Increase maxRequests or timeWindow |
| Cache misses | Wrong key generation | Verify key format consistency |
| Memory leak | Expired entries not removed | Implement cleanup/invalidation |
| False positives | Clock skew | Use consistent time source |

## 📋 Best Practices

### ✅ DO

- Set appropriate TTL for cache entries
- Implement cache invalidation on data updates
- Use meaningful cache key prefixes
- Monitor cache hit ratios
- Implement exponential backoff with rate limiting
- Use specific rate limits per client/endpoint
- Clear cache on errors
- Log cache operations
- Test cache behavior under load
- Implement cache warming for hot data

### ❌ DON'T

- Cache sensitive data (passwords, tokens)
- Use unbounded caches without limits
- Ignore cache invalidation
- Cache all requests indiscriminately
- Set TTL too long (stale data)
- Set TTL too short (cache thrashing)
- Cache without considering memory impact
- Use weak keys that don't properly differentiate
- Forget to handle cache misses gracefully
- Over-cache frequently changing data

## 📦 Dependencies

- **`jetleaf_lang`** — Language utilities
- **`jetleaf_logging`** — Logging support
- **`jetleaf_pod`** — Pod integration
- **`jetleaf_core`** — Core framework
- **`jetleaf_env`** — Configuration

## 🔗 Related Packages

- **`jetleaf_web`** — HTTP caching headers
- **`jetleaf_pod`** — Pod lifecycle
- **`jetleaf_core`** — Application lifecycle

## 📄 License

This package is part of the JetLeaf Framework. See LICENSE in the root directory.

## 📞 Support

For issues, questions, or contributions, visit:
- [GitHub Issues](https://github.com/jetleaf/jetleaf_resource/issues)
- [Documentation](https://jetleaf.hapnium.com/docs/resource)
- [Community Forum](https://forum.jetleaf.hapnium.com)

---

**Created with ❤️ by [Hapnium](https://hapnium.com)**
