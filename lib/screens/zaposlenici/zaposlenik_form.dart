import 'package:flutter/material.dart';
import '../../widgets/forms/custom_text_field.dart';
import '../../widgets/forms/custom_dropdown.dart';
import '../../models/referentni_podatak.dart';
import '../../services/api_service.dart';

class ZaposlenikForm extends StatefulWidget {
  const ZaposlenikForm({super.key});

  @override
  State<ZaposlenikForm> createState() => _ZaposlenikFormState();
}

class _ZaposlenikFormState extends State<ZaposlenikForm> {
  final _formKey = GlobalKey<FormState>();
  final _imeController = TextEditingController();
  final _prezimeController = TextEditingController();
  
  final ApiService _apiService = ApiService();

  List<ReferentniPodatak> _ulogeList = [];
  ReferentniPodatak? _odabranaUloga;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _ucitajPodatke();
  }

  Future<void> _ucitajPodatke() async {
    final uloge = await _apiService.getUloge();
    setState(() {
      _ulogeList = uloge;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text("Dodaj Zaposlenika"), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Icon(Icons.person_add, size: 50, color: Colors.blue),
                      const SizedBox(height: 20),
                      CustomTextField(label: "Ime", controller: _imeController),
                      CustomTextField(label: "Prezime", controller: _prezimeController),
                      const SizedBox(height: 10),
                      
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        )
                      else
                        CustomDropdown<ReferentniPodatak>(
                          label: "Odaberi ulogu",
                          value: _odabranaUloga,
                          items: _ulogeList.map((u) => DropdownMenuItem(
                            value: u,
                            child: Text(u.naziv),
                          )).toList(),
                          onChanged: (novo) => setState(() => _odabranaUloga = novo),
                        ),
                        
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate() && _odabranaUloga != null) {
                              print("Spreman za slanje: ${_imeController.text} - ${_odabranaUloga!.naziv}");
                            }
                          },
                          child: const Text("SPREMI"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}