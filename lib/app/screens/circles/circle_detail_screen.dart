import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/circle_models.dart';
import '../../bindings/app_bindings.dart';
import '../../controllers/circle_detail_controller.dart';
import '../../routes/circles_module_routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pulse_avatar.dart';

class CircleDetailScreen extends GetView<CircleDetailController> {
  const CircleDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.circle.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair do círculo',
            onPressed: () => _confirmLeave(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(
          AppRoutes.liveMap,
          arguments: LiveMapArgs(
            circleId: controller.circle.id,
            circleName: controller.circle.name,
            membersById: controller.membersById,
          ),
        ),
        icon: const Icon(Icons.map_rounded),
        label: const Text('Mapa ao vivo'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.members.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: controller.members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _MemberTile(member: controller.members[index]),
              );
            }),
          ),
          _InviteBar(controller: controller),
        ],
      ),
    );
  }

  void _confirmLeave(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sair do círculo?'),
        content: Text(
          'Você deixará de ver e de compartilhar localização com '
          '"${controller.circle.name}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await controller.leaveCircle();
              Get.back(); // fecha o dialog
              Get.back(); // volta pra lista
            },
            child: const Text('Sair', style: TextStyle(color: AppColors.pending)),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});
  final CircleMemberModel member;

  @override
  Widget build(BuildContext context) {
    final name =
        member.profile?.displayName ?? member.profile?.username ?? 'Membro';
    final isAccepted = member.status == CircleMemberStatus.accepted;
    final isPending = member.status == CircleMemberStatus.pending;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            PulseAvatar(
              initials: initialsFrom(name),
              isLive: isAccepted,
              isPending: isPending,
              size: 40,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    _statusLabel(member.status),
                    style: TextStyle(
                      fontSize: 12,
                      color: isPending ? AppColors.pending : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (member.role == 'owner')
              const Icon(Icons.star_rounded, color: AppColors.live, size: 18),
          ],
        ),
      ),
    );
  }

  String _statusLabel(CircleMemberStatus status) {
    switch (status) {
      case CircleMemberStatus.accepted:
        return 'No círculo';
      case CircleMemberStatus.pending:
        return 'Convite pendente';
      case CircleMemberStatus.declined:
        return 'Convite recusado';
    }
  }
}

class _InviteBar extends StatefulWidget {
  const _InviteBar({required this.controller});
  final CircleDetailController controller;

  @override
  State<_InviteBar> createState() => _InviteBarState();
}

class _InviteBarState extends State<_InviteBar> {
  final _usernameController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final ok = await widget.controller.inviteByUsername(_usernameController.text);
    if (ok) _usernameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 90,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            final error = widget.controller.errorMessage.value;
            if (error == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                error,
                style: const TextStyle(color: AppColors.pending, fontSize: 13),
              ),
            );
          }),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    hintText: 'Convidar por username',
                    prefixIcon: Icon(Icons.person_add_alt_1,
                        color: AppColors.textMuted),
                  ),
                  onSubmitted: (_) => _invite(),
                ),
              ),
              const SizedBox(width: 10),
              Obx(
                () => IconButton.filled(
                  onPressed: widget.controller.isInviting.value ? null : _invite,
                  icon: widget.controller.isInviting.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
