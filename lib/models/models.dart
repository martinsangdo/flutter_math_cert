import 'dart:convert';

enum QuestionType { mcq, integer }

class ExamLevel {
  const ExamLevel({
    required this.id,
    required this.code,
    required this.gradeMin,
    required this.gradeMax,
    required this.totalQuestions,
  });

  factory ExamLevel.fromJson(Map<String, dynamic> json) => ExamLevel(
        id: json['id'] as int,
        code: json['level_code'] as String,
        gradeMin: json['target_grade_min'] as int,
        gradeMax: json['target_grade_max'] as int,
        totalQuestions: json['total_questions'] as int,
      );

  final int id;
  final String code;
  final int gradeMin;
  final int gradeMax;
  final int totalQuestions;
}

class Certification {
  const Certification({
    required this.id,
    required this.fullName,
    this.organizingBody,
    required this.minGrade,
    required this.maxGrade,
    required this.timeMinutes,
    required this.negativeMarking,
    required this.levels,
  });

  factory Certification.fromJson(Map<String, dynamic> json) => Certification(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        organizingBody: json['organizing_body'] as String?,
        minGrade: json['min_grade'] as int,
        maxGrade: json['max_grade'] as int,
        timeMinutes: json['default_time_minutes'] as int,
        negativeMarking: json['has_negative_marking'] as bool? ?? false,
        levels: [
          for (final l in json['exam_levels'] as List? ?? const [])
            ExamLevel.fromJson(l as Map<String, dynamic>),
        ],
      );

  final String id;
  final String fullName;
  final String? organizingBody;
  final int minGrade;
  final int maxGrade;
  final int timeMinutes;
  final bool negativeMarking;
  final List<ExamLevel> levels;

  ExamLevel? levelForGrade(int grade) =>
      levels.where((l) => grade >= l.gradeMin && grade <= l.gradeMax).firstOrNull;
}

List<Certification> parseCertifications(String rawJson) => [
      for (final row in jsonDecode(rawJson) as List)
        Certification.fromJson(row as Map<String, dynamic>),
    ];

class Selection {
  const Selection(this.certId, this.grade);

  final String certId;
  final int grade;
}

/// Compares numerically when both sides are integers, otherwise as
/// case-insensitive trimmed text (option letters).
bool answersMatch(String? given, String expected) {
  final g = given?.trim() ?? '';
  if (g.isEmpty) return false;
  final e = expected.trim();
  final gi = int.tryParse(g);
  final ei = int.tryParse(e);
  return gi != null && ei != null ? gi == ei : g.toLowerCase() == e.toLowerCase();
}

class Question {
  const Question({
    required this.id,
    required this.topicId,
    required this.topicTitle,
    required this.type,
    required this.stem,
    this.latex,
    this.imageUrl,
    required this.options,
    required this.answer,
    required this.points,
    required this.penalty,
    this.hint,
    required this.solution,
  });

  /// Parses a `questions` row with its embedded `topics(title)` relation.
  factory Question.fromJson(Map<String, dynamic> json) {
    final raw = json['options_json'];
    final options = raw is Map
        ? (raw.entries.map((e) => MapEntry('${e.key}', '${e.value}')).toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        : <MapEntry<String, String>>[];
    return Question(
      id: json['id'] as int,
      topicId: json['topic_id'] as int,
      topicTitle: (json['topics'] as Map<String, dynamic>?)?['title'] as String? ?? '',
      type: '${json['question_type']}'.toUpperCase().startsWith('INTEGER')
          ? QuestionType.integer
          : QuestionType.mcq,
      stem: json['stem_text'] as String,
      latex: json['latex_content'] as String?,
      imageUrl: json['image_url'] as String?,
      options: options,
      answer: '${json['correct_answer']}',
      points: (json['points'] as num?)?.toDouble() ?? 1,
      penalty: (json['penalty_points'] as num?)?.toDouble() ?? 0,
      hint: json['kid_friendly_hint'] as String?,
      solution: json['detailed_solution_latex'] as String,
    );
  }

  final int id;
  final int topicId;
  final String topicTitle;
  final QuestionType type;
  final String stem;
  final String? latex;
  final String? imageUrl;

  /// MCQ choices as (letter, text), sorted by letter.
  final List<MapEntry<String, String>> options;

  /// MCQ: the option letter. Integer: the numeric answer.
  final String answer;
  final double points;
  final double penalty;
  final String? hint;
  final String solution;

  bool isCorrect(String? given) => answersMatch(given, answer);
}

List<Question> parseQuestions(String rawJson) => [
      for (final row in jsonDecode(rawJson) as List)
        Question.fromJson(row as Map<String, dynamic>),
    ];

class TopicScore {
  const TopicScore(this.name, this.correct, this.total);

  final String name;
  final int correct;
  final int total;

  double get accuracy => total == 0 ? 0 : correct / total;
}

class ExamSession {
  const ExamSession({
    required this.certId,
    this.levelId,
    required this.score,
    required this.maxScore,
    required this.correct,
    required this.total,
    required this.durationSeconds,
    required this.topics,
  });

  /// Share of available points needed to count as passed. The schema has
  /// `passed_threshold` but no threshold definition, so this is an app rule.
  static const passRatio = 0.5;

  final String certId;
  final int? levelId;
  final double score;
  final double maxScore;
  final int correct;
  final int total;
  final int durationSeconds;

  /// Keyed by topic id.
  final Map<int, TopicScore> topics;

  bool get passed => maxScore > 0 && score >= maxScore * passRatio;
  double get accuracy => total == 0 ? 0 : correct / total;

  /// Topics below 60% accuracy, weakest first.
  List<TopicScore> get weakTopics =>
      (topics.values.where((t) => t.accuracy < 0.6).toList()
        ..sort((a, b) => a.accuracy.compareTo(b.accuracy)));

  /// Columns of `exam_sessions` (the service adds `id` and `user_id`).
  Map<String, dynamic> toRow() => {
        'certification_id': certId,
        'level_id': levelId,
        'score': score,
        'total_time_seconds': durationSeconds,
        'passed_threshold': passed,
      };
}

class TopicMastery {
  const TopicMastery({
    required this.topicId,
    required this.domain,
    required this.title,
    required this.attempts,
    required this.score,
  });

  factory TopicMastery.fromJson(Map<String, dynamic> json) {
    final rows = json['user_mastery'] as List? ?? const [];
    final row = rows.isEmpty ? null : rows.first as Map<String, dynamic>;
    return TopicMastery(
      topicId: json['id'] as int,
      domain: json['domain_code'] as String,
      title: json['title'] as String,
      attempts: row?['questions_attempted'] as int? ?? 0,
      score: row?['mastery_score'] as int? ?? 0,
    );
  }

  final int topicId;
  final String domain;
  final String title;
  final int attempts;

  /// 0-100, maintained by `update_user_mastery`.
  final int score;

  double get percent => score / 100;
}

class HomeData {
  const HomeData({required this.cert, required this.streak, required this.mastery});

  final Certification cert;
  final int streak;
  final List<TopicMastery> mastery;
}
