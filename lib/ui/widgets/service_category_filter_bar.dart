import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/kategorija_usluga.dart';
import '../theme/mobile_spa_theme.dart';
import '../theme/nua_luxury_tokens.dart';

/// Horizontal category filter strip for the service catalog.
class ServiceCategoryFilterBar extends StatelessWidget {
  const ServiceCategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
    this.variant = ServiceCategoryFilterVariant.desktop,
    this.maxVisible = 6,
  });

  final List<KategorijaUsluga> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onSelected;
  final ServiceCategoryFilterVariant variant;
  final int maxVisible;

  static const String _allLabel = 'All';

  static int _priorityScore(String naziv) {
    final lower = naziv.trim().toLowerCase();
    if (lower.contains('massage')) return 0;
    if (lower.contains('facial') || lower.contains('skincare')) return 1;
    if (lower.contains('body')) return 2;
    if (lower.contains('wellness')) return 3;
    if (lower.contains('beauty')) return 4;
    return 10;
  }

  static String displayLabel(String naziv) {
    final lower = naziv.trim().toLowerCase();
    if (lower.contains('massage')) return 'Massage';
    if (lower.contains('facial') || lower.contains('skincare')) {
      return 'Facials';
    }
    if (lower.contains('body')) return 'Body';
    if (lower.contains('wellness')) return 'Wellness';
    if (lower.contains('beauty')) return 'Beauty';
    final trimmed = naziv.trim();
    if (trimmed.length <= 16) return trimmed;
    return '${trimmed.substring(0, 14).trim()}…';
  }

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = List<KategorijaUsluga>.from(categories)
      ..sort((a, b) {
        final pa = _priorityScore(a.naziv);
        final pb = _priorityScore(b.naziv);
        if (pa != pb) return pa.compareTo(pb);
        return a.naziv.compareTo(b.naziv);
      });

    final visibleCap = maxVisible <= 1 ? 1 : maxVisible - 1;
    final visible = sorted.take(visibleCap).toList();
    final overflow = sorted.skip(visibleCap).toList();
    final overflowSelected =
        overflow.any((c) => c.id == selectedCategoryId);

    if (variant == ServiceCategoryFilterVariant.mobile) {
      return SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          itemCount: sorted.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _MobilePill(
                label: 'All services',
                selected: selectedCategoryId == null,
                onTap: () => onSelected(null),
              );
            }
            final cat = sorted[index - 1];
            return _MobilePill(
              label: displayLabel(cat.naziv),
              selected: selectedCategoryId == cat.id,
              onTap: () => onSelected(cat.id),
            );
          },
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: visible.length + 1 + (overflow.isNotEmpty ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _LuxuryChip(
              label: _allLabel,
              selected: selectedCategoryId == null,
              onTap: () => onSelected(null),
            );
          }

          final overflowIndex = visible.length + 1;
          if (overflow.isNotEmpty && index == overflowIndex) {
            return _MoreCategoriesChip(
              overflow: overflow,
              selectedCategoryId: selectedCategoryId,
              overflowSelected: overflowSelected,
              onSelected: onSelected,
            );
          }

          final cat = visible[index - 1];
          return _LuxuryChip(
            label: displayLabel(cat.naziv),
            selected: selectedCategoryId == cat.id,
            onTap: () => onSelected(cat.id),
          );
        },
      ),
    );
  }
}

enum ServiceCategoryFilterVariant { desktop, mobile }

class _LuxuryChip extends StatelessWidget {
  const _LuxuryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF9B7BFF).withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.1),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: NuaLuxuryTokens.softPurpleGlow
                          .withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? const Color(0xFFF5F3FA)
                  : Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreCategoriesChip extends StatelessWidget {
  const _MoreCategoriesChip({
    required this.overflow,
    required this.selectedCategoryId,
    required this.overflowSelected,
    required this.onSelected,
  });

  final List<KategorijaUsluga> overflow;
  final int? selectedCategoryId;
  final bool overflowSelected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'More categories',
      offset: const Offset(0, 44),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      color: const Color(0xFF1A1228),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      onSelected: onSelected,
      itemBuilder: (ctx) => overflow
          .map(
            (c) => PopupMenuItem<int>(
              value: c.id,
              child: Text(
                ServiceCategoryFilterBar.displayLabel(c.naziv),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: selectedCategoryId == c.id
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: selectedCategoryId == c.id
                      ? const Color(0xFF9B7BFF)
                      : Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ),
          )
          .toList(),
      child: _LuxuryChip(
        label: overflowSelected
            ? ServiceCategoryFilterBar.displayLabel(
                overflow.firstWhere((c) => c.id == selectedCategoryId).naziv,
              )
            : 'More',
        selected: overflowSelected,
        onTap: () {},
      ),
    );
  }
}

class _MobilePill extends StatelessWidget {
  const _MobilePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? MobileSpaColors.royalPurple
              : MobileSpaColors.lavender.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? MobileSpaColors.royalPurple
                : MobileSpaColors.lavender.withValues(alpha: 0.5),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: MobileSpaColors.royalPurple.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? Colors.white
                    : MobileSpaColors.royalPurple.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
        ),
      ),
    );
  }
}
