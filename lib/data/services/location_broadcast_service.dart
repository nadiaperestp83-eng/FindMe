import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../models/user_location_model.dart';

/// Responsável por capturar a posição do dispositivo e transmitir
/// (upsert) para a tabela `locations` no Supabase.
///
/// Esta é a versão EM PRIMEIRO PLANO (foreground). A persistência em
/// segundo plano com burla de Doze Mode (foreground service Android +
/// WorkManager) e o fallback BLE entram na próxima etapa, como combinado.
class LocationBroadcastService {
  LocationBroadcastService._internal();
  static final LocationBroadcastService instance =
      LocationBroadcastService._internal();

  final SupabaseClient _client = SupabaseConfig.client;

  StreamSubscription<Position>? _positionSub;
  bool get isBroadcasting => _positionSub != null;

  /// Garante permissões de localização. Lança exceção se negadas
  /// permanentemente — trate isso na UI (deep link para as configs).
  Future<void> ensurePermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Serviço de localização desativado no dispositivo.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw StateError('Permissão de localização negada.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Permissão de localização negada permanentemente. '
        'Abra as configurações do app para liberar.',
      );
    }
  }

  /// Inicia a transmissão contínua da posição do usuário logado.
  ///
  /// [distanceFilterMeters] evita upserts a cada centímetro (economiza
  /// bateria e requisições — importante no plano Free do Supabase).
  Future<void> start({double distanceFilterMeters = 15}) async {
    if (isBroadcasting) return;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Usuário não autenticado.');
    }

    await ensurePermissions();

    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters.toInt(),
    );

    _positionSub =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) => _pushPosition(userId, position),
      onError: (Object e, StackTrace st) {
        // Aqui entra o fallback Wi-Fi/célula na próxima etapa.
        // Por ora, apenas evita que o stream morra silenciosamente.
      },
    );
  }

  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
  }

  Future<void> _pushPosition(String userId, Position position) async {
    final model = UserLocationModel(
      userId: userId,
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      heading: position.heading,
      altitude: position.altitude,
      source: 'gps',
      updatedAt: DateTime.now().toUtc(),
    );

    try {
      // upsert: 1 linha por usuário (PK = user_id). onConflict garante
      // update in-place em vez de erro de PK duplicada.
      await _client
          .from('locations')
          .upsert(model.toUpsertMap(), onConflict: 'user_id');
    } catch (_) {
      // TODO (próxima etapa): enfileirar localmente (Hive) e reenviar
      // quando a conexão voltar — parte do fallback offline/BLE.
    }
  }
}
