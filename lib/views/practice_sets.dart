import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'quiz_screen.dart';
import 'widgets/ad_banner.dart';
import 'widgets/clay_card.dart';
import 'widgets/content_width.dart';
import 'widgets/message_view.dart';

/// How many sets the dashboard previews before "See all".
const _previewCount = 3;

/// Opens a set: a locked one explains itself, any other asks for confirmation
/// (the exam clock starts as soon as the first page loads) and then starts.
Future<void> startPractice(BuildContext context, WidgetRef ref, ExamSet set) async {
  if (set.premium) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Premium practice exam'),
        content: const Text('This exam will be available with a future upgrade.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    return;
  }
  final cert = await ref.read(selectedCertProvider.future);
  if (!context.mounted) return;
  final go = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (_) => _StartSheet(set: set, cert: cert),
  );
  if (go != true || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QuizScreen(set)));
}

/// "Practice exams" block of the dashboard: the first few sets plus "See all".
class PracticeSetsSection extends ConsumerWidget {
  const PracticeSetsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final sets = ref.watch(examSetsProvider);
    final cert = ref.watch(selectedCertProvider).valueOrNull;
    final list = sets.valueOrNull ?? const <ExamSet>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Practice exams', style: text.titleLarge)),
            if (list.length > _previewCount)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PracticeSetsScreen()),
                ),
                child: const Text('See all'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (cert == null || sets.isLoading && !sets.hasValue)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (sets.hasError)
          ClayCard(
            child: Row(
              children: [
                const Expanded(child: Text('Could not load practice exams.')),
                TextButton(
                  onPressed: () => ref.invalidate(examSetsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (list.isEmpty)
          ClayCard(
            child: Text(
              'New practice exams are coming soon.',
              style: text.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final s in list.take(_previewCount)) _SetCard(set: s, cert: cert),
      ],
    );
  }
}

/// Every practice set of the student's exam level.
class PracticeSetsScreen extends ConsumerWidget {
  const PracticeSetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(examSetsProvider);
    final cert = ref.watch(selectedCertProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Practice exams')),
      body: sets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => MessageView(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load practice exams',
          detail: 'Check your connection and try again.',
          onAction: () => ref.invalidate(examSetsProvider),
        ),
        data: (list) => list.isEmpty || cert == null
            ? const MessageView(
                icon: Icons.quiz_rounded,
                title: 'Coming soon',
                detail: 'New practice exams are on their way.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(examSetsProvider.future),
                child: ContentWidth(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _SetCard(set: list[i], cert: cert),
                  ),
                ),
              ),
      ),
      bottomNavigationBar: const AdBanner(),
    );
  }
}

class _SetCard extends ConsumerWidget {
  const _SetCard({required this.set, required this.cert});

  final ExamSet set;
  final Certification cert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final best = set.bestPercent;
    final status = set.premium
        ? 'locked'
        : best == null
            ? 'not attempted'
            : 'best ${(best * 100).round()} percent';
    final details = [
      if (set.year != null) '${set.year}',
      '${set.questionCount} questions',
      '${set.minutes(cert)} min',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClayCard(
        onTap: () => startPractice(context, ref, set),
        semanticLabel: '${set.title}, $details, $status',
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                set.premium ? Icons.lock_rounded : Icons.assignment_rounded,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(set.title, style: text.titleSmall),
                  Text(
                    details,
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(premium: set.premium, best: best),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.premium, required this.best});

  final bool premium;
  final double? best;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (label, bg, fg) = premium
        ? ('Unlock', scheme.secondaryContainer, scheme.onSecondaryContainer)
        : best == null
            ? ('New', scheme.primaryContainer, scheme.onPrimaryContainer)
            : (
                'Best ${(best! * 100).round()}%',
                best! >= ExamSession.passRatio ? scheme.success.withValues(alpha: 0.16) : scheme.surfaceContainerHighest,
                best! >= ExamSession.passRatio ? scheme.success : scheme.onSurface,
              );
    return DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(label, style: text.titleSmall?.copyWith(color: fg)),
      ),
    );
  }
}

class _StartSheet extends StatelessWidget {
  const _StartSheet({required this.set, required this.cert});

  final ExamSet set;
  final Certification cert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final body = text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant);
    return SafeArea(
      child: ContentWidth(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(set.title, style: text.headlineSmall),
              if (set.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 6),
                Text(set.description!, style: body),
              ],
              const SizedBox(height: 16),
              _Rule(Icons.help_outline_rounded, '${set.questionCount} questions'),
              _Rule(Icons.timer_rounded, '${set.minutes(cert)} minutes, the clock starts now'),
              _Rule(
                Icons.rule_rounded,
                cert.negativeMarking ? 'Wrong answers lose points' : 'No points lost for wrong answers',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text('Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
          ],
        ),
      );
}
