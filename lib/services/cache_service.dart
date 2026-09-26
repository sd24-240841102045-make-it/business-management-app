import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
// Cache Entry Model
// ─────────────────────────────────────────────
class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

// ─────────────────────────────────────────────
// Enterprise Cache Service (Singleton)
// ─────────────────────────────────────────────
class CacheService {
  static final CacheService _instance = CacheService._();
  factory CacheService() => _instance;
  CacheService._();

  final Map<String, CacheEntry<dynamic>> _memoryCache = {};
  SharedPreferences? _prefs;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    } catch (e) {
      debugPrint('CacheService: SharedPreferences init notice: $e');
    }
  }

  /// Store in memory with TTL
  void setMemory<T>(String key, T data, {Duration ttl = const Duration(minutes: 10)}) {
    _memoryCache[key] = CacheEntry<T>(
      data: data,
      timestamp: DateTime.now(),
      ttl: ttl,
    );
  }

  /// Get from memory (returns null if expired or missing)
  T? getMemory<T>(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _memoryCache.remove(key);
      return null;
    }
    return entry.data as T?;
  }

  /// Store a JSON-encodable list or map in local persistent disk cache
  Future<void> setPersistent(String key, dynamic data) async {
    setMemory(key, data, ttl: const Duration(hours: 12));
    try {
      if (_prefs == null) await initialize();
      final jsonStr = jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'payload': data,
      });
      await _prefs?.setString('cache_$key', jsonStr);
    } catch (e) {
      debugPrint('CacheService: setPersistent error for $key: $e');
    }
  }

  /// Get cached JSON from local disk
  dynamic getPersistent(String key) {
    try {
      final jsonStr = _prefs?.getString('cache_$key');
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map && decoded.containsKey('payload')) {
        return decoded['payload'];
      }
      return decoded;
    } catch (e) {
      debugPrint('CacheService: getPersistent error for $key: $e');
      return null;
    }
  }

  /// Invalidate cache for a specific key
  Future<void> invalidate(String key) async {
    _memoryCache.remove(key);
    try {
      if (_prefs == null) await initialize();
      await _prefs?.remove('cache_$key');
    } catch (_) {}
  }

  /// Clear all cache
  Future<void> clearAll() async {
    _memoryCache.clear();
    try {
      if (_prefs == null) await initialize();
      final keys = _prefs?.getKeys().where((k) => k.startsWith('cache_')).toList() ?? [];
      for (final k in keys) {
        await _prefs?.remove(k);
      }
    } catch (_) {}
  }
}
