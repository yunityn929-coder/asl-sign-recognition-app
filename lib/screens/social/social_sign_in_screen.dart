import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'widgets/floating_blobs.dart';

// S-25 — Google Sign-In (social unlock)
class SocialSignInScreen extends ConsumerStatefulWidget {
  const SocialSignInScreen({super.key});

  @override
  ConsumerState<SocialSignInScreen> createState() => _SocialSignInScreenState();
}

class _SocialSignInScreenState extends ConsumerState<SocialSignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _onGoogleTap() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = await ref
          .read(authServiceProvider)
          .linkWithGoogle()
          .timeout(const Duration(seconds: 15));

      if (user == null) return; // user dismissed picker

      // Best-effort Firestore update — navigate regardless of result.
      try {
        await ref.read(firestoreServiceProvider).updateUser(user.uid, {
          'isAnonymous': false,
          'authProvider': 'google',
          'displayName': user.displayName ?? 'Learner',
          'email': user.email ?? '',
        });
      } on FirestorePermissionException {
        // Rules not yet deployed — user is still authenticated. Stream will update later.
      } catch (_) {
        // Non-critical: proceed with navigation anyway.
      }

      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(kRouteHome);
        }
      }
    } on TimeoutException {
      setState(() => _error = 'Sign-in timed out. Please try again.');
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 56),
              const Text(
                'HiASL',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Expanded(child: FloatingBlobs()),
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _GoogleButton(loading: _loading, onTap: _onGoogleTap),
              const SizedBox(height: 12),
              _MaybeLaterButton(onTap: () => context.pop()),
              const SizedBox(height: 16),
              const Text(
                'By continuing you agree to our Terms',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.textPrimary.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleIcon(),
                  SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 13,
          height: 1,
        ),
      ),
    );
  }
}

class _MaybeLaterButton extends StatelessWidget {
  const _MaybeLaterButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.textPrimary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'Maybe later',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
