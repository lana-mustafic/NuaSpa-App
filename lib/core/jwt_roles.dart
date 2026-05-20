import 'dart:convert';

/// ASP.NET JWT koristi ClaimTypes.Role kao puni URI u payloadu.
const _roleClaimKeys = <String>[
  'http://schemas.microsoft.com/ws/2008/06/identity/claims/role',
  'role',
  'roles',
];

Map<String, dynamic>? decodeJwtPayload(String? token) {
  if (token == null || token.isEmpty) return null;

  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    var payload = parts[1];
    final pad = payload.length % 4;
    if (pad == 2) {
      payload += '==';
    } else if (pad == 3) {
      payload += '=';
    }

    final jsonStr = utf8.decode(base64Url.decode(payload));
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

List<String> parseJwtRoles(String? token) {
  final map = decodeJwtPayload(token);
  if (map == null) return [];

  final out = <String>{};
  for (final key in _roleClaimKeys) {
    final v = map[key];
    if (v is String) {
      out.add(v);
    } else if (v is List) {
      out.addAll(v.map((e) => e.toString()));
    }
  }

  return out.toList();
}

int? parseJwtIntClaim(String? token, String claimKey) {
  final map = decodeJwtPayload(token);
  if (map == null) return null;
  final v = map[claimKey];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// `true` ako token nedostaje, nije JWT ili je `exp` prošao (s malim skewom).
bool isJwtExpired(
  String? token, {
  Duration clockSkew = const Duration(seconds: 30),
}) {
  final map = decodeJwtPayload(token);
  if (map == null) return true;

  final exp = map['exp'];
  int? expSec;
  if (exp is int) {
    expSec = exp;
  } else if (exp is num) {
    expSec = exp.toInt();
  } else if (exp is String) {
    expSec = int.tryParse(exp);
  }
  if (expSec == null) return false;

  final expiry = DateTime.fromMillisecondsSinceEpoch(expSec * 1000);
  return DateTime.now().isAfter(expiry.add(clockSkew));
}

/// Token izgleda valjano za lokalnu sesiju (format + nije istekao).
bool isJwtSessionValid(String? token) {
  if (token == null || token.trim().isEmpty) return false;
  return !isJwtExpired(token);
}
