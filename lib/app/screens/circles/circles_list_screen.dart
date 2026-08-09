import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/auth.dart';
import '../../../services/auth_service.dart';
import '../../../data/models/circle_models.dart';
import '../../controllers/circles_controller.dart';
import '../../routes/circles_module_routes.dart';
import '../../theme/app_theme.dart';
import 'widgets/create_circle_sheet.dart';

class CirclesListScreen extends GetView<CirclesController> {
  const CirclesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seus círculos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair da conta',
            onPressed: () async {
              // Mesmo padrão do resto do app: AuthService fala com o
              // Supabase, AuthState guarda o estado reativo global.
              await AuthService().removeAuth();
              Get.find<AuthState>().isSignedIn.value = false;
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateCircleSheet(context),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: controller.loadAll,
        color: AppColors.live,
        backgroundColor: AppColors.surface,
        child: Obx(() {
          if (controller.isLoading.value && controller.circles.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              if (controller.pendingInvites.isNotEmpty)
                _PendingInvitesBanner(count: controller.pendingInvites.length),
              if (controller.circles.isEmpty && !controller.isLoading.value)
                const _EmptyState()
              else
                ...controller.circles.map(
                  (circle) => _CircleCard(circle: circle),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _PendingInvitesBanner extends StatelessWidget {
  const _PendingInvitesBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.pending.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Get.toNamed(AppRoutes.pendingInvites),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.mail_outline, color: AppColors.pending),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    count == 1
                        ? 'Você tem 1 convite pendente'
                        : 'Você tem $count convites pendentes',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.pending),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleCard extends StatelessWidget {
  const _CircleCard({required this.circle});
  final CircleModel circle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Get.toNamed(AppRoutes.circleDetail, arguments: circle),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.live.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.groups_rounded,
                      color: AppColors.live),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    circle.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          const Icon(Icons.groups_outlined, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'Nenhum círculo ainda',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'Crie um círculo para começar a acompanhar\nfamília ou amigos em tempo real.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
