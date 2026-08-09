import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controllers/auth.dart';
import 'core/supabase_config.dart';
import 'app/controllers/home_controller.dart';
import 'app/screens/home/home_shell_screen.dart';
import 'screens/authentication/welcome.dart';

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
      () => auth.isSignedIn.value ? _buildHome() : const WelcomeScreen(),
    );
  }

  Widget _buildHome() {
    // HomeShellScreen usa GetView<HomeController>, que exige o controller
    // já registrado via Get.put ANTES do build — mesmo motivo do crash
    // "CirclesController not found" de antes: o AuthWrapper troca de tela
    // direto, sem passar pelo Binding do GetPage.
    if (!Get.isRegistered<HomeController>()) {
      Get.put(HomeController());
    }
    return const HomeShellScreen();
  }
}
