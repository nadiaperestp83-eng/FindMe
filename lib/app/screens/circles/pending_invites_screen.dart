import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/circle_models.dart';
import '../../controllers/circles_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pulse_avatar.dart';

class PendingInvitesScreen extends GetView<CirclesController> {
  const PendingInvitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Convites pendentes')),
      body: Obx(() {
        if (controller.pendingInvites.isEmpty) {
          return const Center(
            child: Text(
              'Nenhum convite pendente.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.pendingInvites.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final invite = controller.pendingInvites[index];
            return _InviteCard(invite: invite);
          },
        );
      }),
    );
  }
}

class _InviteCard extends GetView<CirclesController> {
  const _InviteCard({required this.invite});
  final CircleMemberModel invite;

  @override
  Widget build(BuildContext context) {
    final inviterName =
        invite.profile?.displayName ?? invite.profile?.username ?? 'Alguém';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            PulseAvatar(initials: initialsFrom(inviterName), isPending: true, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Convite para círculo',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Convidado por $inviterName',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textMuted),
              onPressed: () => controller.declineInvite(invite),
              tooltip: 'Recusar',
            ),
            IconButton(
              icon: const Icon(Icons.check_circle, color: AppColors.live),
              onPressed: () => controller.acceptInvite(invite),
              tooltip: 'Aceitar',
            ),
          ],
        ),
      ),
    );
  }
}
