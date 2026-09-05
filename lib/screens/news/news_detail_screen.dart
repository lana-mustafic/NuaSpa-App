import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/obavijest.dart';
import '../../ui/theme/mobile_spa_theme.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/service_network_image.dart';

class NewsDetailScreen extends StatelessWidget {
  const NewsDetailScreen({
    super.key,
    required this.item,
    this.luxury = false,
  });

  final Obavijest item;
  final bool luxury;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.slikaUrl != null && item.slikaUrl!.isNotEmpty;
    final titleStyle = luxury
        ? GoogleFonts.manrope(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFF5F3FA),
          )
        : Theme.of(context).textTheme.headlineSmall;
    final bodyStyle = luxury
        ? GoogleFonts.manrope(
            fontSize: 15,
            height: 1.55,
            color: Colors.white.withValues(alpha: 0.82),
          )
        : Theme.of(context).textTheme.bodyMedium;
    final dateStyle = luxury
        ? GoogleFonts.manrope(
            fontSize: 13,
            color: NuaLuxuryTokens.lavenderWhisper.withValues(alpha: 0.7),
          )
        : Theme.of(context).textTheme.bodySmall?.copyWith(
            color: MobileSpaColors.royalPurple.withValues(alpha: 0.55),
          );

    return Scaffold(
      backgroundColor: luxury ? NuaLuxuryTokens.deepIndigo : MobileSpaColors.softWhite,
      appBar: AppBar(
        backgroundColor: luxury ? Colors.transparent : null,
        foregroundColor: luxury ? const Color(0xFFF5F3FA) : null,
        title: const Text('News'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ServiceNetworkImage(imageUrl: item.slikaUrl!),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(item.naslov, style: titleStyle),
          const SizedBox(height: 8),
          Text(item.publishedLabel, style: dateStyle),
          const SizedBox(height: 18),
          Text(item.tekst, style: bodyStyle),
        ],
      ),
    );
  }
}
