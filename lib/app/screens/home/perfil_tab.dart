import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/auth.dart';
import '../../../core/supabase_config.dart';
import '../../../services/auth_service.dart';
import '../../controllers/home_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pulse_avatar.dart';
import 'my_timeline_screen.dart';

class PerfilTab extends GetView<HomeController> {
  const PerfilTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SupabaseConfig.currentUser;
    final metadata = user?.userMetadata ?? {};
    final displayName =
        (metadata['display_name'] as String?) ?? (metadata['username'] as String?) ?? 'Você';
    final username = (metadata['username'] as String?) ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  PulseAvatar(initials: initialsFrom(displayName), size: 52),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                          style: Theme.of(context).textTheme.titleMedium),
                      if (username.isNotEmpty)
                        Text('@$username',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Obx(
            () => _SettingRow(
              icon: Icons.location_on_outlined,
              label: controller.isSharingMyLocation.value
                  ? 'Compartilhando minha posição'
                  : 'Compartilhar minha posição',
              trailing: Switch(
                value: controller.isSharingMyLocation.value,
                activeColor: AppColors.live,
                onChanged: (_) => controller.toggleMyLocationSharing(),
              ),
            ),
          ),
          _SettingRow(
            icon: Icons.people_outline,
            label: 'Gerenciar quem me vê',
            onTap: () {
              // A gestão em si já vive na aba Pessoas (aceitar/recusar);
              // aqui é só um atalho visual por enquanto.
            },
          ),
          _SettingRow(
            icon: Icons.timeline,
            label: 'Meu dia',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyTimelineScreen()),
            ),
          ),
          _SettingRow(
            icon: Icons.devices_other_outlined,
            label: 'Dispositivos',
            trailing: const Text('em breve',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          const SizedBox(height: 20),
          _SettingRow(
            icon: Icons.logout,
            label: 'Sair da conta',
            isDanger: true,
            onTap: () async {
              await AuthService().removeAuth();
              Get.find<AuthState>().isSignedIn.value = false;
            },
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.isDanger = false,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? AppColors.pending : AppColors.textPrimary;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
