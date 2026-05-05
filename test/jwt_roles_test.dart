import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuaspa_app/core/jwt_roles.dart';

/// Minimalni JWT bez potpisa (validan za naš decoder koji čita samo payload).
String _mockJwt(Map<String, dynamic> payload) {
  final chunk = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return 'x.$chunk.y';
}

void main() {
  test('parseJwtRoles reads ASP.NET Role claim', () {
    final token = _mockJwt({
      'http://schemas.microsoft.com/ws/2008/06/identity/claims/role': 'Admin',
    });
    expect(parseJwtRoles(token), contains('Admin'));
  });

  test('parseJwtIntClaim reads ZaposlenikId', () {
    final token = _mockJwt({'ZaposlenikId': 42});
    expect(parseJwtIntClaim(token, 'ZaposlenikId'), 42);
  });

  test('decodeJwtPayload returns null for garbage', () {
    expect(decodeJwtPayload(null), isNull);
    expect(decodeJwtPayload(''), isNull);
    expect(decodeJwtPayload('not-a-jwt'), isNull);
  });
}
