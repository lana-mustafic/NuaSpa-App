import 'package:flutter/material.dart';

import '../../theme/nua_luxury_tokens.dart';
import 'luxury_glass_panel.dart';
import 'luxury_mini_sparkline.dart';

class LuxuryKpiCard extends StatefulWidget {
  const LuxuryKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.trendLabel,
    this.trendUp,
    required this.icon,
    required this.sparkline,
  });

  final String label;
  final String value;
  final String? subtitle;
  final String? trendLabel;
  final bool? trendUp;
  final IconData icon;
  final List<double> sparkline;

  @override
  State<LuxuryKpiCard> createState() => _LuxuryKpiCardState();
}

class _LuxuryKpiCardState extends State<LuxuryKpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trendColor = widget.trendUp == null
        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
        : widget.trendUp!
            ? const Color(0xFF6EE7B7)
            : const Color(0xFFFF9B9B);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.012 : 1,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: LuxuryGlassPanel(
          borderRadius: NuaLuxuryTokens.radiusXl,
          blurSigma: _hover ? 28 : 20,
          opacity: _hover ? 0.5 : 0.4,
          borderOpacity: _hover ? 0.22 : 0.11,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.18),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                      border: Border.all(
                        color:
                            NuaLuxuryTokens.champagneGold.withValues(alpha: 0.25),
                        width: 0.6,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 22,
                      color: NuaLuxuryTokens.champagneGold,
                    ),
                  ),
                  const Spacer(),
                  if (widget.trendLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: trendColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: trendColor.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.trendUp == true
                                ? Icons.trending_up_rounded
                                : widget.trendUp == false
                                    ? Icons.trending_down_rounded
                                    : Icons.remove_rounded,
                            size: 15,
                            color: trendColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.trendLabel!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: trendColor,
                              letterSpacing: 0.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.48),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: Colors.white.withValues(alpha: 0.95),
                  height: 1.05,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              LuxuryMiniSparkline(values: widget.sparkline),
            ],
          ),
        ),
      ),
    );
  }
}
