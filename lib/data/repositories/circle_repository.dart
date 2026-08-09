import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../models/circle_models.dart';

/// Substitui os antigos endpoints REST de "Movement" do backend
/// Node.js por chamadas diretas ao PostgREST do Supabase.
class CircleRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Usuário não autenticado.');
    }
    return id;
  }

  /// Cria um novo círculo permanente. O dono é adicionado
  /// automaticamente como membro 'accepted' via trigger no banco.
  Future<CircleModel> createCircle(String name) async {
    final row = await _client
        .from('circles')
        .insert({'name': name, 'owner_id': _uid})
        .select()
        .single();
    return CircleModel.fromMap(row);
  }

  /// Lista os círculos visíveis para o usuário atual (dono ou membro aceito).
  Future<List<CircleModel>> listMyCircles() async {
    final rows = await _client
        .from('circles')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => CircleModel.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Convida um usuário pelo username. Só funciona se o usuário atual
  /// for o owner do círculo (garantido pela policy members_insert_owner_invites).
  Future<void> inviteByUsername({
    required String circleId,
    required String username,
  }) async {
    final target = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();

    if (target == null) {
      throw StateError('Usuário "$username" não encontrado.');
    }

    await _client.from('circle_members').insert({
      'circle_id': circleId,
      'user_id': target['id'],
      'status': 'pending',
      'invited_by': _uid,
    });
  }

  /// Lista membros de um círculo (com dados de perfil via join).
  Future<List<CircleMemberModel>> listMembers(String circleId) async {
    final rows = await _client
        .from('circle_members')
        .select('*, profiles(id, username, display_name, avatar_url)')
        .eq('circle_id', circleId);
    return (rows as List)
        .map((r) => CircleMemberModel.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Convites pendentes recebidos pelo usuário atual.
  Future<List<CircleMemberModel>> listMyPendingInvites() async {
    final rows = await _client
        .from('circle_members')
        .select('*, profiles(id, username, display_name, avatar_url)')
        .eq('user_id', _uid)
        .eq('status', 'pending');
    return (rows as List)
        .map((r) => CircleMemberModel.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> acceptInvite(String circleId) async {
    await _client
        .from('circle_members')
        .update({'status': 'accepted'})
        .eq('circle_id', circleId)
        .eq('user_id', _uid);
  }

  Future<void> declineInvite(String circleId) async {
    await _client
        .from('circle_members')
        .update({'status': 'declined'})
        .eq('circle_id', circleId)
        .eq('user_id', _uid);
  }

  /// Sair de um círculo (remove a própria linha de membership).
  Future<void> leaveCircle(String circleId) async {
    await _client
        .from('circle_members')
        .delete()
        .eq('circle_id', circleId)
        .eq('user_id', _uid);
  }

  /// Todos os user_ids de membros 'accepted' de um círculo — útil para
  /// buscar as localizações iniciais antes do realtime assumir.
  Future<List<String>> listAcceptedMemberIds(String circleId) async {
    final rows = await _client
        .from('circle_members')
        .select('user_id')
        .eq('circle_id', circleId)
        .eq('status', 'accepted');
    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['user_id'] as String)
        .toList();
  }
}
