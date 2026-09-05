import 'package:dio/dio.dart';

/// Parses validation and business-rule messages from API responses.
abstract final class ApiErrorMessages {
  static String fromObject(Object error, {String? fallback}) {
    if (error is DioException) {
      final parsed = fromDio(error);
      if (parsed != null) return parsed;
    }
    return fallback ?? 'Something went wrong. Please try again.';
  }

  static String? fromDio(DioException error) {
    final data = error.response?.data;
    if (data is String && data.trim().isNotEmpty) {
      return _humanize(data.trim());
    }
    if (data is Map) {
      final detail = data['detail'] ?? data['message'] ?? data['title'];
      if (detail != null) {
        final d = detail.toString().trim();
        if (d.isNotEmpty && !_isGenericHttpTitle(d, error.response?.statusCode)) {
          return _humanize(d);
        }
      }
      final errors = data['errors'];
      if (errors is Map) {
        final parts = <String>[];
        for (final entry in errors.entries) {
          final v = entry.value;
          if (v is List) {
            parts.addAll(v.map((e) => _humanize(e.toString())));
          } else if (v != null) {
            parts.add(_humanize(v.toString()));
          }
        }
        if (parts.isNotEmpty) return parts.join(' ');
      }
    }
    if (data is List && data.isNotEmpty) {
      return data.map((e) => _humanize(e.toString())).join(' ');
    }
    final code = error.response?.statusCode;
    if (code == 409) {
      return 'The data conflicts with an existing record (e.g. email is already registered).';
    }
    if (code == 400) {
      return 'Invalid request. Check the information you entered.';
    }
    if (code == 401) {
      return 'You are not signed in or your session has expired.';
    }
    if (code == 403) {
      return 'You do not have permission for this action.';
    }
    return null;
  }

  static bool _isGenericHttpTitle(String title, int? statusCode) {
    if (statusCode == 400 && title == 'One or more validation errors occurred.') {
      return true;
    }
    return title == 'Bad Request' ||
        title == 'Success' ||
        title == 'Conflict' ||
        title == 'Unauthorized';
  }

  static String _humanize(String raw) {
    const replacements = <String, String>{
      // Registration / account conflicts
      'Email je već registriran.': 'This email is already registered.',
      'Email is already registered.': 'This email is already registered.',
      'Korisničko ime je zauzeto.': 'This username is already taken.',
      'Username is already taken.': 'This username is already taken.',
      'Email ne može biti prazan.': 'Email cannot be empty.',
      'Ime je obavezno.': 'First name is required.',
      'Prezime je obavezno.': 'Last name is required.',
      'E-mail adresa je obavezna.': 'Email address is required.',
      'Ime može imati najviše 50 znakova.':
          'First name can have at most 50 characters.',
      'Prezime može imati najviše 50 znakova.':
          'Last name can have at most 50 characters.',
      'E-mail adresa može imati najviše 256 znakova.':
          'Email can have at most 256 characters.',
      'Unesite ispravnu e-mail adresu u formatu: ime@domena.ba':
          'Enter a valid email address, e.g. name@domain.com',
      'Unesite ispravan broj telefona u formatu: +387 61 123 456 ili samo cifre (8–15 znamenki).':
          'Enter a valid phone number, e.g. +387 61 123 456 or digits only (8–15 digits).',

      // Auth
      'Korisnik nije pronađen.': 'User not found.',
      'Trenutna lozinka nije ispravna.': 'Current password is incorrect.',
      'Neispravno korisničko ime ili lozinka.': 'Invalid username or password.',
      'Niste prijavljeni ili sesija je istekla.':
          'You are not signed in or your session has expired.',
      'Nemate dozvolu za ovu radnju.':
          'You do not have permission for this action.',
      'Neispravan zahtjev. Provjerite unesene podatke.':
          'Invalid request. Check the information you entered.',
      'Mrežna greška. Pokušajte ponovo.': 'Network error. Please try again.',

      // Clients
      'Klijent nije pronađen.': 'Client not found.',
      'Klijent uloga nije pronađena.': 'Client role not found.',
      'Uloga Klijent nije pronađena u bazi.':
          'Client role not found in the database.',

      // Bookings
      'Rezervacija u ovom statusu se ne može mijenjati.':
          'This booking cannot be changed in its current status.',
      'Plaćena rezervacija se ne može mijenjati.':
          'Paid bookings cannot be changed.',
      'Samo potvrđenu rezervaciju je moguće označiti kao završenu.':
          'Only confirmed bookings can be marked as completed.',
      'Rezervacija se može završiti tek nakon isteka termina.':
          'A booking can only be completed after the appointment time has passed.',
      'Samo rezervacija u statusu Pending može biti potvrđena.':
          'Only pending bookings can be confirmed.',
      'Odobren zahtjev se ne može vratiti u Pending. Koristite otkazivanje s razlogom.':
          'An approved booking cannot be reverted to pending. Cancel it with a reason instead.',
      'Razlog otkazivanja je obavezan.': 'A cancellation reason is required.',
      'Rezervacija nije pronađena.': 'Booking not found.',

      // Payments
      'Rezervacija je već plaćena.': 'This booking is already paid.',
      'Plaćanje nije pronađeno.': 'Payment not found.',
      'Nemate dozvolu za potvrdu ovog plaćanja.':
          'You do not have permission to confirm this payment.',
      'Plaćanje je refundirano.': 'This payment has been refunded.',
      'Plaćanje nije uspješno završeno na Stripe-u.':
          'Payment was not completed successfully on Stripe.',
      'Nema završenog Stripe plaćanja za refund.':
          'No completed Stripe payment found for refund.',
      'Rezervacija nije povezana s plaćanjem.':
          'This booking is not linked to a payment.',
      'Nema naplaćenog iznosa za refund.':
          'No charged amount available for refund.',
      'Nemate dozvolu za kreiranje plaćanja za ovu rezervaciju.':
          'You do not have permission to create payment for this booking.',
      'Online payment is only available for confirmed reservations.':
          'Online payment is only available for confirmed reservations.',
      'Otkazana rezervacija se ne može platiti.':
          'Cancelled bookings cannot be paid.',
      'PaymentIntentId je obavezan.': 'PaymentIntentId is required.',
      'Stripe SecretKey nije konfigurisan. (postavi Stripe__SecretKey u .env)':
          'Stripe SecretKey is not configured. (set Stripe__SecretKey in .env)',
      'Stripe WebhookSecret nije konfigurisan.':
          'Stripe WebhookSecret is not configured.',
      'Neispravan Stripe webhook zahtjev.': 'Invalid Stripe webhook request.',

      // Therapists / staff
      'Terapeut ima rezervacije i ne može biti obrisan.':
          'This therapist has bookings and cannot be deleted.',
      'KategorijaUslugaId ne postoji.': 'Service category does not exist.',

      // Reviews
      'Ocjena mora biti između 1 i 5.': 'Rating must be between 1 and 5.',
      'Komentar može imati najviše 1000 znakova.':
          'Comment can have at most 1000 characters.',

      // Spa resources
      'Spa centar nije pronađen.': 'Spa center not found.',
      'Prostorija nije pronađena.': 'Room not found.',
      'Oprema nije pronađena.': 'Equipment not found.',

      // Location catalogs
      'Država nije pronađena.': 'Country not found.',
      'Grad nije pronađen.': 'City not found.',
      'Naziv države je obavezan.': 'Country name is required.',
      'Naziv grada je obavezan.': 'City name is required.',
      'Pozivni broj je obavezan.': 'Calling code is required.',
      'Poštanski broj je obavezan.': 'Postal code is required.',
      'Država s tim nazivom već postoji.':
          'A country with that name already exists.',
      'Grad s tim nazivom već postoji u odabranoj državi.':
          'A city with that name already exists in the selected country.',
      'Država ima gradove i ne može biti obrisana. Prvo uklonite ili premjestite gradove.':
          'This country has cities and cannot be deleted. Remove or move the cities first.',
      'Državu koriste korisnički profili i ne može biti obrisana.':
          'This country is used on user profiles and cannot be deleted.',
      'Grad je već dodijeljen korisnicima i ne može biti obrisan. Promijenite grad na profilima prije brisanja.':
          'This city is assigned to users and cannot be deleted. Change those profiles first.',
      'Odabrana država nije pronađena.': 'The selected country was not found.',

      // News / announcements
      'Naslov obavijesti je obavezan.': 'News title is required.',
      'Tekst obavijesti je obavezan.': 'News text is required.',
      'Datoteka nije poslana.': 'No file was sent.',
      'Datoteka je prevelika (maks. 5 MB).': 'The file is too large (max 5 MB).',
      'Dopušteni formati: JPG, PNG, WEBP, GIF.':
          'Allowed formats: JPG, PNG, WEBP, GIF.',
      'MIME tip datoteke nije dopušten za upload slike.':
          'The file MIME type is not allowed for image upload.',
      'Datoteka se ne može pročitati.': 'The file cannot be read.',
      'Datoteka je prazna ili oštećena.': 'The file is empty or damaged.',
      'Sadržaj datoteke ne odgovara navedenom formatu slike.':
          'The file content does not match the declared image format.',
    };
    return replacements[raw] ?? raw;
  }

  /// Maps a raw API or validation message to English when a translation exists.
  static String humanize(String raw) => _humanize(raw);
}
