import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/account.dart';
import '../screens/components/top_snackbar.dart';

/// Antes: falava com o backend Node.js via Dio + cachava a sessão no
/// Hive. Agora: fala direto com o Supabase Auth, que já persiste e
/// restaura a sessão sozinho — então os métodos de cache manual
/// (addAuth) saíram, e getAuth()/removeAuth() passaram a consultar a
/// sessão do Supabase.
///
/// Como o cadastro virou 1 passo só (sem OTP por e-mail, sem tela de
/// criar perfil separada — o profile é criado automaticamente pelo
/// trigger handle_new_user no banco), os métodos resendOTP, verifyOTP,
/// createProfile e getProfile não existem mais aqui.
///
/// onDioError, onUnkownError e getAuthToken() foram MANTIDOS porque
/// lib/services/db_service.dart ainda fala com o backend Node antigo
/// (movements/notifications) — isso ainda não foi migrado pro Supabase,
/// é a próxima etapa depois de fecharmos auth.
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

  /// TODO: usado hoje só por db_service.dart pra autenticar chamadas no
  /// backend Node antigo. Quando db_service.dart for migrado pro
  /// Supabase (próxima etapa), este método deixa de ser necessário.
  String? getAuthToken() => _client.auth.currentSession?.accessToken;

  Future<bool> removeAuth() async {
    try {
      await _client.auth.signOut();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Login com e-mail e senha. Lança [AuthException] em caso de erro —
  /// quem chama decide como exibir a mensagem (signin_form.dart já trata).
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

/// Mantido tal e qual o original — db_service.dart chama isso em vários
/// pontos que ainda usam Dio contra o backend Node antigo.
void onDioError(DioError e) {
  if (e.response != null) {
    final data = e.response?.data;
    try {
      showMessage(
        message: data["message"],
        title: data["data"] ?? "Something went wrong",
        type: MessageType.error,
      );
    } catch (e) {
      showMessage(
        message:
            "Something went wrong | Unknown error occured, try again later or contact admin",
        title: "Internal Server Error",
        type: MessageType.error,
      );
    }
  } else {
    String msg = e.message ?? "Unkown error";
    if (DioErrorType.receiveTimeout == e.type ||
        DioErrorType.sendTimeout == e.type) {
      msg =
          "Server is not reachable. Please verify your internet connection and try again";
    } else {
      msg = "Problem connecting to the server. Please try again.";
    }
    showMessage(
      message: msg,
      title: "Something went wrong",
      type: MessageType.error,
    );
  }
}

/// Mantido tal e qual o original — usado por db_service.dart e pelas
/// telas de auth (signin_form.dart, create_account.dart) em catch(e) genérico.
void onUnkownError(Object e) {
  showMessage(
    message: e.toString(),
    title: "Something went wrong",
    type: MessageType.error,
  );
}

void onSuccess({required String title, required String message}) {
  showMessage(
    message: message,
    title: title,
    type: MessageType.success,
  );
}
