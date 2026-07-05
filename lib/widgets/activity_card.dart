import 'package:flutter/material.dart';

import '../models/activity_model.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';

class ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback onTap;

  const ActivityCard({super.key, required this.activity, required this.onTap});

  String get _statusLabel {
    switch (activity.status) {
      case ActivityStatus.running:
        return 'Running';
      case ActivityStatus.paused:
        return 'Paused';
      case ActivityStatus.completed:
        return 'Completed';
      case ActivityStatus.notStarted:
        return 'Not Started';
    }
  }

  Color get _statusColor {
    switch (activity.status) {
      case ActivityStatus.running:
        return AppColors.accent;
      case ActivityStatus.paused:
        return Colors.amber;
      case ActivityStatus.completed:
        return Colors.blueGrey;
      case ActivityStatus.notStarted:
        return AppColors.secondaryText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = activity.currentRemainingSeconds();
    final completed = activity.currentCompletedSeconds();
    final accent = Color(activity.colorValue);

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          child: Row(
            children: [
              Text(activity.emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            label: 'Completed',
                            value: formatHoursMinutes(completed),
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: 'Remaining',
                            value: formatHoursMinutes(remaining),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
