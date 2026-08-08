import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../controllers/live_map_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pulse_avatar.dart';

class LiveMapScreen extends GetView<LiveMapController> {
  const LiveMapScreen({super.key});

  static const _initialCamera = CameraPosition(
    target: LatLng(-1.9441, 30.0619), // fallback: Kigali (ajuste se quiser)
    zoom: 12,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(controller.circleName)),
      body: Stack(
        children: [
          Obx(
            () => GoogleMap(
              initialCameraPosition: _initialCamera,
              onMapCreated: (map) {
                controller.onMapCreated(map);
                map.setMapStyle(_darkMapStyle);
              },
              markers: controller.markers.toSet(),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Obx(
              () => _ShareToggleButton(
                isSharing: controller.isSharingMyLocation.value,
                onTap: controller.toggleMyLocationSharing,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _MembersSheet(controller: controller),
          ),
        ],
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSharing ? Icons.pause_circle : Icons.play_circle,
                size: 18,
                color: isSharing ? AppColors.background : AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                isSharing ? 'Compartilhando' : 'Compartilhar minha posição',
                style: TextStyle(
                  fontSize: 12,
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

class _MembersSheet extends StatelessWidget {
  const _MembersSheet({required this.controller});
  final LiveMapController controller;

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
            final locations = controller.locations.values.toList()
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
                  locations.isEmpty
                      ? 'Ninguém compartilhando localização ainda'
                      : '${locations.length} no mapa agora',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...locations.map((loc) {
                  final isMe = loc.userId == controller.myUserId;
                  final label = isMe
                      ? 'Você'
                      : (controller.membersById[loc.userId]?.profile?.displayName ??
                          controller.membersById[loc.userId]?.profile?.username ??
                          'Membro');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => controller.focusOn(loc.userId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
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
                                    _lastSeenLabel(loc.updatedAt),
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

  String _lastSeenLabel(DateTime updatedAt) {
    final diff = DateTime.now().toUtc().difference(updatedAt.toUtc());
    if (diff.inSeconds < 60) return 'agora mesmo';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    return 'há ${diff.inHours} h';
  }
}

/// Estilo escuro do Google Maps, para casar com a paleta "mapa noturno"
/// do resto do app. Se preferir o mapa padrão, remova a prop `style`
/// do GoogleMap acima.
const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#0F1626"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#0F1626"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8A93A8"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#1B2438"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#12203A"}]},
  {"featureType": "poi", "stylers": [{"visibility": "off"}]}
]
''';
