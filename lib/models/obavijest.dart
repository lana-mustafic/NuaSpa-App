class Obavijest {
  final int id;
  final String naslov;
  final String tekst;
  final String? slikaUrl;
  final DateTime datumObjave;
  final bool aktivna;

  const Obavijest({
    required this.id,
    required this.naslov,
    required this.tekst,
    this.slikaUrl,
    required this.datumObjave,
    required this.aktivna,
  });

  factory Obavijest.fromJson(Map<String, dynamic> json) {
    return Obavijest(
      id: (json['id'] as num).toInt(),
      naslov: json['naslov'] as String? ?? '',
      tekst: json['tekst'] as String? ?? '',
      slikaUrl: json['slikaUrl'] as String?,
      datumObjave: DateTime.parse(json['datumObjave'] as String),
      aktivna: json['aktivna'] as bool? ?? true,
    );
  }

  String get excerpt {
    final trimmed = tekst.trim();
    if (trimmed.length <= 140) return trimmed;
    return '${trimmed.substring(0, 140).trim()}…';
  }

  String get publishedLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final d = datumObjave.toLocal();
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
