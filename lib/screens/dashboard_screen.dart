import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity_model.dart';
import '../providers/activity_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_card.dart';
import '../widgets/add_edit_activity_sheet.dart';
import 'focus_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, ActivityProvider provider, ActivityModel a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete activity?'),
        content: Text('"${a.name}" will be removed permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteActivity(a.id);
    }
  }

  Future<void> _confirmResetDay(BuildContext context, ActivityProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Today?'),
        content: const Text('All activities will go back to their full target duration.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.resetDay();
    }
  }

  Future<bool> _confirmSwitchIfNeeded(
    BuildContext context,
    ActivityProvider provider,
    ActivityModel target,
  ) async {
    final conflicting = provider.conflictingRunningActivity(target.id);
    if (conflicting == null) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${conflicting.emoji} ${conflicting.name} timer is currently running'),
        content: Text('Pause it and start ${target.name} instead?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Pause & Start')),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fikri Tracker'),
        actions: [
          Consumer<ActivityProvider>(
            builder: (context, provider, _) => IconButton(
              tooltip: 'Reset Today',
              icon: const Icon(Icons.refresh),
              onPressed: provider.activities.isEmpty
                  ? null
                  : () => _confirmResetDay(context, provider),
            ),
          ),
        ],
      ),
      body: Consumer<ActivityProvider>(
        builder: (context, provider, _) {
          if (!provider.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.activities.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: provider.activities.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final activity = provider.activities[index];
              return Dismissible(
                key: ValueKey(activity.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
                confirmDismiss: (_) async {
                  await _confirmDelete(context, provider, activity);
                  return false; // deletion itself handled by provider/state
                },
                child: GestureDetector(
                  onLongPress: () => showAddEditActivitySheet(
                    context,
                    provider: provider,
                    existing: activity,
                  ),
                  child: ActivityCard(
                    activity: activity,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FocusScreen(activityId: activity.id),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Consumer<ActivityProvider>(
        builder: (context, provider, _) => FloatingActionButton.extended(
          onPressed: () => showAddEditActivitySheet(context, provider: provider),
          icon: const Icon(Icons.add),
          label: const Text('Add Activity'),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗓️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              'No activities yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap "Add Activity" to set your first daily target, e.g. Productive - 7 Hours.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}
