import 'package:flutter/material.dart';
import 'package:nuaspa_app/widgets/forms/custom_text_field.dart';

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
  void dispose() {
    // Dobra praksa: uvijek uništi controllere kad se ekran zatvori
    _nazivController.dispose();
    _cijenaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                ),
                
                const SizedBox(height: 20),
                
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // Izmijenjeno: debugPrint umjesto print
                        debugPrint("Spasavam uslugu: ${_nazivController.text}");
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