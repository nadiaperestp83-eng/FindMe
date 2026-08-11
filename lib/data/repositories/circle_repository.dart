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
  /// Convida por username OU e-mail. Aceita "@username" (tira o @
  /// sozinho) e não diferencia maiúsculas/minúsculas no username.
  Future<void> inviteByUsername({
    required String circleId,
    required String username,
  }) async {
    final input = username.trim();
    if (input.isEmpty) {
      throw StateError('Digite um username ou e-mail.');
    }

    String targetId;

    // "@" no meio do texto (não no começo) = parece e-mail.
    final looksLikeEmail = input.contains('@') && !input.startsWith('@');

    if (looksLikeEmail) {
      final result = await _client.rpc(
        'find_user_id_by_email',
        params: {'email_input': input},
      );
      if (result == null) {
        throw StateError('Nenhum usuário encontrado com o e-mail "$input".');
      }
      targetId = result as String;
    } else {
      // Tira o "@" do início se tiver (ex: "@layla" -> "layla") e busca
      // sem diferenciar maiúsculas/minúsculas.
      final cleanUsername =
          input.startsWith('@') ? input.substring(1) : input;
      if (cleanUsername.isEmpty) {
        throw StateError('Digite um username válido.');
      }
      final target = await _client
          .from('profiles')
          .select('id')
          .ilike('username', cleanUsername)
          .maybeSingle();
      if (target == null) {
        throw StateError('Usuário "$cleanUsername" não encontrado.');
      }
      targetId = target['id'] as String;
    }

    if (targetId == _uid) {
      throw StateError('Você não pode convidar a si mesmo.');
    }

    await _client.from('circle_members').insert({
      'circle_id': circleId,
      'user_id': targetId,
      'status': 'pending',
      'invited_by': _uid,
    });
  }

  /// Lista membros de um círculo (com dados de perfil via join).
  Future<List<CircleMemberModel>> listMembers(String circleId) async {
    // profiles!circle_members_user_id_fkey: circle_members tem DUAS
    // colunas que apontam pra profiles (user_id e invited_by) — sem
    // dizer qual usar, o PostgREST rejeita a consulta por ambiguidade.
    // Aqui queremos o perfil do MEMBRO (user_id).
    final rows = await _client
        .from('circle_members')
        .select(
            '*, profiles!circle_members_user_id_fkey(id, username, display_name, avatar_url)')
        .eq('circle_id', circleId);
    return (rows as List)
        .map((r) => CircleMemberModel.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Convites pendentes recebidos pelo usuário atual.
  Future<List<CircleMemberModel>> listMyPendingInvites() async {
    // Aqui é o oposto do listMembers: queremos o perfil de QUEM CONVIDOU
    // (invited_by), não o meu próprio perfil (que seria user_id).
    final rows = await _client
        .from('circle_members')
        .select(
            '*, profiles!circle_members_invited_by_fkey(id, username, display_name, avatar_url)')
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

  // -------------------------------------------------------------------
  // Métodos abaixo existem só pra alimentar a UI nova (estilo Find My,
  // sem tela de "Círculos"). O banco continua com o mesmo modelo de
  // circles/circle_members — só "achatamos" o resultado aqui, sem
  // expor o conceito de círculo pra quem usa o app.
  // -------------------------------------------------------------------

  /// Garante que o usuário tem pelo menos 1 círculo próprio, criando um
  /// automaticamente (sem o usuário perceber) se ainda não tiver nenhum.
  /// Usado pelo botão "Convidar pessoa" da tela de Mapa/Pessoas.
  Future<String> ensureDefaultCircle() async {
    final myCircles = await listMyCircles();
    final owned = myCircles.where((c) => c.ownerId == _uid).toList();
    if (owned.isNotEmpty) {
      return owned.first.id;
    }
    final created = await createCircle('Meu círculo');
    return created.id;
  }

  /// Todas as pessoas (perfis) que compartilham comigo, somando membros
  /// 'accepted' de TODOS os círculos que participo — sem duplicar e sem
  /// incluir eu mesmo. É a lista que alimenta a gaveta "Pessoas".
  Future<List<CircleMemberModel>> listAllSharedMembers() async {
    final circles = await listMyCircles();
    final Map<String, CircleMemberModel> byUserId = {};
    for (final circle in circles) {
      final members = await listMembers(circle.id);
      for (final member in members) {
        if (member.userId == _uid) continue;
        if (member.status != CircleMemberStatus.accepted) continue;
        byUserId[member.userId] = member;
      }
    }
    return byUserId.values.toList();
  }

  /// Igual ao acima, mas só os user_ids (incluindo o meu) — pronto pra
  /// alimentar o snapshot inicial + filtro do realtime na tela de Mapa.
  Future<List<String>> listAllAcceptedUserIds() async {
    final circles = await listMyCircles();
    final Set<String> ids = {_uid};
    for (final circle in circles) {
      ids.addAll(await listAcceptedMemberIds(circle.id));
    }
    return ids.toList();
  }
}
