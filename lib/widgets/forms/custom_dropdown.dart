import 'package:flutter/material.dart';

class CustomDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged; // Precizniji tip za callback

  const CustomDropdown({
    required this.label,
    required this.items,
    required this.onChanged,
    this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<T>(
        // Ako ti VS Code i dalje podvlači 'value', on misli na FormField.initialValue
        // Ali za DropdownButtonFormField, 'value' je ispravan za trenutno odabranu stavku.
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        ),
        items: items,
        onChanged: onChanged,
        // Dodajemo validator da izbjegnemo potencijalne runtime greške
        validator: (val) => val == null ? 'Polje je obavezno' : null,
      ),
    );
  }
}