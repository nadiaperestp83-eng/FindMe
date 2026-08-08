import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/account.dart';

/// Antes: falava com o backend Node.js via Dio + cachava a sessão no
/// Hive. Agora: fala direto com o Supabase Auth, que já persiste e
/// restaura a sessão sozinho — então os métodos de cache manual
/// (addAuth/getAuthToken) saíram, e getAuth()/removeAuth() passaram a
/// consultar a sessão do Supabase.
///
/// Como o cadastro virou 1 passo só (sem OTP por e-mail, sem tela de
/// criar perfil separada — o profile é criado automaticamente pelo
/// trigger handle_new_user no banco), os métodos resendOTP, verifyOTP,
/// createProfile e getProfile não existem mais aqui. As telas que os
/// chamavam (verify_otp.dart, create_profile.dart) serão ajustadas
/// numa próxima leva de arquivos.
class AuthService {
  final _client = SupabaseConfig.client;

  /// Retorna a conta da sessão Supabase ativa, ou null se não há login.
  Account? getAuth() {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final metadata = user.userMetadata ?? {};
    return Account(
      userId: user.id,
      fullName: (metadata['display_name'] as String?) ??
          (metadata['username'] as String?) ??
          '',
      email: user.email ?? '',
      username: (metadata['username'] as String?) ?? '',
      profilePic: (metadata['avatar_url'] as String?) ?? '',
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
    );
  }

  Future<bool> removeAuth() async {
    try {
      await _client.auth.signOut();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Login com e-mail e senha. Lança [AuthException] em caso de erro —
  /// quem chama decide como exibir a mensagem (próxima leva de arquivos
  /// vai ajustar signin_form.dart para tratar isso).
  Future<void> login(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Cadastro em passo único: cria a conta no Supabase Auth já com
  /// username/display_name no metadata. O profile na tabela `profiles`
  /// é criado automaticamente pelo trigger handle_new_user (schema.sql).
  Future<void> createAccount(
    String fullName,
    String email,
    String password,
  ) async {
    await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'username': fullName.trim(),
        'display_name': fullName.trim(),
      },
    );
  }
}
