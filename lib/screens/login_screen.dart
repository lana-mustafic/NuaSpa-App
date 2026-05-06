import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/platform/nua_spa_platform.dart';
import '../providers/auth_provider.dart';
import '../ui/theme/mobile_spa_theme.dart';
import '../ui/widgets/glass_panel.dart';
import '../ui/widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();

      bool success = await authProvider.login(
        _usernameController.text,
        _passwordController.text,
      );

      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pogrešno korisničko ime ili lozinka!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final status = auth.status;
    final mobile = nuaspaUseMobileShell();

    final info = auth.infoMessage;
    if (info != null && info.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(info)),
        );
        context.read<AuthProvider>().consumeInfoMessage();
      });
    }

    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mobile) ...[
            Text(
              'NuaSpa',
              textAlign: TextAlign.center,
              style: tt.headlineSmall?.copyWith(letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Relax. Renew. Rejuvenate.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: MobileSpaColors.royalPurple.withValues(alpha: 0.48),
                letterSpacing: 0.35,
              ),
            ),
            const SizedBox(height: 28),
          ] else ...[
            Row(
              children: [
                Icon(Icons.spa_outlined, size: 26, color: scheme.primary),
                const SizedBox(width: 10),
                Text(
                  'NuaSpa',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Text(
            'Prijava',
            textAlign: mobile ? TextAlign.center : TextAlign.start,
            style: mobile ? tt.headlineMedium : tt.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Unesite korisničko ime i lozinku da nastavite.',
            textAlign: mobile ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Korisničko ime',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Unesite korisničko ime';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Lozinka',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _isPasswordVisible
                    ? 'Sakrij lozinku'
                    : 'Prikaži lozinku',
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Unesite lozinku';
              }
              if (value.length < 3) return 'Lozinka je prekratka';
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 18),
          if (status == AuthStatus.authenticating)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else
            PrimaryButton(
              label: 'Prijavi se',
              icon: Icons.login,
              tooltip: 'Prijava na račun',
              onPressed: _submit,
            ),
        ],
      ),
    );

    final scrollChild = mobile
        ? ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: MobileSpaColors.lavender.withValues(alpha: 0.42),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MobileSpaColors.royalPurple.withValues(alpha: 0.07),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(26),
                child: form,
              ),
            ),
          )
        : GlassPanel(child: form);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: mobile
                    ? [
                        MobileSpaColors.softWhite,
                        MobileSpaColors.lavender.withValues(alpha: 0.38),
                        MobileSpaColors.softWhite,
                      ]
                    : [
                        Theme.of(context).scaffoldBackgroundColor,
                        scheme.surface,
                        scheme.surface,
                      ],
              ),
            ),
          ),
          if (mobile) ...[
            Positioned(
              right: -70,
              top: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MobileSpaColors.lavender.withValues(alpha: 0.45),
                ),
              ),
            ),
            Positioned(
              left: -90,
              bottom: 40,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MobileSpaColors.royalPurple.withValues(alpha: 0.06),
                ),
              ),
            ),
          ] else ...[
            Positioned(
              left: -120,
              top: -120,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              right: -140,
              bottom: -140,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.secondary.withValues(alpha: 0.08),
                ),
              ),
            ),
          ],
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: mobile ? 420 : 440),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: scrollChild,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
