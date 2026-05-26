import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sistemska_notifikacija.dart';
import '../../providers/notification_provider.dart';
import '../theme/nua_luxury_tokens.dart';

class NotificationsPanel extends StatelessWidget {
  const NotificationsPanel({super.key});

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
        SizedBox(
          height: 360,
          child: items.isEmpty
              ? Center(
                  child: Text(
                    provider.loading ? 'Učitavanje…' : 'Nema notifikacija.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _NotificationTile(item: items[i]),
                ),
        ),
      ],
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
