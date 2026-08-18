import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/notifications_panel.dart';

/// Full-screen list of system notifications (bookings, payments, etc.).
class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

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
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              Expanded(
                child: NotificationListTheme(
                  colors: NotificationListColors.dark,
                  child: NotificationListBody(
                    provider: provider,
                    items: provider.notifikacije,
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
