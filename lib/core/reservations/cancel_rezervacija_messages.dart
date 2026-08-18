import '../../models/cancel_rezervacija_result.dart';

String cancelRezervacijaSuccessMessage(CancelRezervacijaResult result) {
  if (result.refundIzvrsen && result.refundiraniIznos != null) {
    final amount = result.refundiraniIznos!.toStringAsFixed(2);
    return 'Booking cancelled. A refund of $amount KM has been initiated.';
  }
  if (result.refundIzvrsen) {
    return 'Booking cancelled. A refund has been initiated.';
  }
  return 'Booking cancelled.';
}
