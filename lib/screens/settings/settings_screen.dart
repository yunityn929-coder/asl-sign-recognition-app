import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';

// S-17 — Settings
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _soundEnabled;
  bool _repairAttempted = false;

  void _updateSetting(String uid, Map<String, dynamic> fields) {
    ref
        .read(userActionsProvider(uid))
        .updateSettings(fields)
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text(
          'Settings',
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
          onPressed: () => context.go(kRouteHome),
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
          if (!_repairAttempted) {
            _repairAttempted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(firestoreServiceProvider).createUser(uid).catchError((_) {});
            });
          }
          return const Center(child: CircularProgressIndicator());
        }
        final soundEnabled = _soundEnabled ?? user.soundEnabled;

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const _SectionLabel('Learning'),
            const SizedBox(height: 8),
            _Card(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Sound',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  value: soundEnabled,
                  onChanged: (value) {
                    setState(() => _soundEnabled = value);
                    _updateSetting(uid, {'soundEnabled': value, 'ttsEnabled': value});
                  },
                ),
                ListTile(
                  title: const Text(
                    'Calibration',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                  onTap: () => context.push(kRouteCalibrationSettings),
                ),
                ListTile(
                  title: const Text(
                    'Practice Reminder',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                  onTap: () => context.push(kRouteReminderSettings),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(height: 1, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const _SectionLabel('About'),
            const SizedBox(height: 8),
            _Card(
              children: [
                const ListTile(
                  title: Text(
                    'Version',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  trailing: Text(
                    '1.0.0',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                ),
                ListTile(
                  title: const Text(
                    'Privacy Policy',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                  onTap: () {},
                ),
                ListTile(
                  title: const Text(
                    'Terms of Service',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                  onTap: () {},
                ),
              ],
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 20),
              Divider(height: 1, color: Colors.grey.shade300),
              const SizedBox(height: 20),
              const _SectionLabel('Debug'),
              const SizedBox(height: 8),
              _Card(
                children: [
                  ListTile(
                    title: const Text(
                      'Recognition Test',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () => context.push(kRouteDebugRecognitionTest),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load settings')),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.7,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(children: children);
  }
}
