import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class CalibrationSettingsScreen extends ConsumerStatefulWidget {
  const CalibrationSettingsScreen({super.key});

  @override
  ConsumerState<CalibrationSettingsScreen> createState() =>
      _CalibrationSettingsScreenState();
}

class _CalibrationSettingsScreenState
    extends ConsumerState<CalibrationSettingsScreen> {
  bool? _calibrationEnabled;

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
          'Calibration',
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
        final calibrationEnabled = _calibrationEnabled ?? user.calibrationEnabled;

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            SwitchListTile(
              title: const Text(
                'Apply Calibration',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              value: calibrationEnabled,
              onChanged: (value) {
                setState(() => _calibrationEnabled = value);
                _updateSetting(uid, {'calibrationEnabled': value});
              },
            ),
            ListTile(
              title: const Text(
                'Calibrate my signs',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () => context.push(kRouteCalibration),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load settings')),
    );
  }
}
