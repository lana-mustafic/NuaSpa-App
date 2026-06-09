/// Maps known API messages to English copy for the Settings UI.
abstract final class SettingsMessages {
  static String en(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Something went wrong. Please try again.';
    }
    final t = raw.trim();
    const map = <String, String>{
      'Lozinka je uspješno promijenjena.': 'Password changed successfully.',
      'Password changed successfully.': 'Password changed successfully.',
      'Trenutna lozinka nije ispravna.': 'Current password is incorrect.',
      'Lozinka još nije postavljena. Koristite link za pozivnicu.':
          'Password is not set yet. Use your invitation link to activate access.',
      'Nova lozinka mora biti različita od trenutne.':
          'New password must be different from your current password.',
      'Nova lozinka i potvrda se ne podudaraju.':
          'New password and confirmation do not match.',
      'Uspješno ste se odjavili.': 'Signed out successfully.',
      'Odjava nije uspjela. Lokalna sesija će biti obrisana.':
          'Server sign-out failed. Your local session was cleared.',
      'Niste prijavljeni ili sesija je istekla.':
          'You are not signed in or your session has expired.',
      'Nemate dozvolu za ovu radnju.':
          'You do not have permission for this action.',
      'Neispravan zahtjev. Provjerite unesene podatke.':
          'Invalid request. Check the information you entered.',
      'Mrežna greška. Pokušajte ponovo.':
          'Network error. Please try again.',
      'Lozinka nije promijenjena. Provjerite unos.':
          'Password was not changed. Check your input.',
    };
    return map[t] ?? t;
  }
}
