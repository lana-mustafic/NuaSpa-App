import 'package:flutter/material.dart';

/// Prikaz greške pri učitavanju s mreže / API-ja i akcija „Ponovi”.
class LoadRetryPanel extends StatelessWidget {
  const LoadRetryPanel({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'Ne možemo učitati podatke',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: cs.primary.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Ponovi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
