import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../providers/notification_provider.dart';
import '../../ui/theme/mobile_spa_theme.dart';
import '../../ui/theme/nua_luxury_tokens.dart';

class ObavijestiScreen extends StatelessWidget {
  const ObavijestiScreen({super.key});

  String _resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api/?$'), '');
    return '$base$path';
  }

  static String _formatDt(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d.$m.${local.year} $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<NotificationProvider>().obavijesti;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
      ),
      body: items.isEmpty
          ? const Center(child: Text('No published announcements.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final o = items[i];
                final imageUrl = _resolveImageUrl(o.slikaUrl);
                return Card(
                  color: NuaLuxuryTokens.voidViolet.withValues(alpha: 0.55),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        if (imageUrl.isNotEmpty) const SizedBox(height: 12),
                        Text(
                          o.naslov,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF5F3FA),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDt(o.datumObjave),
                          style: TextStyle(
                            fontSize: 12,
                            color: MobileSpaColors.royalPurple.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          o.tekst,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
