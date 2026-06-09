import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/admin/therapist_account_status.dart';
import '../../ui/theme/nua_luxury_tokens.dart';

/// Therapist activates portal access (set password) from admin invite link.
class AcceptInviteScreen extends StatefulWidget {
  const AcceptInviteScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _validating = false;
  InviteValidationResult? _validation;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void initState() {
    super.initState();
    final t = widget.initialToken?.trim();
    if (t != null && t.isNotEmpty) {
      _tokenCtrl.text = _extractToken(t);
      _validateToken();
    }
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String _extractToken(String input) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.queryParameters['token'] != null) {
      return uri.queryParameters['token']!;
    }
    return trimmed;
  }

  Future<void> _validateToken() async {
    final token = _extractToken(_tokenCtrl.text);
    if (token.isEmpty) return;
    setState(() {
      _validating = true;
      _validation = null;
    });
    final result = await _api.validateInviteToken(token);
    if (!mounted) return;
    setState(() {
      _validating = false;
      _validation = result;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final token = _extractToken(_tokenCtrl.text);
    setState(() => _loading = true);
    final result = await _api.acceptTherapistInvite(
      token: token,
      password: _passwordCtrl.text,
      confirmPassword: _confirmCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success && result.token != null && result.token!.isNotEmpty) {
      await context.read<AuthProvider>().applySessionToken(
            result.token!,
            username: result.username,
          );
      if (!mounted) return;
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
        width: 420,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = _validation?.valid == true;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF07040F), Color(0xFF120A24)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IconButton(
                          alignment: Alignment.centerLeft,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Activate therapist account',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFF5F3FA),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Paste your invitation link or token, then choose a password for the NuaSpa therapist portal.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.5,
                            color: NuaLuxuryTokens.lavenderWhisper
                                .withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _tokenCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: _fieldDeco(
                            hint: 'Invitation token or full link',
                            icon: Icons.link_rounded,
                          ),
                          onFieldSubmitted: (_) => _validateToken(),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Invitation token is required'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _validating ? null : _validateToken,
                          icon: _validating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.verified_outlined, size: 18),
                          label: const Text('Verify invitation'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: NuaLuxuryTokens.softPurpleGlow
                                  .withValues(alpha: 0.45),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        if (_validation != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: (valid
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFFF97316))
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              valid
                                  ? 'Welcome, ${_validation!.therapistName ?? 'Therapist'}.\n${_validation!.message ?? ''}'
                                  : _validation!.message ??
                                      'Invalid invitation.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.45,
                                color: const Color(0xFFF5F3FA),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure1,
                          style: const TextStyle(color: Colors.white),
                          decoration: _fieldDeco(
                            hint: 'New password',
                            icon: Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(
                                _obscure1
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.white54,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure1 = !_obscure1),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.length < 8) {
                              return 'At least 8 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscure2,
                          style: const TextStyle(color: Colors.white),
                          decoration: _fieldDeco(
                            hint: 'Confirm password',
                            icon: Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(
                                _obscure2
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.white54,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure2 = !_obscure2),
                            ),
                          ),
                          validator: (v) {
                            if (v != _passwordCtrl.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: (_loading || !valid) ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: NuaLuxuryTokens.softPurpleGlow,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Activate & sign in',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDeco({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.white38),
      prefixIcon: Icon(icon, color: NuaLuxuryTokens.softPurpleGlow),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: NuaLuxuryTokens.softPurpleGlow.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}
