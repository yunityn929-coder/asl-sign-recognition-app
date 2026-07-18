import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';

// S-17 — Settings
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int? _dailyGoalMinutes;
  bool? _ttsEnabled;
  bool? _soundEnabled;

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
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
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
          return const Center(child: Text('User not found'));
        }
        final dailyGoalMinutes = _dailyGoalMinutes ?? user.dailyGoalMinutes;
        final ttsEnabled = _ttsEnabled ?? user.ttsEnabled;
        final soundEnabled = _soundEnabled ?? user.soundEnabled;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionLabel('Learning'),
            const SizedBox(height: 8),
            _Card(
              children: [
                ListTile(
                  leading: const Icon(Icons.flag_outlined,
                      color: AppColors.primary),
                  title: const Text('Daily Goal'),
                  subtitle: Text('$dailyGoalMinutes minutes per day'),
                  trailing: DropdownButton<int>(
                    value: dailyGoalMinutes,
                    underline: const SizedBox.shrink(),
                    items: const [5, 10, 15, 20]
                        .map((m) =>
                            DropdownMenuItem(value: m, child: Text('$m')))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _dailyGoalMinutes = value);
                      _updateSetting(uid, {'dailyGoalMinutes': value});
                    },
                  ),
                ),
                const Divider(indent: 56, height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.record_voice_over_outlined,
                      color: AppColors.primary),
                  title: const Text('Text to Speech'),
                  subtitle: const Text('Read signs aloud during lessons'),
                  value: ttsEnabled,
                  onChanged: (value) {
                    setState(() => _ttsEnabled = value);
                    _updateSetting(uid, {'ttsEnabled': value});
                  },
                ),
                const Divider(indent: 56, height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined,
                      color: AppColors.primary),
                  title: const Text('Sound Effects'),
                  subtitle: const Text('Play sounds on correct answers'),
                  value: soundEnabled,
                  onChanged: (value) {
                    setState(() => _soundEnabled = value);
                    _updateSetting(uid, {'soundEnabled': value});
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('About'),
            const SizedBox(height: 8),
            _Card(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.primary),
                  title: Text('Version'),
                  trailing: Text('1.0.0',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
                const Divider(indent: 56, height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: AppColors.primary),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new,
                      color: AppColors.textSecondary),
                  onTap: () {},
                ),
                const Divider(indent: 56, height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined,
                      color: AppColors.primary),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.open_in_new,
                      color: AppColors.textSecondary),
                  onTap: () {},
                ),
              ],
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              const _SectionLabel('Debug'),
              const SizedBox(height: 8),
              _Card(
                children: [
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined,
                        color: AppColors.primary),
                    title: const Text('Recognition Test'),
                    subtitle: const Text(
                        'Physical-device gesture recognition diagnostics'),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () => context.push(kRouteDebugRecognitionTest),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (!mounted) return;
                  context.go(kRouteSplash);
                },
                child: const Text(
                  'Sign out',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 24),
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
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primarySoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
