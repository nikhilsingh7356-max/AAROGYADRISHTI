/// Local notification / reminder preferences (device-only, no push infra).
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/storage/storage_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  final _storage = StorageService.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _storage.getBool(AppConstants.keyReminderEnabled);
    final hour = await _storage.getInt('${AppConstants.keyReminderTime}_h');
    final minute = await _storage.getInt('${AppConstants.keyReminderTime}_m');
    if (!mounted) return;
    setState(() {
      _enabled = enabled ?? false;
      if (hour != null && minute != null) {
        _time = TimeOfDay(hour: hour, minute: minute);
      }
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    await _storage.setBool(AppConstants.keyReminderEnabled, value);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked == null || picked == _time) return;
    setState(() => _time = picked);
    await _storage.setInt('${AppConstants.keyReminderTime}_h', picked.hour);
    await _storage.setInt('${AppConstants.keyReminderTime}_m', picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeLabel = _time.format(context);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.notifications)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            AppStrings.notificationsSubtitle,
            style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active_outlined,
                        size: 20, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.reminderTitle,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            AppStrings.reminderBody,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  onChanged: _toggle,
                  title: const Text(
                    'Enabled',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                if (_enabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      AppStrings.reminderTimeLabel,
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeLabel,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded,
                            color: scheme.onSurfaceVariant, size: 22),
                      ],
                    ),
                    onTap: _pickTime,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reminders are saved on this device only. '
                    'No push notifications are sent without server setup.',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
