import 'package:flutter/material.dart';

import '../../models/rezervacija.dart';

/// Boje za statuse. „Premium“ = VIP klijent (API) ili potvrđeno i plaćeno za ovaj termin.
class TherapistSchedulePalette {
  static Color cancelled(BuildContext context) =>
      Theme.of(context).colorScheme.outline.withValues(alpha: 0.55);

  static const Color pendingFill = Color(0x6642A5F5);
  static const Color pendingStroke = Color(0xDD90CAF9);

  static const Color confirmedFill = Color(0x662E7D32);
  static const Color confirmedStroke = Color(0xDD66BB6A);

  static const Color premiumFill = Color(0x665C4813);
  static const Color premiumStroke = Color(0xFFD4AF37);
}

class _Placed {
  _Placed(this.r, this.lane, this.lanes);
  final Rezervacija r;
  final int lane;
  final int lanes;
}

double _minutesFromDayStart(DateTime t, int startHour) {
  final loc = t.toLocal();
  return (loc.hour - startHour) * 60.0 + loc.minute + loc.second / 60.0;
}

bool _overlaps(Rezervacija a, Rezervacija b, int startHour, int durMin) {
  double s(Rezervacija x) =>
      _minutesFromDayStart(x.datumRezervacije, startHour).clamp(0, 1e9);
  final sa = s(a);
  final sb = s(b);
  final ea = sa + durMin;
  final eb = sb + durMin;
  return sa < eb && sb < ea;
}

List<_Placed> _assignLanes(List<Rezervacija> items, int startHour, int durMin) {
  final sorted = [...items.where((r) => !r.isOtkazana)]
    ..sort((a, b) => a.datumRezervacije.compareTo(b.datumRezervacije));
  final stacks = <List<Rezervacija>>[];

  outer:
  for (final r in sorted) {
    for (final stack in stacks) {
      final hits = stack.any(
        (existing) => _overlaps(r, existing, startHour, durMin),
      );
      if (!hits) {
        stack.add(r);
        continue outer;
      }
    }
    stacks.add([r]);
  }

  final out = <_Placed>[];
  final lanes = stacks.isEmpty ? 1 : stacks.length;
  for (var li = 0; li < stacks.length; li++) {
    for (final r in stacks[li]) {
      out.add(_Placed(r, li, lanes));
    }
  }
  return out;
}

class TherapistDayTimeline extends StatelessWidget {
  const TherapistDayTimeline({
    super.key,
    required this.rezervacije,
    required this.selectedId,
    required this.onSelect,
    this.startHour = 7,
    this.endHour = 21,
    this.defaultDurationMinutes = 55,
    this.timelineHeight = 560,
    this.effectiveHourHeight,
  });

  final List<Rezervacija> rezervacije;
  final int? selectedId;
  final ValueChanged<Rezervacija> onSelect;
  final int startHour;
  final int endHour;
  final int defaultDurationMinutes;
  final double timelineHeight;
  final double? effectiveHourHeight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spanMin = ((endHour - startHour).clamp(1, 24)) * 60;
    final hourCount = (endHour - startHour).clamp(1, 24);
    final effectiveHourH =
        effectiveHourHeight ?? (timelineHeight / hourCount).clamp(44.0, 120.0);
    final dayH = hourCount * effectiveHourH;
    final pxPerMinute = dayH / spanMin;

    final placed = _assignLanes(rezervacije, startHour, defaultDurationMinutes);

    Border borderFor(Rezervacija r, bool premium) {
      if (r.isOtkazana) {
        return Border.all(color: TherapistSchedulePalette.cancelled(context));
      }
      if (!r.isPotvrdjena) {
        return Border.all(
          color: TherapistSchedulePalette.pendingStroke,
          width: 1.2,
        );
      }
      if (premium) {
        return Border.all(
          color: TherapistSchedulePalette.premiumStroke,
          width: 2,
        );
      }
      return Border.all(
        color: TherapistSchedulePalette.confirmedStroke,
        width: 1.2,
      );
    }

    Color fillFor(Rezervacija r, bool premium) {
      if (r.isOtkazana) {
        return TherapistSchedulePalette.cancelled(
          context,
        ).withValues(alpha: 0.2);
      }
      if (!r.isPotvrdjena) return TherapistSchedulePalette.pendingFill;
      if (premium) return TherapistSchedulePalette.premiumFill;
      return TherapistSchedulePalette.confirmedFill;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  for (var h = startHour; h < endHour; h++)
                    SizedBox(
                      height: effectiveHourH,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6, top: 6),
                          child: Text(
                            '${h.toString().padLeft(2, '0')}:00',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.62),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final trackW = constraints.maxWidth;
                  const innerPad = 8.0;
                  return SizedBox(
                    height: dayH,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        for (var h = startHour; h < endHour; h++)
                          Positioned(
                            top: (h - startHour) * effectiveHourH,
                            left: 0,
                            right: 0,
                            height: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                          ),
                        ...placed.map((p) {
                          final r = p.r;
                          final premium =
                              r.premiumKlijent || (r.isPotvrdjena && r.isPlacena);
                          final m = _minutesFromDayStart(
                            r.datumRezervacije,
                            startHour,
                          ).clamp(0, spanMin - 0.01);
                          final top = m * pxPerMinute;
                          final hBlock = (defaultDurationMinutes * pxPerMinute)
                              .clamp(32.0, dayH);
                          final colW = (trackW - innerPad * 2) / p.lanes;
                          final leftCol = innerPad + p.lane * colW;
                          final selected =
                              selectedId != null && r.id == selectedId;

                          final block = GestureDetector(
                            onTap: () => onSelect(r),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(11),
                                color: fillFor(r, premium),
                                border: borderFor(r, premium),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: cs.primary.withValues(
                                            alpha: 0.42,
                                          ),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                              child: LayoutBuilder(
                                builder: (_, bc) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${r.datumRezervacije.toLocal().hour.toString().padLeft(2, '0')}:${r.datumRezervacije.toLocal().minute.toString().padLeft(2, '0')}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white.withValues(
                                              alpha: 0.94,
                                            ),
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      r.uslugaNaziv ?? 'Usluga',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (bc.maxHeight > 52)
                                      Text(
                                        r.korisnikIme ?? 'Klijent',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.78,
                                              ),
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );

                          return Positioned(
                            top: top,
                            left: leftCol,
                            width: colW - 6,
                            height: hBlock,
                            child: block,
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
