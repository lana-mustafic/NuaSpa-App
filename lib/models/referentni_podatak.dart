class ReferentniPodatak {
  final int id;
  final String naziv;

  ReferentniPodatak({required this.id, required this.naziv});

  factory ReferentniPodatak.fromJson(Map<String, dynamic> json) {
    return ReferentniPodatak(
      id: json['id'] ?? 0,
      naziv: json['naziv'] ?? json['name'] ?? 'Nepoznato',
    );
  }

  // Ovo nam treba da bi Dropdown znao uporediti objekte
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReferentniPodatak && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}