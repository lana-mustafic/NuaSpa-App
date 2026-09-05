import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/sistemska_notifikacija.dart';
import '../../providers/notification_provider.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/notifications_panel.dart';

enum _NotificationListFilter { all, unread, read }

/// Full-screen list of system notifications (bookings, payments, etc.).
class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  _NotificationListFilter _filter = _NotificationListFilter.all;
  String _query = '';

  List<SistemskaNotifikacija> _visible(List<SistemskaNotifikacija> items) {
    Iterable<SistemskaNotifikacija> filtered = items;
    switch (_filter) {
      case _NotificationListFilter.unread:
        filtered = filtered.where((n) => !n.procitana);
      case _NotificationListFilter.read:
        filtered = filtered.where((n) => n.procitana);
      case _NotificationListFilter.all:
        break;
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((n) {
        return n.naslov.toLowerCase().contains(q) ||
            n.tekst.toLowerCase().contains(q);
      });
    }
    return filtered.toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final items = _visible(provider.notifikacije);

    return Scaffold(
      backgroundColor: const Color(0xFF07040F),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF07040F), Color(0xFF120A24)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: const Color(0xFFF5F3FA),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFF5F3FA),
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bookings, payments, and account activity.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: NuaLuxuryTokens.lavenderWhisper
                                  .withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (provider.unreadCount > 0)
                      TextButton(
                        onPressed: () => provider.markAllRead(),
                        child: Text(
                          'Mark all as read',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: NuaLuxuryTokens.champagneGold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    SegmentedButton<_NotificationListFilter>(
                      segments: const [
                        ButtonSegment(
                          value: _NotificationListFilter.all,
                          label: Text('All'),
                        ),
                        ButtonSegment(
                          value: _NotificationListFilter.unread,
                          label: Text('Unread'),
                        ),
                        ButtonSegment(
                          value: _NotificationListFilter.read,
                          label: Text('Read'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (s) =>
                          setState(() => _filter = s.first),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        style: const TextStyle(color: Color(0xFFF5F3FA)),
                        decoration: InputDecoration(
                          hintText: 'Search title or message…',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              Expanded(
                child: NotificationListTheme(
                  colors: NotificationListColors.dark,
                  child: NotificationListBody(
                    provider: provider,
                    items: items,
                    shrinkWrap: false,
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
