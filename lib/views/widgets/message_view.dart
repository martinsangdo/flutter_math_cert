import 'package:flutter/material.dart';

/// Friendly full-area message for errors and empty states.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: scheme.primaryContainer,
              child: Icon(icon, size: 44, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 20),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            if (detail != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                detail!,
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel ?? 'Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
