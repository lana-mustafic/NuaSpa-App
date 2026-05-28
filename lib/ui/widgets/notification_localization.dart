/// Display-time English strings for system notifications (incl. legacy Bosnian copy).
abstract final class NotificationLocalization {
  static const Map<String, String> _titles = {
    'Rezervacija zaprimljena': 'Booking received',
    'Nova rezervacija': 'New booking',
    'Novi termin': 'New appointment',
    'Rezervacija potvrđena': 'Booking confirmed',
    'Termin potvrđen': 'Appointment confirmed',
    'Rezervacija otkazana': 'Booking cancelled',
    'Otkazana rezervacija': 'Cancelled booking',
    'Termin otkazan': 'Appointment cancelled',
    'Termin završen': 'Appointment completed',
    'Plaćanje uspješno': 'Payment successful',
    'Novo plaćanje': 'New payment',
    'Povrat sredstava': 'Refund processed',
    'Refund izvršen': 'Refund completed',
  };

  static const List<(String, String)> _bodyReplacements = [
    ('Vaša rezervacija za ', 'Your booking for '),
    (' je zaprimljena i čeka potvrdu.', ' was received and is awaiting confirmation.'),
    ('Novi termin: ', 'New appointment: '),
    ('Vaš termin za ', 'Your appointment for '),
    (' je potvrđen.', ' has been confirmed.'),
    ('Termin za ', 'Appointment for '),
    (' je otkazan. Razlog: ', ' was cancelled. Reason: '),
    ('Otkazan termin ', 'Cancelled appointment '),
    (' je otkazan.', ' was cancelled.'),
    ('Tretman ', 'Treatment '),
    (' je označen kao završen.', ' has been marked as completed.'),
    ('Uspješno plaćeno ', 'Successfully paid '),
    ('Plaćeno ', 'Paid '),
    (' za ', ' for '),
    (' je obrađen.', ' has been processed.'),
  ];

  static String title(String value) => _titles[value.trim()] ?? value;

  static String body(String value) {
    var text = value;
    for (final pair in _bodyReplacements) {
      text = text.replaceAll(pair.$1, pair.$2);
    }
    return text;
  }
}
