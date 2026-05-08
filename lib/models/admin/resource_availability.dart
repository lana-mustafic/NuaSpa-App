import 'prostorija.dart';

class ResourceAvailability {
  final DateTime slot;
  final List<Prostorija> freeRooms;
  final List<OpremaAvailability> equipment;

  const ResourceAvailability({
    required this.slot,
    required this.freeRooms,
    required this.equipment,
  });

  factory ResourceAvailability.fromJson(Map<String, dynamic> json) {
    final freeRoomsJson = json['freeRooms'];
    final equipmentJson = json['equipment'];
    return ResourceAvailability(
      slot: DateTime.parse((json['slot'] as String?) ?? DateTime.now().toIso8601String()),
      freeRooms: freeRoomsJson is List
          ? freeRoomsJson
              .whereType<Map>()
              .map((e) => Prostorija.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      equipment: equipmentJson is List
          ? equipmentJson
              .whereType<Map>()
              .map((e) => OpremaAvailability.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class OpremaAvailability {
  final int opremaId;
  final String naziv;
  final int total;
  final int reserved;
  final int remaining;

  const OpremaAvailability({
    required this.opremaId,
    required this.naziv,
    required this.total,
    required this.reserved,
    required this.remaining,
  });

  factory OpremaAvailability.fromJson(Map<String, dynamic> json) {
    return OpremaAvailability(
      opremaId: (json['opremaId'] as num?)?.toInt() ?? 0,
      naziv: (json['naziv'] as String?) ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      reserved: (json['reserved'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    );
  }
}

