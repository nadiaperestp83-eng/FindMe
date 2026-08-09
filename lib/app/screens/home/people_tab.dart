import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/circle_models.dart';
import '../../controllers/home_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pulse_avatar.dart';
import 'home_shell_screen.dart' show showInvitePersonSheet;

class PeopleTab extends GetView<HomeController> {
  const PeopleTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pessoas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showInvitePersonSheet(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Convidar'),
      ),
      body: RefreshIndicator(
        onRefresh: controller.loadPeople,
        color: AppColors.live,
        backgroundColor: AppColors.surface,
        child: Obx(() {
          if (controller.isLoadingPeople.value &&
              controller.sharedMembers.isEmpty &&
              controller.pendingInvites.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.sharedMembers.isEmpty &&
              controller.pendingInvites.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 80, 16, 100),
              children: const [_EmptyPeopleState()],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              if (controller.pendingInvites.isNotEmpty) ...[
                const _SectionLabel('Convites pendentes'),
                ...controller.pendingInvites
                    .map((invite) => _InviteCard(invite: invite)),
                const SizedBox(height: 20),
              ],
              if (controller.sharedMembers.isNotEmpty) ...[
                const _SectionLabel('Compartilhando com você'),
                ...controller.sharedMembers
                    .map((member) => _PersonCard(member: member)),
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _EmptyPeopleState extends StatelessWidget {
  const _EmptyPeopleState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.people_outline, size: 56, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text('Ninguém por aqui ainda',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        const Text(
          'Convide alguém pra começar a ver a\nlocalização em tempo real.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _InviteCard extends GetView<HomeController> {
  const _InviteCard({required this.invite});
  final CircleMemberModel invite;

  @override
  Widget build(BuildContext context) {
    final inviterName =
        invite.profile?.displayName ?? invite.profile?.username ?? 'Alguém';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            PulseAvatar(
                initials: initialsFrom(inviterName), isPending: true, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Convite recebido',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('De $inviterName',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textMuted),
              onPressed: () => controller.declineInvite(invite),
            ),
            IconButton(
              icon: const Icon(Icons.check_circle, color: AppColors.live),
              onPressed: () => controller.acceptInvite(invite),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonCard extends GetView<HomeController> {
  const _PersonCard({required this.member});
  final CircleMemberModel member;

  @override
  Widget build(BuildContext context) {
    final name = member.profile?.displayName ?? member.profile?.username ?? 'Pessoa';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => controller.focusOn(member.userId),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              PulseAvatar(initials: initialsFrom(name), isLive: true, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    Obx(() {
                      final loc = controller.locations[member.userId];
                      return Text(
                        loc != null
                            ? controller.formatLastSeen(loc.updatedAt)
                            : 'Sem localização recente',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      );
                    }),
                  ],
                ),
              ),
              const Icon(Icons.center_focus_strong,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
