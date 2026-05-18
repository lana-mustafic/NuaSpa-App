import 'package:flutter/material.dart';

import '../../models/kategorija_usluga.dart';
import '../theme/mobile_spa_theme.dart';

/// Horizontalna traka za filtriranje usluga po kategoriji.
class ServiceCategoryFilterBar extends StatelessWidget {
  const ServiceCategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
    this.variant = ServiceCategoryFilterVariant.desktop,
  });

  final List<KategorijaUsluga> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onSelected;
  final ServiceCategoryFilterVariant variant;

  static const String _allLabel = 'Sve usluge';

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = <({int? id, String label})>[
      (id: null, label: _allLabel),
      ...categories.map((c) => (id: c.id, label: c.naziv)),
    ];

    return SizedBox(
      height: variant == ServiceCategoryFilterVariant.mobile ? 48 : 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: variant == ServiceCategoryFilterVariant.mobile
            ? const EdgeInsets.fromLTRB(20, 16, 20, 0)
            : EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, _) => SizedBox(
          width: variant == ServiceCategoryFilterVariant.mobile ? 10 : 8,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = selectedCategoryId == item.id;
          return variant == ServiceCategoryFilterVariant.mobile
              ? _MobilePill(
                  label: item.label,
                  selected: selected,
                  onTap: () => onSelected(item.id),
                )
              : FilterChip(
                  label: Text(item.label),
                  selected: selected,
                  onSelected: (_) => onSelected(item.id),
                  showCheckmark: false,
                );
        },
      ),
    );
  }
}

enum ServiceCategoryFilterVariant { desktop, mobile }

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
