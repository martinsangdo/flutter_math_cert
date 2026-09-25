import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mathpathway_junior/models/models.dart';
import 'package:mathpathway_junior/services/cache_service.dart';
import 'package:mathpathway_junior/services/supabase_service.dart';

void main() {
  test('answersMatch compares ints numerically and ignores blanks', () {
    expect(answersMatch(' 05 ', '5'), isTrue);
    expect(answersMatch('-3', '-3'), isTrue);
    expect(answersMatch('', '5'), isFalse);
    expect(answersMatch(null, '5'), isFalse);
  });

  test('answersMatch treats option letters case-insensitively', () {
    expect(answersMatch('b', 'B'), isTrue);
    expect(answersMatch('C', 'B'), isFalse);
  });

  test('parses a question row and picks the level for a grade', () {
    final q = Question.fromJson({
      'id': 7,
      'topic_id': 3,
      'question_type': 'MCQ_5_OPTION',
      'stem_text': 'Pick one',
      'options_json': {'B': 'two', 'A': 'one'},
      'correct_answer': 'B',
      'points': 3,
      'penalty_points': 0.8,
      'detailed_solution_latex': 'because',
      'topics': {'title': 'Geometry'},
    });
    expect(q.options.map((o) => o.key), ['A', 'B']);
    expect(q.type, QuestionType.mcq);
    expect(q.topicTitle, 'Geometry');
    expect(q.penalty, 0.8);
    expect(q.isCorrect('B'), isTrue);

    final cert = Certification.fromJson({
      'id': 'IKMC',
      'full_name': 'Math Kangaroo',
      'min_grade': 1,
      'max_grade': 12,
      'default_time_minutes': 75,
      'exam_levels': [
        {'id': 1, 'level_code': 'ECOLIER', 'target_grade_min': 3, 'target_grade_max': 4, 'total_questions': 24},
        {'id': 2, 'level_code': 'BENJAMIN', 'target_grade_min': 5, 'target_grade_max': 6, 'total_questions': 24},
      ],
    });
    expect(cert.levelForGrade(5)?.code, 'BENJAMIN');
    expect(cert.levelForGrade(9), isNull);
    expect(cert.negativeMarking, isFalse);
  });

  test('timestamps without a zone are read as UTC', () {
    expect(parseTimestamp('2026-09-25T10:00:00.5').isUtc, isFalse);
    expect(parseTimestamp('2026-09-25T10:00:00.5').toUtc(), DateTime.utc(2026, 9, 25, 10, 0, 0, 500));
    expect(parseTimestamp('2026-09-25T10:00:00+02:00').toUtc(), DateTime.utc(2026, 9, 25, 8));
  });

  test('streak counts consecutive days ending today or yesterday', () {
    final now = DateTime(2026, 9, 25, 10);
    expect(streakFromDates([], now), 0);
    expect(streakFromDates([DateTime(2026, 9, 25, 8), DateTime(2026, 9, 24), DateTime(2026, 9, 22)], now), 2);
    expect(streakFromDates([DateTime(2026, 9, 24)], now), 1);
    expect(streakFromDates([DateTime(2026, 9, 20)], now), 0);
  });

  test('question cache is wiped before it reaches 50KB', () async {
    final dir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(dir.path);
    final cache = CacheService(
      await Hive.openBox<String>('q'),
      await Hive.openBox<String>('p'),
    );
    final page = 'x' * (12 * 1024);

    for (var i = 0; i < 3; i++) {
      await cache.writeQuestions('k$i', page);
    }
    expect(cache.questionCacheBytes, 36 * 1024);

    await cache.writeQuestions('k3', page); // 48KB would exceed the 45KB threshold
    expect(cache.readQuestions('k0'), isNull);
    expect(cache.readQuestions('k3'), page);
    expect(cache.questionCacheBytes, lessThan(CacheService.maxBytes));

    await cache.writePref('exam:X', '2026-12-01');
    expect(cache.readPref('exam:X'), '2026-12-01');
    await cache.removePref('exam:X');
    expect(cache.readPref('exam:X'), isNull);

    await Hive.close();
    await dir.delete(recursive: true);
  });
}
