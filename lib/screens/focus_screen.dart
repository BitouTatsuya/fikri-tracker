import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity_model.dart';
import '../providers/activity_provider.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import '../widgets/add_edit_activity_sheet.dart';

class FocusScreen extends StatelessWidget {
  final String activityId;

  const FocusScreen({super.key, required this.activityId});

  Future<bool> _confirmSwitchIfNeeded(
    BuildContext context,
    ActivityProvider provider,
  ) async {
    final conflicting = provider.conflictingRunningActivity(activityId);
    if (conflicting == null) return true;

    final targetName = provider.activities
        .firstWhere((a) => a.id == activityId)
        .name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${conflicting.emoji} ${conflicting.name} timer is currently running'),
        content: Text('Pause it and start $targetName instead?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Pause & Start'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityProvider>(
      builder: (context, provider, _) {
        final exists = provider.activities.any((a) => a.id == activityId);
        if (!exists) {
          // Activity was deleted while this screen was open.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          });
          return const SizedBox.shrink();
        }

        final activity = provider.activities.firstWhere((a) => a.id == activityId);
        final remaining = activity.currentRemainingSeconds();
        final completed = activity.currentCompletedSeconds();
        final accent = Color(activity.colorValue);

        return Scaffold(
          appBar: AppBar(
            title: Text(activity.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showAddEditActivitySheet(
                  context,
                  provider: provider,
                  existing: activity,
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(activity.emoji, style: const TextStyle(fontSize: 72)),
                const SizedBox(height: 12),
                Text(
                  activity.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 28),
                Text(
                  formatClock(remaining),
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatBlock(label: 'Completed', value: formatHoursMinutes(completed)),
                    Container(width: 1, height: 36, color: AppColors.secondaryText.withOpacity(0.3)),
                    _StatBlock(label: 'Remaining', value: formatHoursMinutes(remaining)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _statusLabel(activity.status),
                  style: const TextStyle(color: AppColors.secondaryText),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: activity.status == ActivityStatus.completed
                        ? null
                        : () async {
                            if (activity.status == ActivityStatus.running) {
                              await provider.pauseActivity(activity.id);
                            } else if (activity.status == ActivityStatus.paused) {
                              final ok = await _confirmSwitchIfNeeded(context, provider);
                              if (ok) await provider.resumeActivity(activity.id);
                            } else {
                              final ok = await _confirmSwitchIfNeeded(context, provider);
                              if (ok) await provider.startActivity(activity.id);
                            }
                          },
                    child: Text(_primaryButtonLabel(activity.status)),
                  ),
                ),
                const SizedBox(height: 12),
                if (activity.status != ActivityStatus.completed)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await provider.finishActivity(activity.id);
                      },
                      child: const Text('Finish'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _primaryButtonLabel(ActivityStatus status) {
    switch (status) {
      case ActivityStatus.running:
        return 'Pause';
      case ActivityStatus.paused:
        return 'Resume';
      case ActivityStatus.completed:
        return 'Completed';
      case ActivityStatus.notStarted:
        return 'Start';
    }
  }

  String _statusLabel(ActivityStatus status) {
    switch (status) {
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
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;

  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
