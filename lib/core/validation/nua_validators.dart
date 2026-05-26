/// Zajednički validatori unosa s jasnim porukama na hrvatskom/bosanskom.
abstract final class NuaValidators {
  static final RegExp emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static final RegExp phonePattern = RegExp(r'^\+?[0-9][0-9\s\-]{7,18}$');

  static final RegExp userNamePattern = RegExp(r'^[\w.\-]+$');

  static String? requiredText(String? value, {required String fieldLabel}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldLabel je obavezno.';
    }
    return null;
  }

  static String? email(String? value, {bool required = true}) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) {
      return required
          ? 'E-mail adresa je obavezna.'
          : null;
    }
    if (!emailPattern.hasMatch(t)) {
      return 'Unesite ispravnu e-mail adresu u formatu: ime@domena.ba';
    }
    return null;
  }

  static String? phoneOptional(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return null;
    if (!phonePattern.hasMatch(t)) {
      return 'Unesite ispravan broj telefona u formatu: +387 61 123 456 '
          'ili samo cifre (8–15 znamenki).';
    }
    return null;
  }

  static String? userName(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) {
      return 'Korisničko ime je obavezno.';
    }
    if (!userNamePattern.hasMatch(t)) {
      return 'Korisničko ime smije sadržavati slova, brojeve, tačku, crticu i donju crtu.';
    }
    return null;
  }

  static String? password(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'Lozinka je obavezna.';
    }
    if (value.length < minLength) {
      return 'Lozinka mora imati najmanje $minLength znakova.';
    }
    return null;
  }

  static String? passwordOptional(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) return null;
    if (value.length < minLength) {
      return 'Nova lozinka mora imati najmanje $minLength znakova.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Potvrdite novu lozinku.';
    }
    if (value != password) {
      return 'Nova lozinka i potvrda se ne podudaraju.';
    }
    return null;
  }

  static String? confirmPasswordOptional(String? value, String password) {
    if (password.isEmpty && (value == null || value.isEmpty)) return null;
    return confirmPassword(value, password);
  }

  static String? positivePrice(String? value, {String fieldLabel = 'Cijena'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldLabel je obavezna.';
    }
    final n = double.tryParse(value.trim().replaceAll(',', '.'));
    if (n == null || n <= 0) {
      return 'Unesite ispravan iznos u KM (npr. 80.00). Iznos mora biti veći od 0.';
    }
    return null;
  }

  static String? durationMinutes(
    String? value, {
    int min = 15,
    int max = 480,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Trajanje je obavezno.';
    }
    final n = int.tryParse(value.trim());
    if (n == null) {
      return 'Unesite trajanje u minutama (cijeli broj, npr. 60).';
    }
    if (n < min || n > max) {
      return 'Trajanje mora biti između $min i $max minuta.';
    }
    return null;
  }

  static String? serviceName(String? value) {
    final err = requiredText(value, fieldLabel: 'Naziv usluge');
    if (err != null) return err;
    if (value!.trim().length > 200) {
      return 'Naziv usluge može imati najviše 200 znakova.';
    }
    return null;
  }

  static String? serviceDescription(String? value) {
    final err = requiredText(value, fieldLabel: 'Opis usluge');
    if (err != null) return err;
    if (value!.trim().length > 1000) {
      return 'Opis može imati najviše 1000 znakova.';
    }
    return null;
  }

  static String? categoryName(String? value) {
    return requiredText(value, fieldLabel: 'Naziv kategorije');
  }

  /// E-mail obavezan samo kada je uključena pozivnica na portal.
  static String? emailOptionalOrRequiredForInvite(
    String? value, {
    required bool inviteEnabled,
  }) {
    final t = value?.trim() ?? '';
    if (inviteEnabled && t.isEmpty) {
      return 'E-mail je obavezan za slanje pozivnice na portal.';
    }
    if (t.isEmpty) return null;
    return email(t);
  }

  static String? selectionRequired<T>(T? value, {required String fieldLabel}) {
    if (value == null) {
      return 'Odaberite $fieldLabel.';
    }
    return null;
  }

  static String? appointmentDateTime(DateTime? value) {
    if (value == null) {
      return 'Datum i vrijeme termina su obavezni.';
    }
    return null;
  }
}
