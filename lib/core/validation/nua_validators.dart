/// Shared input validators with clear user-facing messages.
abstract final class NuaValidators {
  static final RegExp emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static final RegExp phonePattern = RegExp(r'^\+?[0-9][0-9\s\-]{7,18}$');

  static final RegExp userNamePattern = RegExp(r'^[\w.\-]+$');

  static String? requiredText(String? value, {required String fieldLabel}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldLabel is required.';
    }
    return null;
  }

  static String? email(String? value, {bool required = true}) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) {
      return required ? 'Email address is required.' : null;
    }
    if (!emailPattern.hasMatch(t)) {
      return 'Enter a valid email address, e.g. name@domain.com';
    }
    return null;
  }

  static String? phoneOptional(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return null;
    if (!phonePattern.hasMatch(t)) {
      return 'Enter a valid phone number, e.g. +387 61 123 456 '
          'or digits only (8–15 digits).';
    }
    return null;
  }

  static String? userName(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) {
      return 'Username is required.';
    }
    if (!userNamePattern.hasMatch(t)) {
      return 'Username may contain letters, numbers, dots, hyphens, and underscores.';
    }
    return null;
  }

  static String? password(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters.';
    }
    return null;
  }

  static String? passwordOptional(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) return null;
    if (value.length < minLength) {
      return 'New password must be at least $minLength characters.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirm your new password.';
    }
    if (value != password) {
      return 'New password and confirmation do not match.';
    }
    return null;
  }

  static String? confirmPasswordOptional(String? value, String password) {
    if (password.isEmpty && (value == null || value.isEmpty)) return null;
    return confirmPassword(value, password);
  }

  static String? positivePrice(String? value, {String fieldLabel = 'Price'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldLabel is required.';
    }
    final n = double.tryParse(value.trim().replaceAll(',', '.'));
    if (n == null || n <= 0) {
      return 'Enter a valid amount in KM (e.g. 80.00). Amount must be greater than 0.';
    }
    return null;
  }

  static String? durationMinutes(
    String? value, {
    int min = 15,
    int max = 480,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Duration is required.';
    }
    final n = int.tryParse(value.trim());
    if (n == null) {
      return 'Enter duration in minutes (whole number, e.g. 60).';
    }
    if (n < min || n > max) {
      return 'Duration must be between $min and $max minutes.';
    }
    return null;
  }

  static String? serviceName(String? value) {
    final err = requiredText(value, fieldLabel: 'Service name');
    if (err != null) return err;
    if (value!.trim().length > 200) {
      return 'Service name can have at most 200 characters.';
    }
    return null;
  }

  static String? serviceDescription(String? value) {
    final err = requiredText(value, fieldLabel: 'Service description');
    if (err != null) return err;
    if (value!.trim().length > 1000) {
      return 'Description can have at most 1000 characters.';
    }
    return null;
  }

  static String? categoryName(String? value) {
    return requiredText(value, fieldLabel: 'Category name');
  }

  /// Email required only when portal invite is enabled.
  static String? emailOptionalOrRequiredForInvite(
    String? value, {
    required bool inviteEnabled,
  }) {
    final t = value?.trim() ?? '';
    if (inviteEnabled && t.isEmpty) {
      return 'Email is required to send a portal invitation.';
    }
    if (t.isEmpty) return null;
    return email(t);
  }

  static String? selectionRequired<T>(T? value, {required String fieldLabel}) {
    if (value == null) {
      return 'Select $fieldLabel.';
    }
    return null;
  }

  static String? appointmentDateTime(DateTime? value) {
    if (value == null) {
      return 'Appointment date and time are required.';
    }
    return null;
  }
}
