import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Tiny offline store on Hive. Holds question pages plus the user's selection,
/// and wipes the question cache whenever it nears [maxBytes] so it stays small
/// on low-end phones.
class CacheService {
  CacheService(this._questions, this._prefs);

  static const maxBytes = 50 * 1024;
  static const _clearThreshold = maxBytes * 9 ~/ 10; // "nearly" 50KB

  final Box<String> _questions;
  final Box<String> _prefs;

  static Future<CacheService> open() async {
    await Hive.initFlutter();
    return CacheService(
      await Hive.openBox<String>('question_cache'),
      await Hive.openBox<String>('prefs'),
    );
  }

  int get questionCacheBytes =>
      _questions.values.fold(0, (sum, v) => sum + utf8.encode(v).length);

  String? readQuestions(String key) => _questions.get(key);

  Future<void> writeQuestions(String key, String json) async {
    final incoming = utf8.encode(json).length;
    final existing = _questions.get(key);
    final current = questionCacheBytes - (existing == null ? 0 : utf8.encode(existing).length);
    if (current + incoming >= _clearThreshold) await _questions.clear();
    if (incoming < _clearThreshold) await _questions.put(key, json);
  }

  String? readPref(String key) => _prefs.get(key);

  Future<void> writePref(String key, String value) => _prefs.put(key, value);

  Future<void> removePref(String key) => _prefs.delete(key);
}
