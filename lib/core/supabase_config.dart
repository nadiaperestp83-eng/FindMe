import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Substitui inteiramente a antiga camada de rede (Dio + Socket.io)
/// do QuickStep original. Toda comunicação de rede do app agora passa
/// por este cliente único do Supabase.
///
/// Requer no arquivo assets/dotenv/.env (mesmo padrão já usado pelo
/// projeto original):
///   SUPABASE_URL=https://xxxxx.supabase.co
///   SUPABASE_ANON_KEY=eyJhbGciOi...
class SupabaseConfig {
  SupabaseConfig._();

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    assert(
      url != null && anonKey != null,
      'SUPABASE_URL e SUPABASE_ANON_KEY precisam estar definidos em '
      'assets/dotenv/.env',
    );

    await Supabase.initialize(
      url: url!,
      anonKey: anonKey!,
      realtimeClientOptions: const RealtimeClientOptions(
        // Reconecta rápido em troca de rede (wifi <-> dados móveis),
        // importante para o cenário de rastreamento contínuo.
        eventsPerSecond: 10,
      ),
    );
  }

  /// Usuário autenticado atual (ou null).
  static User? get currentUser => client.auth.currentUser;

  static bool get isLoggedIn => currentUser != null;
}
