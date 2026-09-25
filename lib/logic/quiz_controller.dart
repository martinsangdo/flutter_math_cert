import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'providers.dart';

const pageSize = 10;
const _fallbackQuestionCount = 20;

class QuizState {
  const QuizState({
    this.questions = const [],
    this.index = 0,
    this.answers = const {},
    this.hinted = const {},
    this.loading = true,
    this.deadline,
    this.error,
  });

  final List<Question> questions;
  final int index;

  /// Question id -> given answer (option letter or integer text).
  final Map<int, String> answers;

  /// Question ids whose hint was unlocked by a rewarded ad.
  final Set<int> hinted;
  final bool loading;

  /// Set once the first page arrives: the moment the exam clock runs out.
  final DateTime? deadline;
  final Object? error;

  Question? get current => index < questions.length ? questions[index] : null;
  bool get isLast => index >= questions.length - 1;

  QuizState copyWith({
    List<Question>? questions,
    int? index,
    Map<int, String>? answers,
    Set<int>? hinted,
    bool? loading,
    DateTime? deadline,
    Object? error,
  }) =>
      QuizState(
        questions: questions ?? this.questions,
        index: index ?? this.index,
        answers: answers ?? this.answers,
        hinted: hinted ?? this.hinted,
        loading: loading ?? this.loading,
        deadline: deadline ?? this.deadline,
        error: error,
      );
}

class QuizController extends AutoDisposeNotifier<QuizState> {
  late Certification _cert;
  ExamLevel? _level;
  late DateTime _startedAt;
  var _disposed = false;
  var _finishing = false;

  @override
  QuizState build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(load);
    return const QuizState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true);
    final selection = ref.read(selectionProvider)!;
    final service = ref.read(supabaseServiceProvider);
    try {
      _cert = await ref.read(selectedCertProvider.future);
      _level = _cert.levelForGrade(selection.grade);
      final target = _level?.totalQuestions ?? _fallbackQuestionCount;

      final loaded = <Question>[];
      // Paginated: pages of [pageSize] until the exam is full or rows run out.
      for (var offset = 0; loaded.length < target; offset += pageSize) {
        final page = await service.fetchQuestions(
          certId: selection.certId,
          gradeLevel: selection.grade,
          limit: min(pageSize, target - loaded.length),
          offset: offset,
        );
        if (_disposed) return;
        loaded.addAll(page);
        if (offset == 0) {
          _startedAt = DateTime.now();
          state = state.copyWith(
            deadline: _startedAt.add(Duration(minutes: _cert.timeMinutes)),
          );
        }
        // Show the first page immediately; keep appending the rest quietly.
        state = state.copyWith(questions: List.of(loaded), loading: false);
        if (page.length < pageSize) break;
      }
    } catch (e) {
      if (!_disposed) state = state.copyWith(loading: false, error: e);
    }
  }

  void answer(String value) {
    final q = state.current;
    if (q == null) return;
    final answers = Map.of(state.answers);
    value.trim().isEmpty ? answers.remove(q.id) : answers[q.id] = value.trim();
    state = state.copyWith(answers: answers);
  }

  void unlockHint() {
    final q = state.current;
    if (q != null) state = state.copyWith(hinted: {...state.hinted, q.id});
  }

  void next() {
    if (!state.isLast) state = state.copyWith(index: state.index + 1);
  }

  /// Scores the exam (points, minus penalties when the contest has negative
  /// marking), saves it and records per-topic mastery. Returns null if a finish
  /// is already in flight. Network failures never block the results.
  Future<ExamSession?> finish() async {
    if (_finishing) return null;
    _finishing = true;

    final service = ref.read(supabaseServiceProvider);
    final scores = <int, ({String name, int correct, int total})>{};
    var correct = 0;
    var score = 0.0;
    var maxScore = 0.0;

    for (final q in state.questions) {
      final given = state.answers[q.id];
      final ok = q.isCorrect(given);
      maxScore += q.points;
      if (ok) {
        correct++;
        score += q.points;
      } else if (given != null && _cert.negativeMarking) {
        score -= q.penalty;
      }
      final s = scores[q.topicId];
      scores[q.topicId] = (
        name: q.topicTitle,
        correct: (s?.correct ?? 0) + (ok ? 1 : 0),
        total: (s?.total ?? 0) + 1,
      );
      if (given != null) {
        service.updateUserMastery(q.topicId, ok).catchError((_) {});
      }
    }

    final session = ExamSession(
      certId: _cert.id,
      levelId: _level?.id,
      score: max(0, score),
      maxScore: maxScore,
      correct: correct,
      total: state.questions.length,
      durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
      topics: scores.map((id, s) => MapEntry(id, TopicScore(s.name, s.correct, s.total))),
    );
    try {
      await service.submitExamResult(session);
    } catch (_) {}
    return session;
  }
}

final quizProvider =
    NotifierProvider.autoDispose<QuizController, QuizState>(QuizController.new);
