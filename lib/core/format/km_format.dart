/// Iznos u KM s uvijek dvije decimale (npr. 80.00).
String formatKmAmount(num value) => value.toStringAsFixed(2);

/// Iznos s valutom (npr. 80.00 KM).
String formatKm(num value) => '${formatKmAmount(value)} KM';
