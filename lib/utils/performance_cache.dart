import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

class PerformanceCache<K, V> {
  final LinkedHashMap<K, CacheEntry<V>> _cache = LinkedHashMap();
  final int maxSize;
  final Duration ttl;

  PerformanceCache({
    this.maxSize = 100,
    this.ttl = const Duration(minutes: 5),
  });

  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (DateTime.now().difference(entry.timestamp) > ttl) {
      _cache.remove(key);
      return null;
    }
    
    return entry.value;
  }

  void put(K key, V value) {
    if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = CacheEntry(value, DateTime.now());
  }

  void clear() {
    _cache.clear();
  }

  void remove(K key) {
    _cache.remove(key);
  }

  int get length => _cache.length;
}

class CacheEntry<V> {
  final V value;
  final DateTime timestamp;

  CacheEntry(this.value, this.timestamp);
}
