import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/providers.dart';
import '../models/models.dart';
import 'home_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String? _certId;
  int _grade = 1;

  @override
  void initState() {
    super.initState();
    final current = ref.read(selectionProvider);
    _certId = current?.certId;
    _grade = current?.grade ?? 1;
  }

  void _pick(Certification cert) => setState(() {
        _certId = cert.id;
        _grade = _grade.clamp(cert.minGrade, cert.maxGrade);
      });

  Future<void> _continue() async {
    await ref.read(selectionProvider.notifier).select(_certId!, _grade);
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacement(MaterialPageRoute<void>(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final certs = ref.watch(certificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your contest')),
      body: SafeArea(
        child: certs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load contests.'),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => ref.invalidate(certificationsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: _content,
        ),
      ),
    );
  }

  Widget _content(List<Certification> certs) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final selected = certs.where((c) => c.id == _certId).firstOrNull;
    final minGrade = selected?.minGrade ?? 1;
    final maxGrade = max(minGrade, selected?.maxGrade ?? 12);

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemCount: certs.length,
            itemBuilder: (_, i) {
              final cert = certs[i];
              return Material(
                color: cert.id == _certId ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _pick(cert),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(cert.id, style: text.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          cert.fullName,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey(_certId),
                  initialValue: _grade,
                  decoration: const InputDecoration(
                    labelText: 'Grade',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (var g = minGrade; g <= maxGrade; g++)
                      DropdownMenuItem(value: g, child: Text('Grade $g')),
                  ],
                  onChanged: selected == null ? null : (g) => setState(() => _grade = g ?? _grade),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: selected == null ? null : _continue,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
