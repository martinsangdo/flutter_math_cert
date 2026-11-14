import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathpathway_junior/logic/providers.dart';
import 'package:mathpathway_junior/logic/quiz_controller.dart';
import 'package:mathpathway_junior/models/models.dart';
import 'package:mathpathway_junior/services/cache_service.dart';
import 'package:mathpathway_junior/services/supabase_service.dart';
import 'package:mathpathway_junior/views/quiz_screen.dart';

class MemoryCache implements CacheService {
  final prefs = <String, String>{};
  @override
  String? readPref(String key) => prefs[key];
  @override
  Future<void> writePref(String key, String value) async {
    prefs[key] = value;
  }

  @override
  Future<void> removePref(String key) async {
    prefs.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ProofService implements SupabaseService {
  ProofService(this.questions);
  final List<Question> questions;
  final mastery = <int>[];
  ExamSession? submitted;
  @override
  Future<List<Question>> fetchQuestions({
    required int setId,
    int limit = 10,
    int offset = 0,
  }) async => questions.skip(offset).take(limit).toList();
  @override
  Future<void> updateUserMastery(int topicId, bool correct) async {
    mastery.add(topicId);
  }

  @override
  Future<void> submitExamResult(ExamSession session) async {
    submitted = session;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Question question(int id, String type) => Question.fromJson({
  'id': id,
  'topic_id': id,
  'question_type': type,
  'stem_text': 'Explain your answer',
  'correct_answer': '42',
  'points': 5,
  'penalty_points': 2,
  'detailed_solution_latex': 'Solution',
});

void main() {
  testWidgets('proof input accepts prose and the hint button reveals solution', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cache = MemoryCache();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        cacheServiceProvider.overrideWithValue(cache),
        supabaseServiceProvider.overrideWithValue(ProofService([question(1, 'PROOF')])),
        selectedCertProvider.overrideWith((ref) async => Certification.fromJson({
          'id': 'IMO', 'full_name': 'IMO', 'min_grade': 9, 'max_grade': 12,
          'default_time_minutes': 30,
        })),
      ],
      child: const MaterialApp(home: QuizScreen(ExamSet(
        id: 1, levelId: 1, title: 'Proofs', questionCount: 1, premium: false,
      ))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Your proof'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Let a be odd.\nThen a = 2k+1.');
    expect(cache.readPref(quizDraftKey(1)), contains('Then a = 2k+1.'));
    expect(find.text('Solution'), findsNothing);
    final hint = find.text('Watch an ad for a hint');
    await tester.ensureVisible(hint);
    await tester.tap(hint);
    await tester.pumpAndSettle();
    expect(find.text('Step-by-step solution'), findsOneWidget);
    expect(find.text('Solution', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  for (final mixed in [false, true]) {
    test(
      'proofs stay ungraded in ${mixed ? 'mixed' : 'proof-only'} sets',
      () async {
        final service = ProofService([
          question(1, 'PROOF'),
          if (mixed) question(2, 'INTEGER_FILL'),
        ]);
        final cache = MemoryCache();
        final container = ProviderContainer(
          overrides: [
            cacheServiceProvider.overrideWithValue(cache),
            supabaseServiceProvider.overrideWithValue(service),
            selectedCertProvider.overrideWith(
              (ref) async => Certification.fromJson({
                'id': 'IMO',
                'full_name': 'IMO',
                'min_grade': 9,
                'max_grade': 12,
                'default_time_minutes': 30,
                'has_negative_marking': true,
              }),
            ),
          ],
        );
        addTearDown(container.dispose);
        final set = ExamSet(
          id: 1,
          levelId: 1,
          title: 'Proofs',
          questionCount: service.questions.length,
          premium: false,
        );
        final provider = quizProvider(set);
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);
        await pumpEventQueue();
        final controller = container.read(provider.notifier);
        controller.answer('First step.\nSecond step.');
        expect(
          container.read(provider).answers[1],
          'First step.\nSecond step.',
        );
        controller.unlockHint();
        expect(container.read(provider).hinted, contains(1));
        expect(cache.readPref(quizDraftKey(1)), contains('Second step.'));
        if (mixed) {
          controller.next();
          controller.answer('42');
        }
        final session = (await controller.finish())!;
        expect(session.ungradedCount, 1);
        expect(session.total, mixed ? 1 : 0);
        expect(session.score, mixed ? 5 : 0);
        expect(session.maxScore, mixed ? 5 : 0);
        expect(session.topics.containsKey(1), isFalse);
        expect(service.mastery, mixed ? [2] : isEmpty);
        expect(service.submitted, same(session));
      },
    );
  }
}
