import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/sistemska_notifikacija.dart';
import '../../providers/notification_provider.dart';
import '../../screens/admin/admin_notifications_screen.dart';
import 'notification_localization.dart';
import '../theme/nua_luxury_tokens.dart';

const _panelBg = Color.fromRGBO(18, 10, 36, 0.96);
const _textPrimary = Color(0xFFF5F3FA);
const _purple = Color(0xFF7B4DFF);
const _green = Color(0xFF22C55E);
const _blue = Color(0xFF3B82F6);
const _gold = Color(0xFFD4AF7A);
const _mobilePurple = Color(0xFF2A1244);

/// List/row colors — dark luxury dropdown vs light mobile bottom sheet.
class NotificationListColors {
  const NotificationListColors({
    required this.title,
    required this.titleMuted,
    required this.body,
    required this.timestamp,
    required this.divider,
    required this.emptyIcon,
    required this.skeleton,
    required this.subtitle,
  });

  final Color title;
  final Color titleMuted;
  final Color body;
  final Color timestamp;
  final Color divider;
  final Color emptyIcon;
  final Color skeleton;
  final Color subtitle;

  static const dark = NotificationListColors(
    title: _textPrimary,
    titleMuted: Color(0xC7F5F3FA),
    body: Color(0x94FFFFFF),
    timestamp: Color(0x61FFFFFF),
    divider: Color(0x0FFFFFFF),
    emptyIcon: Color(0x47FFFFFF),
    skeleton: Color(0x0FFFFFFF),
    subtitle: Color(0x99E8E4F0),
  );

  static const light = NotificationListColors(
    title: _mobilePurple,
    titleMuted: Color(0xCC2A1244),
    body: Color(0x992A1244),
    timestamp: Color(0x662A1244),
    divider: Color(0x1A2A1244),
    emptyIcon: Color(0x402A1244),
    skeleton: Color(0x142A1244),
    subtitle: Color(0x8C2A1244),
  );
}

class NotificationListTheme extends InheritedWidget {
  const NotificationListTheme({
    super.key,
    required this.colors,
    required super.child,
  });

  final NotificationListColors colors;

  static NotificationListColors of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<NotificationListTheme>()
            ?.colors ??
        NotificationListColors.dark;
  }

  @override
  bool updateShouldNotify(NotificationListTheme oldWidget) =>
      colors != oldWidget.colors;
}

/// Opens a bell-anchored notification dropdown (desktop admin header).
Future<void> showLuxuryNotificationsDropdown(
  BuildContext context,
  BuildContext anchorContext,
) {
  final box = anchorContext.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return Future.value();

  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return Future.value();

  final anchor = box.localToGlobal(Offset.zero, ancestor: overlay);
  final anchorSize = box.size;
  final screen = MediaQuery.sizeOf(context);
  final padding = MediaQuery.paddingOf(context);

  const panelW = 560.0;
  const maxH = 620.0;
  final width = panelW.clamp(320.0, screen.width * 0.92);
  final rightMargin = 16.0 + padding.right;
  final left = (anchor.dx + anchorSize.width / 2 - width / 2)
      .clamp(padding.left + 16, screen.width - width - rightMargin);
  final top = anchor.dy + anchorSize.height + 12;
  final bellCenterX = anchor.dx + anchorSize.width / 2;
  final arrowLeft = (bellCenterX - left - 9).clamp(24.0, width - 40);

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss notifications',
    barrierColor: Colors.black.withValues(alpha: 0.25),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, _, _) {
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            child: Material(
              color: Colors.transparent,
              child: _NotificationsDropdownShell(
                arrowLeft: arrowLeft,
                maxHeight: maxH,
                onClose: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curve),
          alignment: Alignment.topCenter,
          child: child,
        ),
      );
    },
  );
}

class _NotificationsDropdownShell extends StatelessWidget {
  const _NotificationsDropdownShell({
    required this.arrowLeft,
    required this.maxHeight,
    required this.onClose,
  });

  final double arrowLeft;
  final double maxHeight;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              onClose();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: arrowLeft,
                child: const _DropdownArrow(),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      decoration: BoxDecoration(
                        color: _panelBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 80,
                            offset: const Offset(0, 24),
                          ),
                          BoxShadow(
                            color: _purple.withValues(alpha: 0.18),
                            blurRadius: 48,
                            spreadRadius: -8,
                          ),
                        ],
                      ),
                      child: NotificationsDropdownPanel(onClose: onClose),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownArrow extends StatelessWidget {
  const _DropdownArrow();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 10),
      painter: _ArrowPainter(),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = _panelBg
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bell-anchored dropdown body (desktop).
class NotificationsDropdownPanel extends StatelessWidget {
  const NotificationsDropdownPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final items = provider.notifikacije;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DropdownHeader(
          unreadCount: provider.unreadCount,
          onMarkAllRead: provider.unreadCount > 0
              ? () => provider.markAllRead()
              : null,
        ),
        Flexible(
          child: NotificationListTheme(
            colors: NotificationListColors.dark,
            child: NotificationListBody(
              provider: provider,
              items: items,
            ),
          ),
        ),
        _DropdownFooter(
          onViewAll: () {
            onClose();
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminNotificationsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DropdownHeader extends StatelessWidget {
  const _DropdownHeader({
    required this.unreadCount,
    this.onMarkAllRead,
  });

  final int unreadCount;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Notifications',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _purple.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (onMarkAllRead != null)
                TextButton(
                  onPressed: onMarkAllRead,
                  style: TextButton.styleFrom(
                    foregroundColor: NuaLuxuryTokens.champagneGold,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Mark all as read',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Stay updated on what matters.',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared list area for dropdown and full-screen notifications.
class NotificationListBody extends StatelessWidget {
  const NotificationListBody({
    super.key,
    required this.provider,
    required this.items,
    this.shrinkWrap = true,
  });

  final NotificationProvider provider;
  final List<SistemskaNotifikacija> items;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    if (provider.loading && items.isEmpty) {
      return const _NotificationSkeletonList();
    }
    if (items.isEmpty) {
      return const _NotificationEmptyState();
    }
    final dividerColor = NotificationListTheme.of(context).divider;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      shrinkWrap: shrinkWrap,
      itemCount: items.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 72,
        color: dividerColor,
      ),
      itemBuilder: (context, i) => LuxuryNotificationRow(item: items[i]),
    );
  }
}

class _DropdownFooter extends StatefulWidget {
  const _DropdownFooter({required this.onViewAll});

  final VoidCallback onViewAll;

  @override
  State<_DropdownFooter> createState() => _DropdownFooterState();
}

class _DropdownFooterState extends State<_DropdownFooter> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: _hover
            ? _purple.withValues(alpha: 0.12)
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onViewAll,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: _hover
                      ? _textPrimary
                      : NuaLuxuryTokens.champagneGold.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Text(
                  'View all notifications',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _hover
                        ? _textPrimary
                        : NuaLuxuryTokens.champagneGold.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LuxuryNotificationRow extends StatefulWidget {
  const LuxuryNotificationRow({super.key, required this.item});

  final SistemskaNotifikacija item;

  @override
  State<LuxuryNotificationRow> createState() => _LuxuryNotificationRowState();
}

class _LuxuryNotificationRowState extends State<LuxuryNotificationRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NotificationProvider>();
    final unread = !widget.item.procitana;
    final visual = NotificationsPanel.visualFor(widget.item);
    final title = NotificationLocalization.title(widget.item.naslov);
    final body = NotificationLocalization.body(widget.item.tekst);
    final colors = NotificationListTheme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: _hover
            ? _purple.withValues(alpha: 0.10)
            : Colors.transparent,
        child: InkWell(
          onTap: unread ? () => provider.markRead(widget.item.id) : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              border: unread
                  ? Border(
                      left: BorderSide(
                        color: _purple.withValues(alpha: 0.75),
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: visual.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: visual.color.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Icon(visual.icon, size: 20, color: visual.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w600,
                          color: unread ? colors.title : colors.titleMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w400,
                          color: colors.body,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        NotificationsPanel.formatRelative(widget.item.datumVrijeme),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.timestamp,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, left: 8),
                    decoration: BoxDecoration(
                      color: _purple,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _purple.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = NotificationListTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 36,
            color: colors.emptyIcon,
          ),
          const SizedBox(height: 14),
          Text(
            'No notifications yet',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.title,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You\'re all caught up.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: colors.subtitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSkeletonList extends StatelessWidget {
  const _NotificationSkeletonList();

  @override
  Widget build(BuildContext context) {
    final colors = NotificationListTheme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 72,
        color: colors.divider,
      ),
      itemBuilder: (_, _) => _NotificationSkeletonRow(colors: colors),
    );
  }
}

class _NotificationSkeletonRow extends StatelessWidget {
  const _NotificationSkeletonRow({required this.colors});

  final NotificationListColors colors;

  @override
  Widget build(BuildContext context) {
    Widget block(double w, double h, {double radius = 6}) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: colors.skeleton,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          block(42, 42, radius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(140, 12),
                const SizedBox(height: 8),
                block(double.infinity, 10),
                const SizedBox(height: 6),
                block(64, 9),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mobile bottom sheet — system notifications only.
class NotificationsBottomSheet extends StatelessWidget {
  const NotificationsBottomSheet({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 24),
    this.maxHeightFactor = 0.85,
  });

  final EdgeInsets padding;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final sheetHeight = MediaQuery.sizeOf(context).height * maxHeightFactor;

    return NotificationListTheme(
      colors: NotificationListColors.light,
      child: SafeArea(
        child: Padding(
          padding: padding,
          child: SizedBox(
            height: sheetHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: NotificationListColors.light.title,
                        ),
                      ),
                    ),
                    if (provider.unreadCount > 0)
                      TextButton(
                        onPressed: () => provider.markAllRead(),
                        style: TextButton.styleFrom(
                          foregroundColor: _mobilePurple,
                        ),
                        child: const Text('Mark all as read'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Bookings, payments, and account activity.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: NotificationListColors.light.subtitle,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: NotificationListBody(
                    provider: provider,
                    items: provider.notifikacije,
                    shrinkWrap: false,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _mobilePurple,
                    side: BorderSide(
                      color: _mobilePurple.withValues(alpha: 0.35),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const AdminNotificationsScreen(),
                      ),
                    );
                  },
                  child: const Text('View all notifications'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationVisual {
  const NotificationVisual(this.icon, this.color);

  final IconData icon;
  final Color color;
}

abstract final class NotificationsPanel {
  NotificationsPanel._();

  static IconData iconForTip(String tip) => visualForTip(tip).icon;

  static NotificationVisual visualFor(SistemskaNotifikacija item) {
    final title = NotificationLocalization.title(item.naslov).toLowerCase();
    final body = NotificationLocalization.body(item.tekst).toLowerCase();
    final tip = item.tip;

    if (tip == '5' ||
        tip == 'PlacanjeUspjesno' ||
        title.contains('payment') ||
        body.contains('paid')) {
      return const NotificationVisual(Icons.payments_outlined, _green);
    }
    if (title.contains('review') || body.contains('review') || body.contains('star')) {
      return const NotificationVisual(Icons.star_rounded, _gold);
    }
    if (title.contains('client') || body.contains('added to the system')) {
      return const NotificationVisual(Icons.person_add_alt_1_outlined, _blue);
    }
    if (tip == '2' || tip == 'RezervacijaOtkazana' || title.contains('cancel')) {
      return const NotificationVisual(Icons.cancel_outlined, Color(0xFFEC4899));
    }
    return const NotificationVisual(Icons.event_available_outlined, _purple);
  }

  static NotificationVisual visualForTip(String tip) {
    return switch (tip) {
      '5' || 'PlacanjeUspjesno' => const NotificationVisual(Icons.payments_outlined, _green),
      '6' || 'PlacanjeRefundirano' =>
        const NotificationVisual(Icons.currency_exchange, _gold),
      '2' || 'RezervacijaOtkazana' =>
        const NotificationVisual(Icons.cancel_outlined, Color(0xFFEC4899)),
      '1' || 'RezervacijaPotvrdena' =>
        const NotificationVisual(Icons.check_circle_outline, _purple),
      '3' || 'RezervacijaZavrsena' => const NotificationVisual(Icons.done_all, _purple),
      _ => const NotificationVisual(Icons.notifications_outlined, _purple),
    };
  }

  static String formatDt(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d.$m.${local.year} $h:$min';
  }

  static String formatRelative(DateTime dt) {
    final local = dt.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return m == 1 ? '1 min ago' : '$m min ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return h == 1 ? '1h ago' : '${h}h ago';
    }
    if (diff.inDays < 7) {
      final d = diff.inDays;
      return d == 1 ? '1d ago' : '${d}d ago';
    }
    return formatDt(dt);
  }
}
