import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../ui/theme/nua_luxury_tokens.dart';
import '../../ui/widgets/luxury/luxury_glass_panel.dart';

class LuxurySettingsScreen extends StatelessWidget {
  const LuxurySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: LuxuryGlassPanel(
            blurSigma: 26,
            opacity: 0.42,
            borderRadius: NuaLuxuryTokens.radiusXl,
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Settings',
                  style: t.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign out and session controls. Tenant & billing arrive in a later sprint.',
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: t.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 28),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.verified_user_outlined,
                      color: NuaLuxuryTokens.lavenderWhisper),
                  title: const Text('Authenticated account'),
                  subtitle: Text(auth.displayName ?? 'Signed in'),
                ),
                const Divider(height: 36),
                OutlinedButton.icon(
                  onPressed: () => auth.logout(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
