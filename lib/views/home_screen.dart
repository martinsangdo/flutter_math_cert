import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'quiz_screen.dart';
import 'widgets/ad_banner.dart';
import 'widgets/app_logo.dart';
import 'widgets/clay_card.dart';
import 'widgets/content_width.dart';
import 'widgets/countdown.dart';
import 'widgets/message_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _practice(BuildContext context, WidgetRef ref) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const QuizScreen()));
    ref.invalidate(homeDataProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeDataProvider);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            AppLogo(size: 36),
            SizedBox(width: 10),
            Flexible(
              child: Text('MathPathway', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings: change contest or grade',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => MessageView(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load your progress',
          detail: 'Check your connection and try again.',
          onAction: () => ref.invalidate(homeDataProvider),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(homeDataProvider.future),
          child: ContentWidth(
            child: _Dashboard(
              data: d,
              onPractice: () => _practice(context, ref),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AdBanner(),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.data, required this.onPractice});

  final HomeData data;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final grade = ref.watch(selectionProvider)!.grade;
    final level = data.cert.levelForGrade(grade);

    final groups = <String, List<TopicMastery>>{};
    for (final t in data.mastery) {
      groups.putIfAbsent(t.domain, () => []).add(t);
    }

    final questionCount = level?.totalQuestions;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _Hero(cert: data.cert, grade: grade, level: level, streak: data.streak),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.secondary,
            foregroundColor: scheme.onSecondary,
            minimumSize: const Size.fromHeight(60),
          ),
          onPressed: onPractice,
          icon: const Icon(Icons.play_arrow_rounded, size: 30),
          label: const Text('Start practice exam'),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            [
              if (questionCount != null) '$questionCount questions',
              '${data.cert.timeMinutes} minutes',
            ].join(' · '),
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 28),
        Text('Your skill tree', style: text.titleLarge),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          ClayCard(
            child: Text(
              'No topics for this contest yet.',
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          for (final (i, entry) in groups.entries.indexed) ...[
            _DomainCard(
              domain: entry.key,
              topics: entry.value,
              accent: AppTheme.accents[i % AppTheme.accents.length],
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({
    required this.cert,
    required this.grade,
    required this.level,
    required this.streak,
  });

  final Certification cert;
  final int grade;
  final ExamLevel? level;
  final int streak;

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: ref.read(examDateProvider) ?? today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 3 * 365)),
      helpText: 'When is your exam?',
    );
    if (picked != null) await ref.read(examDateProvider.notifier).set(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final examDate = ref.watch(examDateProvider);
    const onHero = Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Color(0xFF1E3A8A), offset: Offset(0, 5)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cert.id,
                        style: text.headlineMedium?.copyWith(color: onHero),
                      ),
                      Text(
                        'Grade $grade${level == null ? '' : ' · ${_prettyDomain(level!.code)}'}',
                        style: text.bodyLarge?.copyWith(
                          color: onHero.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
                _StreakPill(streak: streak),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Exam countdown',
                    style: text.titleSmall?.copyWith(color: onHero),
                  ),
                ),
                if (examDate == null)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: onHero),
                    onPressed: () => _pickDate(context, ref),
                    icon: const Icon(Icons.event_rounded),
                    label: const Text('Set date'),
                  )
                else ...[
                  IconButton(
                    tooltip: 'Change exam date',
                    color: onHero,
                    icon: const Icon(Icons.edit_calendar_rounded),
                    onPressed: () => _pickDate(context, ref),
                  ),
                  IconButton(
                    tooltip: 'Hide countdown',
                    color: onHero,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () =>
                        ref.read(examDateProvider.notifier).clear(),
                  ),
                ],
              ],
            ),
            if (examDate != null)
              Countdown(
                key: ValueKey(examDate),
                deadline: examDate,
                builder: (_, d) => d == Duration.zero
                    ? Text(
                        'It is exam day. Good luck!',
                        style: text.titleMedium?.copyWith(color: onHero),
                      )
                    : Row(
                        children: [
                          _TimeTile(value: d.inDays, unit: 'days'),
                          _TimeTile(value: d.inHours % 24, unit: 'hours'),
                          _TimeTile(value: d.inMinutes % 60, unit: 'min'),
                          _TimeTile(value: d.inSeconds % 60, unit: 'sec'),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: streak == 0 ? 'No streak yet' : '$streak day streak',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: streak == 0 ? Colors.white70 : const Color(0xFFFBBF24),
              ),
              const SizedBox(width: 4),
              Text(
                streak == 0
                    ? 'No streak yet'
                    : '$streak day${streak == 1 ? '' : 's'}',
                style: text.titleSmall?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.value, required this.unit});

  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(
                  value.toString().padLeft(2, '0'),
                  style: AppTheme.heading(
                    30,
                    700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                Text(
                  unit,
                  style: text.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _domainIcon(String code) {
  final c = code.toUpperCase();
  if (c.contains('GEOM')) return Icons.change_history_rounded;
  if (c.contains('NUMBER')) return Icons.pin_rounded;
  if (c.contains('COMBIN')) return Icons.shuffle_rounded;
  if (c.contains('LOGIC')) return Icons.psychology_alt_rounded;
  if (c.contains('ALGEBRA')) return Icons.functions_rounded;
  return Icons.category_rounded;
}

String _prettyDomain(String code) {
  final words = code.toLowerCase().replaceAll('_', ' ');
  return words[0].toUpperCase() + words.substring(1);
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({
    required this.domain,
    required this.topics,
    required this.accent,
  });

  final String domain;
  final List<TopicMastery> topics;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ClayCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withValues(alpha: 0.18),
                child: Icon(_domainIcon(domain), color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_prettyDomain(domain), style: text.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final t in topics) _TopicRow(t),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow(this.topic);

  final TopicMastery topic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final started = topic.attempts > 0;
    final mastered = topic.score >= 80;
    return Semantics(
      label:
          '${topic.title}, ${started ? '${topic.score} percent mastery' : 'not started'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: topic.percent,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      color: mastered ? scheme.success : scheme.primary,
                    ),
                  ),
                  Text(
                    started ? '${topic.score}' : '-',
                    style: text.titleSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.title, style: text.titleSmall),
                  Row(
                    children: [
                      if (mastered) ...[
                        Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: scheme.success,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        !started
                            ? 'Not started'
                            : mastered
                            ? 'Mastered'
                            : '${topic.attempts} answered',
                        style: text.bodyMedium?.copyWith(
                          color: mastered
                              ? scheme.success
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
