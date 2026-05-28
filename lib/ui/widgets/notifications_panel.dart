import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sistemska_notifikacija.dart';
import '../../providers/notification_provider.dart';
import '../../screens/news/obavijesti_screen.dart';
import '../theme/nua_luxury_tokens.dart';

/// Bottom sheet: scrollable notifications + sticky "Obavijesti" action.
class NotificationsBottomSheet extends StatelessWidget {
  const NotificationsBottomSheet({
    super.key,
    this.backgroundColor,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 24),
    this.maxHeightFactor = 0.85,
  });

  final Color? backgroundColor;
  final EdgeInsets padding;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.sizeOf(context).height * maxHeightFactor;

    return SafeArea(
      child: Padding(
        padding: padding,
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(
                child: NotificationsPanel(expandList: true),
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ObavijestiScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.newspaper_outlined),
                label: const Text('Obavijesti (novosti)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationsPanel extends StatelessWidget {
  const NotificationsPanel({
    super.key,
    this.expandList = false,
    this.listHeight = 360,
  });

  /// When true, the notification list fills remaining parent height (use inside
  /// a bounded [Column] with [Expanded]).
  final bool expandList;

  /// Used only when [expandList] is false.
  final double listHeight;

  static IconData iconForTip(String tip) {
    return switch (tip) {
      '5' || 'PlacanjeUspjesno' => Icons.payments_outlined,
      '6' || 'PlacanjeRefundirano' => Icons.currency_exchange,
      '2' || 'RezervacijaOtkazana' => Icons.cancel_outlined,
      '1' || 'RezervacijaPotvrdena' => Icons.check_circle_outline,
      '3' || 'RezervacijaZavrsena' => Icons.done_all,
      _ => Icons.notifications_outlined,
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final items = provider.notifikacije;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Notifikacije',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF5F3FA),
              ),
            ),
            const Spacer(),
            if (provider.unreadCount > 0)
              TextButton(
                onPressed: () => provider.markAllRead(),
                child: const Text('Označi sve pročitano'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Automatski osvježavanje svakih 15 sekundi.',
          style: TextStyle(
            fontSize: 13,
            color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        if (expandList)
          Expanded(
            child: _buildList(context, provider, items),
          )
        else
          SizedBox(
            height: listHeight,
            child: _buildList(context, provider, items),
          ),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    NotificationProvider provider,
    List<SistemskaNotifikacija> items,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          provider.loading ? 'Učitavanje…' : 'Nema notifikacija.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) => _NotificationTile(item: items[i]),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final SistemskaNotifikacija item;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NotificationProvider>();
    final unread = !item.procitana;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: unread ? () => provider.markRead(item.id) : null,
      leading: Icon(
        NotificationsPanel.iconForTip(item.tip),
        color: unread
            ? NuaLuxuryTokens.champagneGold
            : Colors.white.withValues(alpha: 0.45),
      ),
      title: Text(
        item.naslov,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
          color: const Color(0xFFF5F3FA),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            item.tekst,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            NotificationsPanel.formatDt(item.datumVrijeme),
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
      trailing: unread
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFEC4899),
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
