import 'package:flutter/material.dart';

import '../../models/rezervacija.dart';

/// Jednostavan bar chart — broj aktivnih rezervacija po satu (lokalno vrijeme).
class HourlyOccupancyBars extends StatelessWidget {
  const HourlyOccupancyBars({
    super.key,
    required this.rezervacije,
    this.startHour = 7,
    this.endHour = 21,
  });

  /// Samo aktivne rezervacije (npr. ne otkazane).
  final List<Rezervacija> rezervacije;

  /// Uključivo [startHour], ekskluzivno [endHour] (tipično radni dan).
  final int startHour;
  final int endHour;

  List<int> _buckets() {
    final hours = endHour - startHour;
    final buckets = List<int>.filled(hours > 0 ? hours : 1, 0);
    if (hours <= 0) return buckets;
    for (final r in rezervacije) {
      final l = r.datumRezervacije.toLocal();
      final h = l.hour;
      if (h < startHour || h >= endHour) continue;
      buckets[h - startHour]++;
    }
    return buckets;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buckets = _buckets();
    final maxV = buckets.fold<int>(0, (a, b) => a > b ? a : b).clamp(1, 999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 20,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Zauzetost termina po satima (danas)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < buckets.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _Bar(
                      value: buckets[i],
                      max: maxV,
                      label: (startHour + i).toString().padLeft(2, '0'),
                      color: theme.colorScheme.primary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.max,
    required this.label,
    required this.color,
  });

  final int value;
  final int max;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final h = max == 0 ? 0.0 : value / max;
    return Tooltip(
      message: '$label:00 — $value termina',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: h),
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) {
                return FractionallySizedBox(
                  alignment: Alignment.bottomCenter,
                  heightFactor: t,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          color.withValues(alpha: 0.35),
                          color.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontSize: 10,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
