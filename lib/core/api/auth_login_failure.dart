/// Structured sign-in failure surfaced from [AuthRepository.login].
class AuthLoginFailure implements Exception {
  const AuthLoginFailure(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
