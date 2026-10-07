import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nesta_core/nesta_core.dart';

import '../theme.dart';

final dateFmt = DateFormat('d MMM y', 'tr');
final dateTimeFmt = DateFormat('d MMM y, HH:mm', 'tr');

String relativeTime(DateTime t, DateTime now) {
  final d = now.difference(t.toLocal());
  if (d.inMinutes < 1) return 'şimdi';
  if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
  if (d.inHours < 24) return '${d.inHours} sa önce';
  if (d.inDays < 7) return '${d.inDays} gün önce';
  return dateFmt.format(t.toLocal());
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color,
              child: Icon(icon, color: PanelColors.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: PanelColors.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ClearanceChip extends StatelessWidget {
  const ClearanceChip(this.status, {super.key});
  final ClearanceStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      ClearanceStatus.approved => (PanelColors.mintSoft, PanelColors.primary),
      ClearanceStatus.pending => (PanelColors.sandSoft, PanelColors.warning),
      ClearanceStatus.rejected => (PanelColors.dangerSoft, PanelColors.danger),
      ClearanceStatus.notRequested => (PanelColors.line, PanelColors.inkSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class ScreeningChip extends StatelessWidget {
  const ScreeningChip(this.outcome, {super.key});
  final ScreeningOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    if (o == null) return const SizedBox.shrink();
    final (bg, fg) = switch (o) {
      ScreeningOutcome.eligible => (PanelColors.mintSoft, PanelColors.primary),
      ScreeningOutcome.needsReview => (
        PanelColors.sandSoft,
        PanelColors.warning,
      ),
      ScreeningOutcome.ineligible => (
        PanelColors.dangerSoft,
        PanelColors.danger,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Tarama: ${o.label}',
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (action != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: action,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key, this.icon = Icons.inbox_outlined});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 40, color: PanelColors.inkSoft),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: PanelColors.inkSoft),
          ),
        ],
      ),
    ),
  );
}

class AlertTile extends StatelessWidget {
  const AlertTile({
    super.key,
    required this.alert,
    required this.now,
    this.onAcknowledge,
    this.onOpen,
  });

  final AlertRecord alert;
  final DateTime now;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final a = alert;
    final color = a.isAcknowledged
        ? PanelColors.inkSoft
        : a.urgent
        ? PanelColors.danger
        : PanelColors.warning;
    return ListTile(
      onTap: onOpen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: a.isAcknowledged
            ? PanelColors.line
            : a.urgent
            ? PanelColors.dangerSoft
            : PanelColors.sandSoft,
        child: Icon(switch (a.type) {
          AlertType.heartRateLimit => Icons.monitor_heart_outlined,
          AlertType.screeningUpdated => Icons.fact_check_outlined,
          _ => Icons.warning_amber_rounded,
        }, color: color),
      ),
      title: Text(
        '${a.patientName} · ${a.type.label}',
        style: TextStyle(
          fontWeight: a.isAcknowledged ? FontWeight.w500 : FontWeight.w800,
        ),
      ),
      subtitle: Text('${a.message}\n${relativeTime(a.createdAt, now)}'),
      isThreeLine: true,
      trailing: a.isAcknowledged
          ? const Tooltip(
              message: 'Görüldü',
              child: Icon(Icons.done_all_rounded, color: PanelColors.primary),
            )
          : onAcknowledge == null
          ? null
          : TextButton(onPressed: onAcknowledge, child: const Text('Görüldü')),
    );
  }
}

/// Basit sütun grafik (son haftaların dakikaları).
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    this.goal,
  });
  final List<int> values;
  final List<String> labels;
  final int? goal;

  @override
  Widget build(BuildContext context) {
    final maxV = [
      ...values,
      goal ?? 0,
      1,
    ].reduce((a, b) => a > b ? a : b).toDouble();
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${values[i]}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: (values[i] / maxV).clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: goal != null && values[i] >= goal!
                                ? PanelColors.primary
                                : PanelColors.mint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: PanelColors.inkSoft,
                      ),
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
