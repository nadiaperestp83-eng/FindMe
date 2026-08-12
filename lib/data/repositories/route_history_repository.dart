import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/hive_service.dart';

class RoutePointRecord {
  const RoutePointRecord({
    required this.position,
    required this.timestamp,
  });

  final LatLng position;
  final DateTime timestamp;
}

/// Um trecho da linha do tempo do dia: ou "parado" num lugar, ou "em
/// trânsito" entre dois lugares.
class TimelineSegment {
  const TimelineSegment({
    required this.isStop,
    required this.position,
    required this.start,
    required this.end,
  });

  final bool isStop;
  final LatLng position;
  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);
}

/// Guarda o trajeto percorrido HOJE no Hive — reseta a cada dia (a chave
/// é a data). Sem TypeAdapter/build_runner: só Map/List/double/String,
/// que o Hive já serializa nativamente.
///
/// Guarda só a posição do PRÓPRIO usuário (gravada localmente no
/// aparelho dele). Ver o trajeto de outra pessoa exigiria essa posição
/// vir do Supabase, não é o escopo desta etapa.
class RouteHistoryRepository {
  Box get _box => Hive.box(Boxes.dailyRouteBox);

  String get _todayKey {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }

  /// Carrega o trajeto de hoje já salvo, com horário de cada ponto.
  List<RoutePointRecord> loadTodayRecords() {
    try {
      final raw = _box.get(_todayKey);
      if (raw == null) return [];
      final list = (raw as List).cast<Map>();
      return list.map((m) {
        return RoutePointRecord(
          position: LatLng(
            (m['lat'] as num).toDouble(),
            (m['lng'] as num).toDouble(),
          ),
          // Pontos antigos (salvos antes desta atualização) não têm
          // "ts" — usa o momento da leitura como aproximação, pra não
          // quebrar quem já tinha trajeto salvo.
          timestamp: m['ts'] != null
              ? DateTime.parse(m['ts'] as String)
              : DateTime.now().toUtc(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Só os pontos (sem horário) — usado pra desenhar a Polyline no mapa.
  List<LatLng> loadToday() =>
      loadTodayRecords().map((r) => r.position).toList();

  /// Adiciona um ponto novo ao trajeto de hoje e salva, com o horário
  /// exato (default: agora).
  Future<void> appendPoint(LatLng point, {DateTime? timestamp}) async {
    final raw = _box.get(_todayKey);
    final list = raw != null ? (raw as List).cast<Map>().toList() : <Map>[];
    list.add({
      'lat': point.latitude,
      'lng': point.longitude,
      'ts': (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
    });
    await _box.put(_todayKey, list);
  }

  Future<void> clearToday() async {
    await _box.delete(_todayKey);
  }

  /// Transforma os pontos brutos do dia em trechos "parado"/"em trânsito".
  ///
  /// Algoritmo simples (v1): agrupa pontos consecutivos que ficam dentro
  /// de [stopRadiusMeters] do primeiro ponto do grupo; se esse grupo
  /// durou pelo menos [minStopDuration], vira um trecho "parado" —
  /// senão, é "em trânsito". Trechos "em trânsito" consecutivos são
  /// unidos num só, pra não fragmentar o trajeto em pedacinhos.
  List<TimelineSegment> buildTimeline({
    double stopRadiusMeters = 60,
    Duration minStopDuration = const Duration(minutes: 8),
  }) {
    final records = loadTodayRecords();
    if (records.isEmpty) return [];

    final raw = <TimelineSegment>[];
    int i = 0;

    while (i < records.length) {
      final clusterStart = records[i];
      int j = i + 1;
      while (j < records.length &&
          Geolocator.distanceBetween(
                clusterStart.position.latitude,
                clusterStart.position.longitude,
                records[j].position.latitude,
                records[j].position.longitude,
              ) <=
              stopRadiusMeters) {
        j++;
      }

      final clusterEnd = records[j - 1];
      final duration =
          clusterEnd.timestamp.difference(clusterStart.timestamp);

      raw.add(
        TimelineSegment(
          isStop: duration >= minStopDuration,
          position: clusterStart.position,
          start: clusterStart.timestamp,
          end: clusterEnd.timestamp,
        ),
      );

      i = j;
    }

    // Une trechos "em trânsito" consecutivos num só (sem isso, cada
    // ponto em movimento vira um mini-trecho separado).
    final merged = <TimelineSegment>[];
    for (final seg in raw) {
      if (!seg.isStop && merged.isNotEmpty && !merged.last.isStop) {
        final prev = merged.removeLast();
        merged.add(
          TimelineSegment(
            isStop: false,
            position: prev.position,
            start: prev.start,
            end: seg.end,
          ),
        );
      } else {
        merged.add(seg);
      }
    }

    return merged;
  }
}
