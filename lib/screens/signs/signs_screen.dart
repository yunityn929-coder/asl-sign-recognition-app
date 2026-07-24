import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/quiz_service.dart';
import '../../providers/user_provider.dart';

const List<String> _kLetters = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];
const List<String> _kNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

enum _SignFilter { all, letters, numbers }

class SignsScreen extends ConsumerStatefulWidget {
  const SignsScreen({super.key});

  @override
  ConsumerState<SignsScreen> createState() => _SignsScreenState();
}

class _SignsScreenState extends ConsumerState<SignsScreen> {
  _SignFilter _filter = _SignFilter.all;
  String _query = '';

  List<String> get _filteredSigns {
    List<String> base;
    switch (_filter) {
      case _SignFilter.letters:
        base = _kLetters;
        break;
      case _SignFilter.numbers:
        base = _kNumbers;
        break;
      case _SignFilter.all:
        base = [..._kLetters, ..._kNumbers];
        break;
    }
    if (_query.isEmpty) return base;
    final q = _query.toUpperCase();
    return base.where((s) => s.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final user = uid == null ? null : ref.watch(userProvider(uid)).value;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterTabs(),
            const SizedBox(height: 8),
            Expanded(child: _buildGrid(user)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Signs',
              style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.3,
          )),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search signs...',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.backgroundAccent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: _filter == _SignFilter.all,
            onTap: () => setState(() => _filter = _SignFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Letters',
            selected: _filter == _SignFilter.letters,
            onTap: () => setState(() => _filter = _SignFilter.letters),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Numbers',
            selected: _filter == _SignFilter.numbers,
            onTap: () => setState(() => _filter = _SignFilter.numbers),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(UserModel? user) {
    final signs = _filteredSigns;
    if (signs.isEmpty) {
      return const Center(
        child: Text('No signs found', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: signs.length,
      itemBuilder: (context, i) {
        final sign = signs[i];
        final accuracy = user?.signAccuracyPercent(sign) ?? -1.0;
        return _SignCard(
          sign: sign,
          accuracy: accuracy,
          onTap: () {},
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.primarySoft),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SignCard extends StatelessWidget {
  final String sign;
  final double accuracy;
  final VoidCallback onTap;
  const _SignCard({required this.sign, required this.accuracy, required this.onTap});

  bool get _hasImage => kAvailableSigns.contains(sign);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primarySoft),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _hasImage
                    ? [
                        Image.asset(
                          '$kSignImagePath$sign.png',
                          height: 70,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 4),
                        Text('Sign $sign',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ]
                    : [
                        Text('Sign $sign',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
              ),
            ),
            Positioned(top: 8, right: 8, child: _AccuracyBadge(accuracy: accuracy)),
          ],
        ),
      ),
    );
  }
}

class _AccuracyBadge extends StatelessWidget {
  final double accuracy;
  const _AccuracyBadge({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    if (accuracy < 0) {
      return const SizedBox.shrink();
    }
    final percent = (accuracy * 100).round();
    if (accuracy >= 0.7) {
      return _badge('★ $percent%', AppColors.success.withValues(alpha: 0.15), AppColors.success);
    }
    return _badge('$percent%', AppColors.warning.withValues(alpha: 0.25), const Color(0xFF9A6100));
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
