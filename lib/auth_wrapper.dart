import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controllers/auth.dart';
import 'core/supabase_config.dart';
import 'screens/authentication/welcome.dart';
import 'screens/layout.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final auth = Get.put(AuthState());

  @override
  void initState() {
    super.initState();
    _init();

    // Mantém isSignedIn sincronizado se a sessão mudar durante o uso do
    // app (logout em outro lugar, token expirado, etc).
    SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      auth.isSignedIn.value = data.session != null;
      auth.email.value = data.session?.user.email ?? "";
    });
  }

  // Antes: lia a conta salva no Hive via AuthService().getAuth().
  // Agora: o supabase_flutter já restaura a sessão sozinho (persistida
  // localmente) assim que SupabaseConfig.initialize() roda no main.dart
  // — só precisamos perguntar pra ele se já existe sessão ativa.
  void _init() {
    final session = SupabaseConfig.client.auth.currentSession;
    auth.isSignedIn.value = session != null;
    auth.email.value = session?.user.email ?? "";
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => auth.isSignedIn.value ? const LayoutPage() : const WelcomeScreen(),
    );
  }
}
