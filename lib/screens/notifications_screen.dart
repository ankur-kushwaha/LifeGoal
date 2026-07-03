import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Scaffold(
      backgroundColor: kScaffoldBg,
      appBar: AppBar(
        backgroundColor: kCardBg,
        elevation: 0,
        title: const Text('AI Suggestions', style: TextStyle(color: Colors.black87)),
        actions: [
          if (provider.notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black54),
              onSelected: (value) async {
                if (value == 'mark_read') {
                  await provider.markAllAsRead();
                } else if (value == 'clear_all') {
                  final confirmed = await _confirmClearAll(context);
                  if (confirmed == true && context.mounted) {
                    await provider.clearAllNotifications();
                  }
                }
              },
              itemBuilder: (context) => [
                if (provider.unreadCount > 0)
                  const PopupMenuItem(
                    value: 'mark_read',
                    child: Row(
                      children: [
                        Icon(Icons.done_all, size: 20, color: kMoneyGreen),
                        SizedBox(width: 8),
                        Text('Mark all read'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Clear all'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          _buildTriggerBar(context, provider),
          if (provider.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(provider.error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: provider.notifications.isEmpty
                ? _buildEmptyState(theme)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notification = provider.notifications[index];
                      return _NotificationCard(
                        notification: notification,
                        dateFormat: dateFormat,
                        onTap: () {
                          if (!notification.isRead) {
                            provider.markAsRead(notification.id);
                          }
                        },
                        onDelete: () => provider.deleteNotification(notification.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmClearAll(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Clear all suggestions?', style: TextStyle(color: Colors.black87)),
        content: const Text(
          'This will permanently delete all AI suggestions for your family.',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildTriggerBar(BuildContext context, NotificationProvider provider) {
    return Container(
      width: double.infinity,
      color: kCardBg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Get a personalized next action based on your goals.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: provider.isGenerating ? null : () => provider.triggerCustom(),
            icon: provider.isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome, size: 20),
            label: Text(provider.isGenerating ? 'Generating...' : 'Get AI Suggestion Now'),
            style: FilledButton.styleFrom(
              backgroundColor: kMoneyGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No suggestions yet',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the button above or wait for your daily 10 AM suggestion.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.notification,
    required this.dateFormat,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final triggerLabel = switch (notification.trigger) {
      NotificationTrigger.scheduled => 'Scheduled',
      NotificationTrigger.custom => 'Custom',
      NotificationTrigger.event => 'Event',
    };

    return Material(
      color: notification.isRead ? kCardBg : kCardBg.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(16),
      elevation: notification.isRead ? 1 : 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead ? Colors.grey.shade200 : kMoneyGreen.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8, top: 6),
                      decoration: const BoxDecoration(
                        color: kMoneyGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      notification.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (notification.isAiGenerated) const _AiChip(),
                  const SizedBox(width: 6),
                  _TriggerChip(label: triggerLabel),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Delete',
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(notification.body, style: const TextStyle(color: Colors.black87, height: 1.4)),
              const SizedBox(height: 12),
              if (notification.suggestionType == SuggestionType.addNewGoal &&
                  notification.suggestedNewGoalName != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_circle_outline, size: 18, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Suggested new goal',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.suggestedNewGoalName!,
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                      ),
                      if (notification.suggestedNewGoalTargetCost != null ||
                          notification.suggestedNewGoalMonths != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            [
                              if (notification.suggestedNewGoalTargetCost != null)
                                'Target: ₹${NumberFormat.decimalPattern('en_IN').format(notification.suggestedNewGoalTargetCost!.round())}',
                              if (notification.suggestedNewGoalMonths != null)
                                'Timeline: ${notification.suggestedNewGoalMonths} months',
                              if (notification.suggestedNewGoalAccount != null)
                                'For: ${notification.suggestedNewGoalAccount}',
                            ].join(' · '),
                            style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kMoneyGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.tips_and_updates_outlined, color: kMoneyGreen, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notification.suggestedAction,
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                dateFormat.format(notification.createdAt),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiChip extends StatelessWidget {
  const _AiChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kMoneyGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: kMoneyGreen),
          SizedBox(width: 4),
          Text(
            'AI',
            style: TextStyle(fontSize: 11, color: kMoneyGreen, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TriggerChip extends StatelessWidget {
  final String label;

  const _TriggerChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
    );
  }
}
