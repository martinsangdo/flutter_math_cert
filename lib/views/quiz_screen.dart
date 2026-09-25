import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/providers.dart';
import '../logic/quiz_controller.dart';
import '../models/models.dart';
import 'result_screen.dart';
import 'widgets/ad_banner.dart';
import 'widgets/countdown_text.dart';
import 'widgets/latex_text.dart';
import 'widgets/scratchpad.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

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
    final session = await ref.read(quizProvider.notifier).finish();
    if (!mounted || session == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ResultScreen(session)),
    );
  }

  void _next() {
    _integerController.clear();
    setState(() => _drawing = false);
    ref.read(quizProvider.notifier).next();
  }

  Future<void> _watchAdForHint() async {
    setState(() => _adBusy = true);
    final earned = await ref.read(adServiceProvider).showRewarded();
    if (!mounted) return;
    setState(() => _adBusy = false);
    if (earned) {
      ref.read(quizProvider.notifier).unlockHint();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad not available. Watch it to the end to unlock the hint.')),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final quiz = ref.watch(quizProvider);
    final controller = ref.read(quizProvider.notifier);
    final question = quiz.current;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(question == null ? 'Practice' : 'Question ${quiz.index + 1} / ${quiz.questions.length}'),
          actions: [
            if (quiz.deadline != null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: CountdownText(
                    deadline: quiz.deadline!,
                    format: formatClock,
                    onDone: _finish,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
          ],
          bottom: question == null
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(value: (quiz.index + 1) / quiz.questions.length),
                ),
        ),
        body: _body(quiz, question, controller),
        bottomNavigationBar: question == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: _drawing ? 'Stop drawing' : 'Scratchpad',
                          isSelected: _drawing,
                          icon: const Icon(Icons.edit_outlined),
                          selectedIcon: const Icon(Icons.edit_off_outlined),
                          onPressed: () => setState(() => _drawing = !_drawing),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _submitting ? null : (quiz.isLast ? _finish : _next),
                            child: Text(quiz.isLast ? 'Finish' : 'Next'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const AdBanner(),
                ],
              ),
      ),
    );
  }

  Widget _body(QuizState quiz, Question? question, QuizController controller) {
    if (quiz.loading) return const Center(child: CircularProgressIndicator());
    if (question == null) {
      return Center(
        child: quiz.error == null
            ? const Text('No questions for this contest and grade yet.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load questions.'),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: controller.load, child: const Text('Retry')),
                ],
              ),
      );
    }

    final given = quiz.answers[question.id];
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(question.topicTitle, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              LatexText(question.stem, style: Theme.of(context).textTheme.titleLarge),
              if (question.latex?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                LatexBlock(question.latex!),
              ],
              if (question.imageUrl?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                Image.network(
                  question.imageUrl!,
                  height: 200,
                  cacheWidth: 720, // decode small: keeps RAM low on 2GB phones
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ],
              const SizedBox(height: 24),
              if (question.type == QuestionType.mcq)
                for (final option in question.options)
                  _OptionTile(
                    label: option.key,
                    latex: option.value,
                    selected: given == option.key,
                    onTap: () => controller.answer(option.key),
                  )
              else
                TextField(
                  controller: _integerController,
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[-0-9]'))],
                  decoration: const InputDecoration(
                    labelText: 'Your answer (integer)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: controller.answer,
                ),
              const SizedBox(height: 24),
              _hint(quiz, question),
            ],
          ),
        ),
        Positioned.fill(child: ScratchPad(key: ValueKey(question.id), enabled: _drawing)),
      ],
    );
  }

  Widget _hint(QuizState quiz, Question question) {
    if (!quiz.hinted.contains(question.id)) {
      return OutlinedButton.icon(
        onPressed: _adBusy ? null : _watchAdForHint,
        icon: _adBusy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.ondemand_video),
        label: const Text('Watch ad for step-by-step hint'),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (question.hint?.isNotEmpty ?? false) ...[
              LatexText(question.hint!),
              const SizedBox(height: 8),
            ],
            LatexText(question.solution),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.latex,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String latex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(radius: 14, child: Text(label)),
                const SizedBox(width: 12),
                Expanded(child: LatexText(latex)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
