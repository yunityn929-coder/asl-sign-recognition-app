import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/notification_service.dart';

class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  ConsumerState<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends ConsumerState<ReminderSettingsScreen> {
  bool? _reminderEnabled;
  int? _reminderHour;
  int? _reminderMinute;

  void _updateSetting(String uid, Map<String, dynamic> fields) {
    ref.read(userActionsProvider(uid)).updateSettings(fields).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text(
          'Practice Reminder',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(uid),
    );
  }

  Widget _buildBody(String uid) {
    final userAsync = ref.watch(userProvider(uid));

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final reminderEnabled = _reminderEnabled ?? user.reminderEnabled;
        final reminderHour = _reminderHour ?? user.reminderHour;
        final reminderMinute = _reminderMinute ?? user.reminderMinute;
        final time = TimeOfDay(hour: reminderHour, minute: reminderMinute);

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            SwitchListTile(
              title: const Text(
                'Practice Reminder',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              value: reminderEnabled,
              onChanged: (value) async {
                setState(() => _reminderEnabled = value);
                _updateSetting(uid, {'reminderEnabled': value});
                final notificationService = ref.read(notificationServiceProvider);
                if (value) {
                  await notificationService.scheduleDailyReminder(reminderHour, reminderMinute);
                } else {
                  await notificationService.cancelReminder();
                }
              },
            ),
            ListTile(
              title: const Text(
                'Reminder Time',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              trailing: Text(
                time.format(context),
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: time);
                if (picked == null || !mounted) return;
                setState(() {
                  _reminderHour = picked.hour;
                  _reminderMinute = picked.minute;
                });
                _updateSetting(uid, {
                  'reminderHour': picked.hour,
                  'reminderMinute': picked.minute,
                });
                if (reminderEnabled) {
                  await ref
                      .read(notificationServiceProvider)
                      .scheduleDailyReminder(picked.hour, picked.minute);
                }
              },
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load settings')),
    );
  }
}
