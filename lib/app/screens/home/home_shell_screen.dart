import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../controllers/home_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pulse_avatar.dart';
import 'people_tab.dart';
import 'perfil_tab.dart';

/// Tela pós-login única: abre direto no Mapa (sem tela de "Círculos").
/// Navbar inferior fixa troca entre Mapa / Pessoas / Perfil.
class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          _MapTab(),
          PeopleTab(),
          PerfilTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.live.withOpacity(0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.map_rounded, color: AppColors.live),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.people_rounded, color: AppColors.live),
            label: 'Pessoas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.live),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _MapTab extends GetView<HomeController> {
  const _MapTab();

  static const _initialCamera = CameraPosition(
    target: LatLng(-1.9441, 30.0619),
    zoom: 12,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Obx(
          () => GoogleMap(
            initialCameraPosition: _initialCamera,
            mapType: MapType.hybrid,
            onMapCreated: (map) {
              controller.onMapCreated(map);
            },
            markers: controller.markers.toSet(),
            polylines: controller.polylines.toSet(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'FindMe',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Obx(
                  () => _ShareToggleButton(
                    isSharing: controller.isSharingMyLocation.value,
                    onTap: controller.toggleMyLocationSharing,
                  ),
                ),
              ],
            ),
          ),
        ),
        Obx(() {
          if (controller.isLoadingPeople.value) {
            return const SizedBox.shrink();
          }
          return controller.sharedMembers.isEmpty
              ? _EmptyInviteCard()
              : _PeopleSheet(controller: controller);
        }),
      ],
    );
  }
}

class _ShareToggleButton extends StatelessWidget {
  const _ShareToggleButton({required this.isSharing, required this.onTap});
  final bool isSharing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSharing ? AppColors.live : AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSharing ? Icons.pause_circle : Icons.play_circle,
                size: 16,
                color: isSharing ? AppColors.background : AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                isSharing ? 'Compartilhando' : 'Compartilhar',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSharing ? AppColors.background : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vazio: card flutuante, NÃO bloqueia a tela (o mapa continua
/// visível com a posição do usuário atrás dele).
class _EmptyInviteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: SafeArea(
        top: false,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          elevation: 6,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showInvitePersonSheet(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.live.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.person_add_alt_1,
                        color: AppColors.live, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ninguém compartilhando ainda',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Convide alguém pra ver no mapa',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => showInvitePersonSheet(context),
                    style: ElevatedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    child: const Text('Convidar', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gaveta inferior com as pessoas compartilhando — aparece só quando já
/// tem gente. Toque numa pessoa dá zoom na posição dela.
class _PeopleSheet extends StatelessWidget {
  const _PeopleSheet({required this.controller});
  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.16,
      minChildSize: 0.12,
      maxChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Obx(() {
            final locs = controller.locations.values.toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  '${locs.length} no mapa agora',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...locs.map((loc) {
                  final label = controller.labelFor(loc.userId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => controller.focusOn(loc.userId),
                      child: Row(
                        children: [
                          PulseAvatar(
                            initials: initialsFrom(label),
                            isLive: true,
                            size: 36,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label,
                                    style:
                                        Theme.of(context).textTheme.titleMedium),
                                Text(
                                  controller.formatLastSeen(loc.updatedAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.center_focus_strong,
                              size: 18, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        );
      },
    );
  }
}

/// Bottom sheet compartilhado (usado pela aba Mapa e pela aba Pessoas)
/// pra convidar alguém por username.
Future<void> showInvitePersonSheet(BuildContext context) {
  final controller = Get.find<HomeController>();
  final textController = TextEditingController();

  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Convidar pessoa', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'Digite o username de quem você quer ver no mapa.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'username'),
              onSubmitted: (_) async {
                final ok = await controller.invitePerson(textController.text);
                if (ok && ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
            const SizedBox(height: 16),
            Obx(() {
              final error = controller.errorMessage.value;
              if (error == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(error,
                    style: const TextStyle(color: AppColors.pending, fontSize: 13)),
              );
            }),
            Obx(
              () => SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.isInviting.value
                      ? null
                      : () async {
                          final ok =
                              await controller.invitePerson(textController.text);
                          if (ok && ctx.mounted) Navigator.of(ctx).pop();
                        },
                  child: controller.isInviting.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Convidar'),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
