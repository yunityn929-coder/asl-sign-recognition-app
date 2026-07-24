import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'widgets/social_auth_widgets.dart';

// S-25 — Google Sign-In (switch to a different existing account)
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _onGoogleTap() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (!await _confirmSwitchIfProgressAtRisk()) return;

      final result = await ref.read(authServiceProvider).signInWithGoogle();

      if (result.user == null) return; // user dismissed picker

      if (result.isNewUser) {
        // No account was ever registered under this Google identity — undo
        // the Firebase Auth user signInWithCredential() just auto-created
        // and fall back to an anonymous session instead of treating this as
        // a successful sign-in.
        try {
          await result.user!.delete();
        } catch (_) {
          // Best-effort cleanup only.
        }
        await ref.read(authServiceProvider).signInSilently();
        setState(() => _error =
            "We couldn't find an account for this Google sign-in. Try Create Profile instead.");
        return;
      }

      // Always proceed forward on success, regardless of entry point — a
      // completed sign-in should never bounce back to the pre-auth screen
      // it was launched from (e.g. Welcome Brand).
      if (mounted) context.go(kRouteHome);
    } on PlatformException {
      setState(() => _error = "Google sign-in didn't complete. Please try again.");
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
            "Signing in will cause your current progress to be lost and cannot be recovered."),
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

  Widget _buildHero(BuildContext context) {
    return Column(
      children: [
        Image.asset('assets/images/owl_welcome.png', width: 260, height: 260),
        const SizedBox(height: 20),
        const Text(
          'Welcome back!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Sign in to pick up right where you left off.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
      ],
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
                  _buildHero(context),
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
                        GoogleButton(
                          loading: _loading,
                          onTap: _onGoogleTap,
                          label: 'Sign In with Google',
                        ),
                        const SizedBox(height: 12),
                        MaybeLaterButton(onTap: () {
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
