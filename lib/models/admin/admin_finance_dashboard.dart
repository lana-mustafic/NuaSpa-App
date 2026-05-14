class AdminFinanceDashboard {
  AdminFinanceDashboard({
    required this.kpi,
    required this.redovi,
    required this.ukupno,
    required this.stranica,
    required this.velicinaStranice,
    required this.metodePostotak,
    required this.prihodDnevno,
    required this.nedavnaAktivnost,
  });

  final AdminFinanceKpi kpi;
  final List<AdminFinanceTransactionRow> redovi;
  final int ukupno;
  final int stranica;
  final int velicinaStranice;
  final List<AdminFinanceMethodShare> metodePostotak;
  final List<AdminFinanceTrendPoint> prihodDnevno;
  final List<AdminFinanceActivity> nedavnaAktivnost;

  factory AdminFinanceDashboard.fromJson(Map<String, dynamic> json) {
    return AdminFinanceDashboard(
      kpi: AdminFinanceKpi.fromJson(
        json['kpi'] as Map<String, dynamic>? ?? const {},
      ),
      redovi: (json['redovi'] as List<dynamic>? ?? const [])
          .map((e) => AdminFinanceTransactionRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      ukupno: (json['ukupno'] as num?)?.toInt() ?? 0,
      stranica: (json['stranica'] as num?)?.toInt() ?? 1,
      velicinaStranice: (json['velicinaStranice'] as num?)?.toInt() ?? 10,
      metodePostotak: (json['metodePostotak'] as List<dynamic>? ?? const [])
          .map((e) => AdminFinanceMethodShare.fromJson(e as Map<String, dynamic>))
          .toList(),
      prihodDnevno: (json['prihodDnevno'] as List<dynamic>? ?? const [])
          .map((e) => AdminFinanceTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      nedavnaAktivnost: (json['nedavnaAktivnost'] as List<dynamic>? ?? const [])
          .map((e) => AdminFinanceActivity.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AdminFinanceKpi {
  AdminFinanceKpi({
    required this.ukupniPrihod,
    required this.postotakPromjeneUkupniPrihod,
    required this.placeneRezervacije,
    required this.postotakPromjenePlaceneRezervacije,
    required this.prosjecnaVrijednost,
    required this.postotakPromjeneProsjecnaVrijednost,
    required this.neplaceneRezervacije,
    required this.postotakPromjeneNeplaceneRezervacije,
    required this.iznosRefundacija,
    required this.postotakPromjeneRefundacija,
  });

  final double ukupniPrihod;
  final double? postotakPromjeneUkupniPrihod;
  final int placeneRezervacije;
  final double? postotakPromjenePlaceneRezervacije;
  final double prosjecnaVrijednost;
  final double? postotakPromjeneProsjecnaVrijednost;
  final int neplaceneRezervacije;
  final double? postotakPromjeneNeplaceneRezervacije;
  final double iznosRefundacija;
  final double? postotakPromjeneRefundacija;

  factory AdminFinanceKpi.fromJson(Map<String, dynamic> json) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    double? dn(Object? v) => (v as num?)?.toDouble();
    int i(Object? v) => (v as num?)?.toInt() ?? 0;
    return AdminFinanceKpi(
      ukupniPrihod: d(json['ukupniPrihod']),
      postotakPromjeneUkupniPrihod: dn(json['postotakPromjeneUkupniPrihod']),
      placeneRezervacije: i(json['placeneRezervacije']),
      postotakPromjenePlaceneRezervacije: dn(json['postotakPromjenePlaceneRezervacije']),
      prosjecnaVrijednost: d(json['prosjecnaVrijednost']),
      postotakPromjeneProsjecnaVrijednost: dn(json['postotakPromjeneProsjecnaVrijednost']),
      neplaceneRezervacije: i(json['neplaceneRezervacije']),
      postotakPromjeneNeplaceneRezervacije: dn(json['postotakPromjeneNeplaceneRezervacije']),
      iznosRefundacija: d(json['iznosRefundacija']),
      postotakPromjeneRefundacija: dn(json['postotakPromjeneRefundacija']),
    );
  }
}

class AdminFinanceTransactionRow {
  AdminFinanceTransactionRow({
    required this.placanjeId,
    required this.transakcijskiId,
    required this.klijentPunoIme,
    required this.uslugaTekst,
    required this.datumVrijeme,
    required this.iznos,
    required this.metodaLabel,
    required this.status,
  });

  final int placanjeId;
  final String transakcijskiId;
  final String klijentPunoIme;
  final String uslugaTekst;
  final DateTime datumVrijeme;
  final double iznos;
  final String metodaLabel;
  /// paid | unpaid | refunded
  final String status;

  factory AdminFinanceTransactionRow.fromJson(Map<String, dynamic> json) {
    return AdminFinanceTransactionRow(
      placanjeId: (json['placanjeId'] as num?)?.toInt() ?? 0,
      transakcijskiId: json['transakcijskiId'] as String? ?? '',
      klijentPunoIme: json['klijentPunoIme'] as String? ?? '',
      uslugaTekst: json['uslugaTekst'] as String? ?? '',
      datumVrijeme: DateTime.tryParse(json['datumVrijeme'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      iznos: (json['iznos'] as num?)?.toDouble() ?? 0,
      metodaLabel: json['metodaLabel'] as String? ?? '',
      status: (json['status'] as String? ?? 'paid').toLowerCase(),
    );
  }
}

class AdminFinanceMethodShare {
  AdminFinanceMethodShare({
    required this.kljuc,
    required this.label,
    required this.postotak,
  });

  final String kljuc;
  final String label;
  final double postotak;

  factory AdminFinanceMethodShare.fromJson(Map<String, dynamic> json) {
    return AdminFinanceMethodShare(
      kljuc: json['kljuc'] as String? ?? '',
      label: json['label'] as String? ?? '',
      postotak: (json['postotak'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdminFinanceTrendPoint {
  AdminFinanceTrendPoint({
    required this.datum,
    required this.iznos,
  });

  final DateTime datum;
  final double iznos;

  factory AdminFinanceTrendPoint.fromJson(Map<String, dynamic> json) {
    return AdminFinanceTrendPoint(
      datum: DateTime.tryParse(json['datum'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      iznos: (json['iznos'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdminFinanceActivity {
  AdminFinanceActivity({
    required this.tip,
    required this.opis,
    required this.klijent,
    required this.iznos,
    required this.datumVrijeme,
  });

  final String tip;
  final String opis;
  final String klijent;
  final double iznos;
  final DateTime datumVrijeme;

  factory AdminFinanceActivity.fromJson(Map<String, dynamic> json) {
    return AdminFinanceActivity(
      tip: json['tip'] as String? ?? '',
      opis: json['opis'] as String? ?? '',
      klijent: json['klijent'] as String? ?? '',
      iznos: (json['iznos'] as num?)?.toDouble() ?? 0,
      datumVrijeme: DateTime.tryParse(json['datumVrijeme'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
