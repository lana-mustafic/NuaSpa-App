import 'package:flutter/material.dart';
// Provjeri da li je 'nuaspa_app' tačno ime tvog projekta u pubspec.yaml
import 'package:nuaspa_app/widgets/forms/custom_text_field.dart';
import 'package:nuaspa_app/widgets/forms/custom_dropdown.dart';

class UslugaForm extends StatefulWidget {
  const UslugaForm({super.key});

  @override
  State<UslugaForm> createState() => _UslugaFormState();
}

class _UslugaFormState extends State<UslugaForm> {
  final _formKey = GlobalKey<FormState>();
  final _nazivController = TextEditingController();
  final _cijenaController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Scaffold dodajemo jer svaki ekran treba da ima bazu (pozadinu, appbar itd.)
    return Scaffold(
      appBar: AppBar(title: const Text("Nova Usluga")),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600), // Desktop optimizacija
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Dodaj/Uredi Uslugu", 
                  style: Theme.of(context).textTheme.headlineSmall
                ),
                const SizedBox(height: 20),
                
                CustomTextField(
                  label: "Naziv usluge", 
                  controller: _nazivController
                ),
                
                CustomTextField(
                  label: "Cijena", 
                  controller: _cijenaController,
                  // Ako tvoj CustomTextField nema isNumeric, izbriši ovu liniju ispod
                ),
                
                const SizedBox(height: 20),
                
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        print("Spasavam uslugu: ${_nazivController.text}");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Spasi"),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}