import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// O elemento de assinatura do app: um anel que "respira" atrás do avatar
/// de um membro cuja localização está sendo transmitida agora. É o único
/// lugar com animação — usado com moderação, só onde presença ao vivo
/// importa (lista de membros e bottom sheet do mapa).
class PulseAvatar extends StatefulWidget {
  const PulseAvatar({
    super.key,
    required this.initials,
    this.isLive = false,
    this.isPending = false,
    this.size = 44,
  });

  final String initials;
  final bool isLive;
  final bool isPending;
  final double size;

  @override
  State<PulseAvatar> createState() => _PulseAvatarState();
}

class _PulseAvatarState extends State<PulseAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.isPending ? AppColors.pending : AppColors.live;

    return SizedBox(
      width: widget.size * 1.6,
      height: widget.size * 1.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isLive)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                return Opacity(
                  opacity: (1 - t) * 0.5,
                  child: Container(
                    width: widget.size + (widget.size * 0.6 * t),
                    height: widget.size + (widget.size * 0.6 * t),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.live,
                    ),
                  ),
                );
              },
            ),
          Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceRaised,
              border: Border.all(color: ringColor, width: 2),
            ),
            child: Text(
              widget.initials,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Extrai iniciais (até 2 letras) de um nome ou username para o PulseAvatar.
String initialsFrom(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
