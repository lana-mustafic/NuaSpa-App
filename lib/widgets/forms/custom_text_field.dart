import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isNumeric;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.label,
    required this.controller,
    this.isNumeric = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextFormField(
        controller: controller,
        // Ako je isNumeric true, koristimo tastaturu za brojeve (važno za cijene)
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.teal),
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.teal, width: 2.0),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        // Ako nismo proslijedili poseban validator, koristi ovaj osnovni
        validator: validator ?? (value) {
          if (value == null || value.isEmpty) {
            return 'Molimo unesite $label';
          }
          return null;
        },
      ),
    );
  }
}