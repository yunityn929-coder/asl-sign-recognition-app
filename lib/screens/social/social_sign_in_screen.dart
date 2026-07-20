import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

// S-25 — Google Sign-In (social unlock)
class SocialSignInScreen extends ConsumerStatefulWidget {
  final bool isSignUp;
  const SocialSignInScreen({super.key, required this.isSignUp});

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
      if (widget.isSignUp) {
        final user = await ref
            .read(authServiceProvider)
            .linkWithGoogle()
            .timeout(const Duration(seconds: 15));

        if (user == null) return; // user dismissed picker

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
      } else {
        if (!await _confirmSwitchIfProgressAtRisk()) return;

        final result = await ref
            .read(authServiceProvider)
            .signInWithGoogle()
            .timeout(const Duration(seconds: 15));

        if (result.user == null) return; // user dismissed picker

        if (result.isNewUser) {
          // Genuinely new Google identity — bootstrap its Firestore doc, same
          // as the anonymous flow. Existing accounts load their doc as-is;
          // don't overwrite displayName/email with anonymous-derived values.
          try {
            await ref.read(firestoreServiceProvider).createUser(result.user!.uid);
          } catch (_) {
            // Non-critical: proceed with navigation anyway.
          }
        }
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
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        setState(() => _error =
            'This Google account is already linked to another profile. Try Sign In instead.');
      } else {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Returns false if the user has progress on this device worth losing and
  // cancels the switch; true if it's safe to proceed (no progress, or the
  // user confirmed).
  Future<bool> _confirmSwitchIfProgressAtRisk() async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return true;

    final current = await ref.read(firestoreServiceProvider).getUserOnce(uid);
    final hasProgress = current != null &&
        (current.totalXp > 0 ||
            current.currentStreak > 0 ||
            current.signAccuracy.isNotEmpty);
    if (!hasProgress || !mounted) return true;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch account?'),
        content: const Text(
            "Signing in will replace this device's current progress with your account's data."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(kRouteHome);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  _WelcomeHeroCard(isSignUp: widget.isSignUp),
                  const Spacer(flex: 2),
                  if (_error != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        _GoogleButton(loading: _loading, onTap: _onGoogleTap),
                        const SizedBox(height: 12),
                        _MaybeLaterButton(onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(kRouteHome);
                          }
                        }),
                        const SizedBox(height: 16),
                        const Text(
                          'By continuing you agree to our Terms',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeHeroCard extends StatelessWidget {
  final bool isSignUp;
  const _WelcomeHeroCard({required this.isSignUp});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset('assets/images/owl_welcome.png', width: 260, height: 260),
        const SizedBox(height: 20),
        Text(
          isSignUp ? 'Join us!' : 'Welcome back!',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            isSignUp
                ? 'Create your profile to save your progress.'
                : 'Sign in to pick up right where you left off.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
      ],
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
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                      fontWeight: FontWeight.bold,
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
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary),
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onTap,
        child: const Text('Maybe later', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
