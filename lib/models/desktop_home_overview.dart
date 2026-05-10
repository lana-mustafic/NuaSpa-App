/// Odgovor na `GET Portal/desktop-home-overview`.
class DesktopHomeOverview {
  const DesktopHomeOverview({
    required this.noviKlijentiZadnjih7Dana,
    required this.procijenjeniPrihodZaDan,
    required this.valuta,
  });

  /// `null` kad korisnik nema pravo (npr. nije admin).
  final int? noviKlijentiZadnjih7Dana;
  final double procijenjeniPrihodZaDan;
  final String valuta;

  factory DesktopHomeOverview.fromJson(Map<String, dynamic> json) {
    final n = json['noviKlijentiZadnjih7Dana'];
    return DesktopHomeOverview(
      noviKlijentiZadnjih7Dana: n == null ? null : (n as num).toInt(),
      procijenjeniPrihodZaDan:
          (json['procijenjeniPrihodZaDan'] as num?)?.toDouble() ?? 0,
      valuta: (json['valuta'] as String?) ?? 'KM',
    );
  }
}
