import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'cache_service.dart';

/// Direct client-to-Supabase access. Row Level Security does the authorization;
/// the app signs in anonymously so `auth.uid()` exists without a login screen.
class SupabaseService {
  SupabaseService(this._client, this._cache);

  final SupabaseClient _client;
  final CacheService _cache;

  Future<String> _uid() async {
    final user = _client.auth.currentUser ??
        (await _client.auth.signInAnonymously()).user;
    if (user == null) throw const AuthException('Anonymous sign-in failed');
    return user.id;
  }

  /// All contests with their exam levels (one query). Cached so the app can
  /// still open offline.
  Future<List<Certification>> fetchCertifications() async {
    try {
      await _uid();
      final rows = await _client.from('certifications').select(
            'id, full_name, organizing_body, min_grade, max_grade, '
            'default_time_minutes, has_negative_marking, '
            'exam_levels(id, level_code, target_grade_min, target_grade_max, total_questions)',
          ).order('id');
      final json = jsonEncode(rows);
      await _cache.writePref('certifications', json);
      return parseCertifications(json);
    } catch (e) {
      debugPrint('fetchCertifications failed: $e');
      final cached = _cache.readPref('certifications');
      if (cached == null) rethrow;
      return parseCertifications(cached);
    }
  }

  /// One page of gradable questions (with their topic title) for the exam
  /// level that covers [gradeLevel]. Falls back to the offline cache when the
  /// network call fails.
  Future<List<Question>> fetchQuestions({
    required String certId,
    required int gradeLevel,
    int limit = 10,
    int offset = 0,
  }) async {
    final cacheKey = '$certId:$gradeLevel:$offset:$limit';
    try {
      await _uid();
      final rows = await _client
          .from('questions')
          .select(
            'id, topic_id, question_type, stem_text, latex_content, image_url, '
            'options_json, correct_answer, points, penalty_points, '
            'kid_friendly_hint, detailed_solution_latex, '
            'topics(title), exam_levels!inner(id)',
          )
          .eq('certification_id', certId)
          .neq('question_type', 'PROOF') // proofs can't be auto-graded
          .lte('exam_levels.target_grade_min', gradeLevel)
          .gte('exam_levels.target_grade_max', gradeLevel)
          .order('id')
          .range(offset, offset + limit - 1);
      final json = jsonEncode(rows);
      await _cache.writeQuestions(cacheKey, json);
      return parseQuestions(json);
    } catch (e) {
      debugPrint('fetchQuestions failed: $e');
      final cached = _cache.readQuestions(cacheKey);
      if (cached == null) rethrow;
      return parseQuestions(cached);
    }
  }

  Future<void> submitExamResult(ExamSession session) async {
    final uid = await _uid();
    await _client.from('exam_sessions').insert({
      'id': const Uuid().v4(),
      'user_id': uid,
      ...session.toRow(),
    });
  }

  /// Atomic upsert of the caller's per-topic counters (see supabase/app_access.sql).
  Future<void> updateUserMastery(int topicId, bool isCorrect) async {
    await _uid();
    await _client.rpc('update_user_mastery', params: {
      'p_topic_id': topicId,
      'p_is_correct': isCorrect,
    });
  }

  /// Streak plus the mastery of every topic that has questions for [cert].
  Future<HomeData> fetchHomeData(Certification cert) async {
    final uid = await _uid();
    final results = await Future.wait([
      _client
          .from('exam_sessions')
          .select('completed_at')
          .eq('user_id', uid)
          .order('completed_at', ascending: false)
          .limit(60),
      _client
          .from('topics')
          .select(
            'id, domain_code, title, difficulty_tier, '
            'user_mastery(questions_attempted, mastery_score), questions!inner(id)',
          )
          .eq('questions.certification_id', cert.id)
          .limit(1, referencedTable: 'questions')
          .order('domain_code')
          .order('difficulty_tier'),
    ]);

    return HomeData(
      cert: cert,
      streak: streakFromDates(
        [for (final r in results[0]) parseTimestamp((r as Map)['completed_at'] as String)],
        DateTime.now(),
      ),
      mastery: [
        for (final r in results[1]) TopicMastery.fromJson(r),
      ],
    );
  }
}

/// `completed_at` is `timestamp` (no zone) written by a UTC server, so a value
/// without an offset is UTC.
DateTime parseTimestamp(String s) {
  final hasZone = RegExp(r'(Z|[+-]\d{2}(:?\d{2})?)$').hasMatch(s);
  return DateTime.parse(hasZone ? s : '${s}Z').toLocal();
}

/// Consecutive local days with at least one session, ending today (or
/// yesterday, so the streak survives until the day is over).
int streakFromDates(List<DateTime> sessions, DateTime now) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final days = sessions.map(day).toSet();
  var cursor = day(now);
  if (!days.contains(cursor)) cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}
