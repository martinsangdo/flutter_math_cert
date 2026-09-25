import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'widgets/app_logo.dart';
import 'widgets/bottom_bar.dart';
import 'widgets/clay_card.dart';
import 'widgets/content_width.dart';
import 'widgets/message_view.dart';

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
    final changing = Navigator.of(context).canPop();
    return Scaffold(
      appBar: changing ? AppBar() : null,
      body: SafeArea(
        child: certs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => MessageView(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load contests',
            detail: kDebugMode ? '$e' : 'Check your connection and try again.',
            onAction: () => ref.invalidate(certificationsProvider),
          ),
          data: (list) => _content(list, changing),
        ),
      ),
      bottomNavigationBar: certs.hasValue ? _bottom(certs.requireValue, changing) : null,
    );
  }

  Widget _content(List<Certification> certs, bool changing) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ContentWidth(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!changing) ...[const AppLogo(size: 56), const SizedBox(height: 16)],
                  Text(changing ? 'Change contest' : 'Welcome to MathPathway', style: text.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Pick the contest you are training for.',
                    style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisExtent: 184,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: certs.length,
              itemBuilder: (_, i) => _ContestCard(
                cert: certs[i],
                accent: AppTheme.accents[i % AppTheme.accents.length],
                selected: certs[i].id == _certId,
                onTap: () => _pick(certs[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottom(List<Certification> certs, bool changing) {
    final selected = certs.where((c) => c.id == _certId).firstOrNull;
    final minGrade = selected?.minGrade ?? 1;
    final maxGrade = max(minGrade, selected?.maxGrade ?? 12);
    return BottomBar(
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<int>(
              key: ValueKey(_certId),
              initialValue: _grade,
              borderRadius: BorderRadius.circular(16),
              decoration: const InputDecoration(labelText: 'Grade'),
              items: [
                for (var g = minGrade; g <= maxGrade; g++)
                  DropdownMenuItem(value: g, child: Text('Grade $g')),
              ],
              onChanged: selected == null ? null : (g) => setState(() => _grade = g ?? _grade),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: selected == null ? null : _continue,
              child: Text(changing ? 'Save' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContestCard extends StatelessWidget {
  const _ContestCard({
    required this.cert,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final Certification cert;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ClayCard(
      onTap: onTap,
      selected: selected,
      semanticLabel: '${cert.id}, ${cert.fullName}',
      color: selected ? scheme.primaryContainer : null,
      borderColor: selected ? scheme.primary : null,
      borderWidth: selected ? 3 : 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: accent.withValues(alpha: 0.18),
                child: Icon(Icons.emoji_events_rounded, color: accent, size: 22),
              ),
              const Spacer(),
              if (selected) Icon(Icons.check_circle_rounded, color: scheme.primary),
            ],
          ),
          const Spacer(),
          Text(cert.id, style: text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            cert.fullName,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(
              color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
