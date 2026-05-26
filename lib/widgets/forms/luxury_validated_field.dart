import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Polje u luxury stilu s porukom greške ispod kontrole (ne unutar inputa).
class LuxuryValidatedField extends StatelessWidget {
  const LuxuryValidatedField({
    super.key,
    required this.icon,
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.hint = '',
    this.enabled = true,
    this.suffix,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String hint;
  final bool enabled;
  final Widget? suffix;

  static const Color _lavender = Color(0xFFC8B6E8);
  static const Color _textPrimary = Color(0xFFF5F3FA);

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: controller.text,
      validator: validator,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: state.hasError
                      ? Colors.red.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.04),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: _lavender.withValues(alpha: 0.7)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 88,
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      enabled: enabled,
                      keyboardType: keyboardType,
                      obscureText: obscureText,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: hint,
                        hintStyle: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.32),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 2),
                        errorStyle: const TextStyle(height: 0, fontSize: 0),
                        suffixIcon: suffix,
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      onChanged: (v) {
                        state.didChange(v);
                        if (state.hasError) state.validate();
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 6, right: 4),
                child: Text(
                  state.errorText!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.red.shade300,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
