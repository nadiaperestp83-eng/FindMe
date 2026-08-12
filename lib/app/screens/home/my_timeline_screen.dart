import 'package:flutter/material.dart';

import '../../../data/repositories/route_history_repository.dart';
import '../../theme/app_theme.dart';

/// Linha do tempo do dia — "Parado há 4h" / "Em trânsito há 15 min".
/// Calculada 100% a partir do Hive local (ver route_history_repository).
/// Por enquanto só mostra o SEU próprio dia (ver nota no repositório
/// sobre por que a versão "de outra pessoa" é um passo à parte).
class MyTimelineScreen extends StatefulWidget {
  const MyTimelineScreen({super.key});

  @override
  State<MyTimelineScreen> createState() => _MyTimelineScreenState();
}

class _MyTimelineScreenState extends State<MyTimelineScreen> {
  final _repository = RouteHistoryRepository();
  late List<TimelineSegment> _segments;

  @override
  void initState() {
    super.initState();
    _segments = _repository.buildTimeline();
  }

  void _refresh() {
    setState(() {
      _segments = _repository.buildTimeline();
    });
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return 'menos de 1 min';
    if (d.inHours < 1) return '${d.inMinutes} min';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu dia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _refresh,
          ),
        ],
      ),
      body: _segments.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Ainda não há trajeto registrado hoje. Ligue '
                  '"Compartilhar" na aba Mapa e ande um pouco pra '
                  'começar a ver sua linha do tempo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              itemCount: _segments.length,
              itemBuilder: (context, index) {
                return _TimelineTile(
                  segment: _segments[index],
                  formatDuration: _formatDuration,
                  formatTime: _formatTime,
                  isLast: index == _segments.length - 1,
                );
              },
            ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.segment,
    required this.formatDuration,
    required this.formatTime,
    required this.isLast,
  });

  final TimelineSegment segment;
  final String Function(Duration) formatDuration;
  final String Function(DateTime) formatTime;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = segment.isStop ? AppColors.live : AppColors.textMuted;
    final icon = segment.isStop ? Icons.location_on : Icons.directions_walk;
    final label = segment.isStop
        ? 'Parado há ${formatDuration(segment.duration)}'
        : 'Em trânsito há ${formatDuration(segment.duration)}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppColors.border),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatTime(segment.start)} — ${formatTime(segment.end)}',
                    style:
                        const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
