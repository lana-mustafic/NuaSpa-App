import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/forms/custom_text_field.dart';
import '../../widgets/forms/custom_dropdown.dart';
import '../../models/referentni_podatak.dart';
import '../../providers/uloga_provider.dart';
import '../../services/api_service.dart'; // MORAŠ imati ovaj import za PDF

class ZaposlenikForm extends StatefulWidget {
  const ZaposlenikForm({super.key});

  @override
  State<ZaposlenikForm> createState() => _ZaposlenikFormState();
}

class _ZaposlenikFormState extends State<ZaposlenikForm> {
  final _formKey = GlobalKey<FormState>();
  final _imeController = TextEditingController();
  final _prezimeController = TextEditingController();
  
  ReferentniPodatak? _odabranaUloga;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => 
      context.read<UlogaProvider>().fetchUloge()
    );
  }

  @override
  void dispose() {
    _imeController.dispose();
    _prezimeController.dispose();
    super.dispose();
  }

  // Funkcija za PDF Export
  Future<void> _preuzmiIzvjestaj() async {
    // Prikazujemo mali krug dok se skida
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await ApiService().downloadReport();

    if (!mounted) return;
    Navigator.pop(context); // Zatvori krug
  }

  void _spasi() {
    if (_formKey.currentState!.validate() && _odabranaUloga != null) {
      final noviZaposlenik = ReferentniPodatak(
        id: DateTime.now().millisecondsSinceEpoch, 
        naziv: "${_imeController.text} ${_prezimeController.text} (${_odabranaUloga!.naziv})"
      );

      context.read<UlogaProvider>().dodajUlogu(noviZaposlenik);

      _imeController.clear();
      _prezimeController.clear();
      setState(() => _odabranaUloga = null);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Zaposlenik dodan na listu!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Upravljanje Zaposlenicima"), 
        centerTitle: true,
        // OVDJE DODAJEMO DUGME ZA PDF
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _preuzmiIzvjestaj,
            tooltip: "Export PDF",
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Row( 
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_add, size: 50, color: Colors.teal),
                        const SizedBox(height: 20),
                        CustomTextField(label: "Ime", controller: _imeController),
                        CustomTextField(label: "Prezime", controller: _prezimeController),
                        const SizedBox(height: 10),
                        
                        Consumer<UlogaProvider>(
                          builder: (context, provider, child) {
                            if (provider.isLoading) return const CircularProgressIndicator();
                            return CustomDropdown<ReferentniPodatak>(
                              label: "Odaberi ulogu",
                              value: _odabranaUloga,
                              items: provider.uloge.map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(u.naziv),
                              )).toList(),
                              onChanged: (novo) => setState(() => _odabranaUloga = novo),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _spasi,
                            child: const Text("DODAJ NA LISTU"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Pregled zaposlenika",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Consumer<UlogaProvider>(
                      builder: (context, provider, child) {
                        if (provider.uloge.isEmpty && !provider.isLoading) {
                          return const Center(child: Text("Nema dodanih zaposlenika."));
                        }
                        
                        return ListView.builder(
                          itemCount: provider.uloge.length,
                          itemBuilder: (context, index) {
                            final item = provider.uloge[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.teal, 
                                  child: Icon(Icons.person, color: Colors.white)
                                ),
                                title: Text(item.naziv),
                                trailing: const Icon(Icons.check_circle, color: Colors.green),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}