import 'package:flutter/material.dart';

class OverviewStatCard extends StatelessWidget {
  const OverviewStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = accent ?? theme.colorScheme.primary;
    return Material(
      color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 26, color: ac.withValues(alpha: 0.95)),
              const SizedBox(height: 14),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 0.2,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
