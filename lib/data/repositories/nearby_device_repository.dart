import 'package:hive_flutter/hive_flutter.dart';

import '../../services/hive_service.dart';
import '../../services/ble_protocol.dart';

/// Guarda no Hive a última posição recebida via BLE de cada pessoa do
/// círculo detectada por perto — permite o mapa mostrar "última posição
/// conhecida" mesmo sem internet (o BLE não depende de rede nenhuma).
///
/// Chave = user_id completo (já resolvido pelo BleLocationService antes
/// de chegar aqui — esse repositório não lida com o ID curto).
class NearbyDeviceRepository {
  Box get _box => Hive.box(Boxes.nearbyDevicesBox);

  Future<void> save(BleLocationPayload payload) async {
    await _box.put(payload.userId, {
      'lat': payload.lat,
      'lng': payload.lng,
      'battery': payload.batteryLevel,
      'ts': payload.timestamp.toUtc().toIso8601String(),
    });
  }

  BleLocationPayload? get(String userId) {
    try {
      final raw = _box.get(userId);
      if (raw == null) return null;
      final map = raw as Map;
      return BleLocationPayload(
        userId: userId,
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
        batteryLevel: (map['battery'] as num).toInt(),
        timestamp: DateTime.parse(map['ts'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  /// Todo mundo que já foi visto por BLE em algum momento (mesmo que
  /// tenha sido há horas — quem usa isso decide se o dado ainda é
  /// "recente o suficiente" pra mostrar).
  Map<String, BleLocationPayload> getAll() {
    final result = <String, BleLocationPayload>{};
    for (final key in _box.keys) {
      final payload = get(key as String);
      if (payload != null) {
        result[key] = payload;
      }
    }
    return result;
  }

  Future<void> clear() async {
    await _box.clear();
  }
}
