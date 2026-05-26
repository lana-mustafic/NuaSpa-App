import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../ui/theme/luxury_modal_style.dart';

/// Tekstualno polje u luxury modalu — poruka greške ispod kontrole.
class LuxuryModalTextField extends StatelessWidget {
  const LuxuryModalTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.focusNode,
    this.autofillHints,
    this.onChanged,
    this.maxLines,
    this.minHeight = 54,
    this.expands = false,
    this.textAlignVertical,
    this.contentPadding,
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final double minHeight;
  final bool expands;
  final TextAlignVertical? textAlignVertical;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: validator,
      builder: (state) {
        final borderRadius = BorderRadius.circular(16);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              autofillHints: autofillHints,
              maxLines: maxLines,
              expands: expands,
              textAlignVertical: textAlignVertical,
              onChanged: (v) {
                state.didChange(v);
                onChanged?.call(v);
                if (state.hasError) state.validate();
              },
              style: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFFF5F3FA),
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                contentPadding: contentPadding ??
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                constraints: BoxConstraints(minHeight: minHeight),
                enabledBorder: OutlineInputBorder(
                  borderRadius: borderRadius,
                  borderSide: BorderSide(
                    color: state.hasError
                        ? const Color(0xFFFF6B8A)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: borderRadius,
                  borderSide: BorderSide(
                    color: state.hasError
                        ? const Color(0xFFFF6B8A)
                        : LuxuryModalStyle.accentPurple.withValues(alpha: 0.65),
                  ),
                ),
                errorStyle: const TextStyle(height: 0, fontSize: 0),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Text(
                  state.errorText!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.35,
                    color: const Color(0xFFFF6B8A),
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
