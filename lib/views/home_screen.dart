import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/providers.dart';
import '../models/models.dart';
import 'onboarding_screen.dart';
import 'quiz_screen.dart';
import 'widgets/ad_banner.dart';
import 'widgets/countdown_text.dart';

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
    final selection = ref.watch(selectionProvider)!;
    final data = ref.watch(homeDataProvider);
    final level = data.valueOrNull?.cert.levelForGrade(selection.grade);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${selection.certId} · Grade ${selection.grade}${level == null ? '' : ' · ${level.code}'}',
        ),
        actions: [
          IconButton(
            tooltip: 'Change contest or grade',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
            ),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load your progress.'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(homeDataProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(homeDataProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatusRow(streak: d.streak),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _practice(context, ref),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start practice exam'),
              ),
              const SizedBox(height: 24),
              Text(
                'Skill tree',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (d.mastery.isEmpty)
                const Text('No topics for this contest yet.')
              else
                for (var i = 0; i < d.mastery.length; i++) ...[
                  if (i == 0 || d.mastery[i].domain != d.mastery[i - 1].domain)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _prettyDomain(d.mastery[i].domain),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  _MasteryTile(d.mastery[i]),
                ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AdBanner(),
    );
  }
}

String _prettyDomain(String code) {
  final words = code.toLowerCase().replaceAll('_', ' ');
  return words[0].toUpperCase() + words.substring(1);
}

class _StatusRow extends ConsumerWidget {
  const _StatusRow({required this.streak});

  final int streak;

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: ref.read(examDateProvider) ?? today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 3 * 365)),
      helpText: 'Exam date',
    );
    if (picked != null) await ref.read(examDateProvider.notifier).set(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examDate = ref.watch(examDateProvider);
    final text = Theme.of(context).textTheme;
    // IntrinsicHeight: the list gives unbounded height, which `stretch` can't use.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Exam in', style: text.labelMedium),
                    const SizedBox(height: 4),
                    examDate == null
                        ? TextButton(
                            onPressed: () => _pickDate(context, ref),
                            child: const Text('Set exam date'),
                          )
                        : InkWell(
                            onTap: () => _pickDate(context, ref),
                            child: CountdownText(
                              key: ValueKey(examDate),
                              deadline: examDate,
                              format: formatDaysLeft,
                              style: text.titleMedium,
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Streak', style: text.labelMedium),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: Colors.deepOrange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$streak day${streak == 1 ? '' : 's'}',
                          style: text.titleMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MasteryTile extends StatelessWidget {
  const _MasteryTile(this.topic);

  final TopicMastery topic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(topic.title)),
              Text(topic.attempts == 0 ? 'New' : '${topic.score}%'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: topic.percent, minHeight: 8),
        ],
      ),
    );
  }
}
