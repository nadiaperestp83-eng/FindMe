import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/hive_service.dart';

/// Guarda o trajeto percorrido HOJE no Hive — reseta a cada dia (a chave
/// é a data). Sem TypeAdapter/build_runner: só Map/List/double, que o
/// Hive já serializa nativamente.
class RouteHistoryRepository {
  Box get _box => Hive.box(Boxes.dailyRouteBox);

  String get _todayKey {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }

  /// Carrega o trajeto de hoje já salvo (se o app foi reaberto no mesmo
  /// dia, o traçado continua de onde parou).
  List<LatLng> loadToday() {
    try {
      final raw = _box.get(_todayKey);
      if (raw == null) return [];
      final list = (raw as List).cast<Map>();
      return list
          .map((m) => LatLng(
                (m['lat'] as num).toDouble(),
                (m['lng'] as num).toDouble(),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Adiciona um ponto novo ao trajeto de hoje e salva.
  Future<void> appendPoint(LatLng point) async {
    final raw = _box.get(_todayKey);
    final list = raw != null ? (raw as List).cast<Map>().toList() : <Map>[];
    list.add({'lat': point.latitude, 'lng': point.longitude});
    await _box.put(_todayKey, list);
  }

  /// Limpa o trajeto de hoje (não usado ainda na UI, mas fica pronto
  /// pra um futuro botão "limpar trajeto").
  Future<void> clearToday() async {
    await _box.delete(_todayKey);
  }
}
