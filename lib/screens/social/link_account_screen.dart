import 'package:firebase_auth/firebase_auth.dart';
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

// S-25 — Google Sign-In (link current anonymous progress to a Google account)
class LinkAccountScreen extends ConsumerStatefulWidget {
  const LinkAccountScreen({super.key});

  @override
  ConsumerState<LinkAccountScreen> createState() => _LinkAccountScreenState();
}

class _LinkAccountScreenState extends ConsumerState<LinkAccountScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _onGoogleTap() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ref.read(authServiceProvider).linkWithGoogle();

      final user = result.user;
      if (user == null) return; // user dismissed picker

      try {
        await ref.read(firestoreServiceProvider).updateUser(user.uid, {
          'isAnonymous': false,
          'authProvider': 'google',
          'displayName': result.googleDisplayName ?? user.displayName ?? 'Learner',
          'email': result.googleEmail ?? user.email ?? '',
          'photoUrl': result.googlePhotoUrl ?? user.photoURL ?? '',
        });
        debugPrint('[TEMP DEBUG] updateUser succeeded for uid=${user.uid}');
      } on FirestorePermissionException catch (e) {
        debugPrint('[TEMP DEBUG] updateUser threw FirestorePermissionException: $e');
      } catch (e) {
        debugPrint('[TEMP DEBUG] updateUser threw: $e');
      }

      // Always proceed forward on success, regardless of entry point — a
      // completed link should never bounce back to the screen it was
      // launched from.
      if (mounted) context.go(kRouteHome);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        setState(() => _error =
            'This Google account is already linked to another profile. Try Sign In instead.');
      } else {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
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
          'Join us!',
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
            'Create your profile to save your progress.',
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
                          label: 'Link Account with Google',
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
