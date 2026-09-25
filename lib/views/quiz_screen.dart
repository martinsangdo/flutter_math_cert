import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/providers.dart';
import '../logic/quiz_controller.dart';
import '../models/models.dart';
import 'result_screen.dart';
import 'widgets/ad_banner.dart';
import 'widgets/bottom_bar.dart';
import 'widgets/clay_card.dart';
import 'widgets/content_width.dart';
import 'widgets/countdown.dart';
import 'widgets/latex_text.dart';
import 'widgets/question_image.dart';
import 'widgets/message_view.dart';
import 'widgets/scratchpad.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen(this.set, {super.key});

  final ExamSet set;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final _integerController = TextEditingController();
  var _drawing = false;
  var _adBusy = false;
  var _submitting = false;

  @override
  void dispose() {
    _integerController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final session = await ref.read(quizProvider(widget.set).notifier).finish();
    if (!mounted || session == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ResultScreen(session, widget.set)),
    );
  }

  void _next() {
    _integerController.clear();
    setState(() => _drawing = false);
    ref.read(quizProvider(widget.set).notifier).next();
  }

  Future<void> _watchAdForHint() async {
    setState(() => _adBusy = true);
    final earned = await ref.read(adServiceProvider).showRewarded();
    if (!mounted) return;
    setState(() => _adBusy = false);
    if (earned) {
      ref.read(quizProvider(widget.set).notifier).unlockHint();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ad not available. Watch it to the end to unlock the hint.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the exam?'),
        content: const Text('Your answers will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final quiz = ref.watch(quizProvider(widget.set));
    final controller = ref.read(quizProvider(widget.set).notifier);
    final question = quiz.current;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Leave exam',
            icon: const Icon(Icons.close_rounded),
            onPressed: _confirmExit,
          ),
          title: Text(
            question == null
                ? 'Practice'
                : 'Question ${quiz.index + 1} of ${quiz.questions.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          actions: [
            if (quiz.deadline != null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Countdown(
                  deadline: quiz.deadline!,
                  onDone: _finish,
                  builder: (_, remaining) => _TimerPill(remaining),
                ),
              ),
          ],
        ),
        body: _body(quiz, question, controller),
        bottomNavigationBar: question == null
            ? null
            : BottomBar(
                footer: const AdBanner(),
                child: Row(
                  children: [
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(64, 56),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer,
                      ),
                      onPressed: () => setState(() => _drawing = !_drawing),
                      icon: Icon(
                        _drawing ? Icons.check_rounded : Icons.draw_rounded,
                      ),
                      label: Text(_drawing ? 'Done' : 'Draw'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _submitting
                            ? null
                            : (quiz.isLast ? _finish : _next),
                        icon: Icon(
                          quiz.isLast
                              ? Icons.flag_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                        iconAlignment: IconAlignment.end,
                        label: Text(quiz.isLast ? 'Finish' : 'Next'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _body(QuizState quiz, Question? question, QuizController controller) {
    if (quiz.loading) return const Center(child: CircularProgressIndicator());
    if (question == null) {
      return quiz.error == null
          ? const MessageView(
              icon: Icons.quiz_rounded,
              title: 'No questions yet',
              detail:
                  'This practice exam has no questions yet. Check back soon.',
            )
          : MessageView(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load questions',
              detail: 'Check your connection and try again.',
              onAction: controller.load,
            );
    }

    final given = quiz.answers[question.id];
    return ContentWidth(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ExcludeSemantics(
              child: LinearProgressIndicator(
                value: (quiz.index + 1) / quiz.questions.length,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _QuestionCard(question),
                      const SizedBox(height: 20),
                      if (question.type == QuestionType.mcq)
                        for (final option in question.options)
                          _OptionTile(
                            letter: option.key,
                            latex: option.value,
                            selected: given == option.key,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              controller.answer(option.key);
                            },
                          )
                      else
                        ClayCard(
                          padding: const EdgeInsets.all(12),
                          child: TextField(
                            controller: _integerController,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp('[-0-9]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Type your answer (a whole number)',
                            ),
                            onChanged: controller.answer,
                          ),
                        ),
                      const SizedBox(height: 20),
                      _hint(quiz, question),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: ScratchPad(
                    key: ValueKey(question.id),
                    enabled: _drawing,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hint(QuizState quiz, Question question) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (!quiz.hinted.contains(question.id)) {
      return Column(
        children: [
          OutlinedButton.icon(
            onPressed: _adBusy ? null : _watchAdForHint,
            icon: _adBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : const Icon(Icons.play_circle_rounded),
            label: const Text('Watch an ad for a hint'),
          ),
          const SizedBox(height: 6),
          Text(
            'Unlocks the hint and the step-by-step solution.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    final body = text.bodyLarge?.copyWith(
      color: scheme.onSecondaryContainer,
      fontSize: 17,
    );
    return ClayCard(
      color: scheme.secondaryContainer,
      borderColor: scheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question.hint?.isNotEmpty ?? false) ...[
            _HintHeader(
              icon: Icons.lightbulb_rounded,
              label: 'Hint',
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(height: 6),
            LatexText(question.hint!, style: body),
            const SizedBox(height: 14),
          ],
          _HintHeader(
            icon: Icons.stairs_rounded,
            label: 'Step-by-step solution',
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(height: 6),
          LatexText(question.solution, style: body),
        ],
      ),
    );
  }
}

class _HintHeader extends StatelessWidget {
  const _HintHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 8),
      Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
      ),
    ],
  );
}

class _TimerPill extends StatelessWidget {
  const _TimerPill(this.remaining);

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final urgent = remaining < const Duration(minutes: 1);
    final fg = urgent ? scheme.onErrorContainer : scheme.onPrimaryContainer;
    return Semantics(
      label:
          'Time left ${remaining.inMinutes} minutes ${remaining.inSeconds % 60} seconds',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: urgent ? scheme.errorContainer : scheme.primaryContainer,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_rounded, size: 20, color: fg),
              const SizedBox(width: 4),
              Text(
                formatClock(remaining),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: fg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard(this.question);

  final Question question;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ClayCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: _Chip(
                  label: question.topicTitle,
                  background: scheme.tertiaryContainer,
                  foreground: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              _Chip(
                label:
                    '${_fmt(question.points)} pt${question.points == 1 ? '' : 's'}',
                background: scheme.primaryContainer,
                foreground: scheme.onPrimaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LatexText(
            question.stem,
            style: text.bodyLarge?.copyWith(fontSize: 20, height: 1.45),
          ),
          if (question.latex?.isNotEmpty ?? false) ...[
            const SizedBox(height: 14),
            LatexBlock(question.latex!),
          ],
          if (question.imageUrl?.isNotEmpty ?? false) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: QuestionImage(question.imageUrl!),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: foreground, fontSize: 14),
      ),
    ),
  );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.latex,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String latex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClayCard(
        onTap: onTap,
        selected: selected,
        semanticLabel: 'Option $letter, ${latex.replaceAll(r'$', '')}',
        color: selected ? scheme.primaryContainer : null,
        borderColor: selected ? scheme.primary : null,
        borderWidth: selected ? 3 : 2,
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: selected
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              foregroundColor: selected ? scheme.onPrimary : scheme.onSurface,
              child: Text(
                letter,
                style: text.titleSmall?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: LatexText(
                latex,
                style: text.bodyLarge?.copyWith(
                  fontSize: 18,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
