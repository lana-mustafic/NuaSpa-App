class AdminReviewQuote {
  const AdminReviewQuote({
    required this.tekst,
    required this.autor,
    required this.ocjena,
  });

  final String tekst;
  final String autor;
  final int ocjena;

  factory AdminReviewQuote.fromJson(Map<String, dynamic> json) {
    return AdminReviewQuote(
      tekst: (json['tekst'] as String?) ?? '',
      autor: (json['autor'] as String?) ?? '',
      ocjena: (json['ocjena'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminReviewRow {
  const AdminReviewRow({
    required this.id,
    required this.createdAt,
    required this.ocjena,
    required this.komentar,
    required this.korisnikPunoIme,
    required this.brojPosjeta,
    required this.uslugaNaziv,
    required this.terapeutIme,
    required this.izvor,
    this.adminOdgovor,
  });

  final int id;
  final DateTime createdAt;
  final int ocjena;
  final String komentar;
  final String korisnikPunoIme;
  final int brojPosjeta;
  final String uslugaNaziv;
  final String? terapeutIme;
  final String izvor;
  final String? adminOdgovor;

  factory AdminReviewRow.fromJson(Map<String, dynamic> json) {
    return AdminReviewRow(
      id: (json['id'] as num).toInt(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '') as String) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ocjena: (json['ocjena'] as num?)?.toInt() ?? 0,
      komentar: (json['komentar'] as String?) ?? '',
      korisnikPunoIme: (json['korisnikPunoIme'] as String?) ?? '',
      brojPosjeta: (json['brojPosjeta'] as num?)?.toInt() ?? 0,
      uslugaNaziv: (json['uslugaNaziv'] as String?) ?? '',
      terapeutIme: json['terapeutIme'] as String?,
      izvor: (json['izvor'] as String?) ?? 'NuaSpa',
      adminOdgovor: json['adminOdgovor'] as String?,
    );
  }
}

class AdminTopUslugaOcjena {
  const AdminTopUslugaOcjena({required this.naziv, required this.prosjek});

  final String naziv;
  final double prosjek;

  factory AdminTopUslugaOcjena.fromJson(Map<String, dynamic> json) {
    return AdminTopUslugaOcjena(
      naziv: (json['naziv'] as String?) ?? '',
      prosjek: (json['prosjek'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdminReviewsDashboard {
  const AdminReviewsDashboard({
    required this.ukupno,
    required this.stranica,
    required this.velicinaStranice,
    required this.redovi,
    required this.prosjecnaOcjena,
    required this.prosjecnaOcjenaPrethodno,
    required this.ukupnoPrethodno,
    required this.postotakPozitivnih,
    required this.postotakPozitivnihPrethodno,
    required this.postotakOdgovora,
    required this.postotakOdgovoraPrethodno,
    required this.distribucijaOcjena,
    required this.topUsluge,
    required this.istaknutaRecenzija,
  });

  final int ukupno;
  final int stranica;
  final int velicinaStranice;
  final List<AdminReviewRow> redovi;
  final double prosjecnaOcjena;
  final double? prosjecnaOcjenaPrethodno;
  final int ukupnoPrethodno;
  final double postotakPozitivnih;
  final double? postotakPozitivnihPrethodno;
  final double? postotakOdgovora;
  final double? postotakOdgovoraPrethodno;
  final Map<int, int> distribucijaOcjena;
  final List<AdminTopUslugaOcjena> topUsluge;
  final AdminReviewQuote? istaknutaRecenzija;

  int get totalPages =>
      ukupno <= 0 ? 1 : ((ukupno + velicinaStranice - 1) / velicinaStranice).ceil();

  factory AdminReviewsDashboard.fromJson(Map<String, dynamic> json) {
    final rawDist = json['distribucijaOcjena'];
    final dist = <int, int>{};
    if (rawDist is Map) {
      rawDist.forEach((k, v) {
        final key = int.tryParse(k.toString());
        if (key != null && key >= 1 && key <= 5) {
          dist[key] = (v as num?)?.toInt() ?? 0;
        }
      });
    }
    for (var s = 1; s <= 5; s++) {
      dist.putIfAbsent(s, () => 0);
    }

    final rawRows = json['redovi'];
    final rows = <AdminReviewRow>[];
    if (rawRows is List) {
      for (final e in rawRows) {
        if (e is Map<String, dynamic>) {
          rows.add(AdminReviewRow.fromJson(e));
        }
      }
    }

    final rawTop = json['topUsluge'];
    final top = <AdminTopUslugaOcjena>[];
    if (rawTop is List) {
      for (final e in rawTop) {
        if (e is Map<String, dynamic>) {
          top.add(AdminTopUslugaOcjena.fromJson(e));
        }
      }
    }

    AdminReviewQuote? quote;
    final rawQ = json['istaknutaRecenzija'];
    if (rawQ is Map<String, dynamic>) {
      quote = AdminReviewQuote.fromJson(rawQ);
    }

    return AdminReviewsDashboard(
      ukupno: (json['ukupno'] as num?)?.toInt() ?? 0,
      stranica: (json['stranica'] as num?)?.toInt() ?? 1,
      velicinaStranice: (json['velicinaStranice'] as num?)?.toInt() ?? 10,
      redovi: rows,
      prosjecnaOcjena: (json['prosjecnaOcjena'] as num?)?.toDouble() ?? 0,
      prosjecnaOcjenaPrethodno:
          (json['prosjecnaOcjenaPrethodno'] as num?)?.toDouble(),
      ukupnoPrethodno: (json['ukupnoPrethodno'] as num?)?.toInt() ?? 0,
      postotakPozitivnih: (json['postotakPozitivnih'] as num?)?.toDouble() ?? 0,
      postotakPozitivnihPrethodno:
          (json['postotakPozitivnihPrethodno'] as num?)?.toDouble(),
      postotakOdgovora: (json['postotakOdgovora'] as num?)?.toDouble(),
      postotakOdgovoraPrethodno:
          (json['postotakOdgovoraPrethodno'] as num?)?.toDouble(),
      distribucijaOcjena: dist,
      topUsluge: top,
      istaknutaRecenzija: quote,
    );
  }
}
