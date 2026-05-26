import '../../models/cancel_rezervacija_result.dart';

String cancelRezervacijaSuccessMessage(CancelRezervacijaResult result) {
  if (result.refundIzvrsen && result.refundiraniIznos != null) {
    final amount = result.refundiraniIznos!.toStringAsFixed(2);
    return 'Rezervacija otkazana. Povrat $amount KM je pokrenut.';
  }
  if (result.refundIzvrsen) {
    return 'Rezervacija otkazana. Povrat sredstava je pokrenut.';
  }
  return 'Rezervacija otkazana.';
}
