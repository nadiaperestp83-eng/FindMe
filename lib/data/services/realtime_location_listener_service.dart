import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../models/user_location_model.dart';
import '../repositories/circle_repository.dart';

/// Escuta em tempo real as posições dos membros de um círculo e expõe
/// um Stream<Map<userId, UserLocationModel>> pronto para alimentar os
/// marcadores do Google Maps.
///
/// A tabela `locations` tem RLS: mesmo que o filtro do canal não seja
/// perfeito, o Postgres nunca entrega uma linha que o usuário atual
/// não tem permissão de ver (garantido pela policy locations_select).
class RealtimeLocationListenerService {
  RealtimeLocationListenerService({CircleRepository? circleRepository})
      : _circleRepository = circleRepository ?? CircleRepository();

  final SupabaseClient _client = SupabaseConfig.client;
  final CircleRepository _circleRepository;

  RealtimeChannel? _channel;
  final _controller =
      StreamController<Map<String, UserLocationModel>>.broadcast();

  final Map<String, UserLocationModel> _cache = {};

  Stream<Map<String, UserLocationModel>> get locationsStream =>
      _controller.stream;

  /// Começa a escutar as posições de TODOS os círculos que o usuário
  /// participa, de uma vez — usado pela tela de Mapa/Pessoas nova (que
  /// não tem mais conceito de círculo visível na UI). Como a policy de
  /// RLS já libera exatamente "qualquer círculo em comum", isso bate
  /// certinho com o que o Postgres nos deixaria ver de qualquer forma.
  Future<void> listenToAllMyCircles() async {
    await stop();

    final memberIds = await _circleRepository.listAllAcceptedUserIds();
    if (memberIds.isEmpty) {
      _controller.add(const {});
      return;
    }

    await _loadInitialSnapshot(memberIds);

    _channel = _client
        .channel('locations-all-circles')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'locations',
          callback: _handleChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'locations',
          callback: _handleChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'locations',
          callback: _handleDelete,
        )
        .subscribe();
  }

  /// Começa a escutar as posições dos membros aceitos de [circleId].
  /// 1) Busca o snapshot inicial (posições atuais) via SELECT normal.
  /// 2) Assina o canal Realtime para receber INSERT/UPDATE ao vivo.
  Future<void> listenToCircle(String circleId) async {
    await stop();

    final memberIds = await _circleRepository.listAcceptedMemberIds(circleId);
    if (memberIds.isEmpty) {
      _controller.add(const {});
      return;
    }

    await _loadInitialSnapshot(memberIds);

    _channel = _client
        .channel('locations-circle-$circleId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'locations',
          callback: _handleChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'locations',
          callback: _handleChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'locations',
          callback: _handleDelete,
        )
        .subscribe();
  }

  Future<void> _loadInitialSnapshot(List<String> memberIds) async {
    final rows = await _client
        .from('locations')
        .select()
        .inFilter('user_id', memberIds);

    _cache.clear();
    for (final row in (rows as List)) {
      final loc = UserLocationModel.fromMap(row as Map<String, dynamic>);
      _cache[loc.userId] = loc;
    }
    _controller.add(Map.unmodifiable(_cache));
  }

  void _handleChange(PostgresChangePayload payload) {
    // A RLS já garante que só recebemos linhas permitidas; aqui só
    // atualizamos o cache local e republicamos no stream.
    final loc = UserLocationModel.fromMap(payload.newRecord);
    _cache[loc.userId] = loc;
    _controller.add(Map.unmodifiable(_cache));
  }

  void _handleDelete(PostgresChangePayload payload) {
    final userId = payload.oldRecord['user_id'] as String?;
    if (userId != null) {
      _cache.remove(userId);
      _controller.add(Map.unmodifiable(_cache));
    }
  }

  Future<void> stop() async {
    if (_channel != null) {
      await _client.removeChannel(_channel!);
      _channel = null;
    }
    _cache.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
