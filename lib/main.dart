import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_colors.dart';
import 'firebase_options.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Ensure anonymous auth resolves before the first frame so authStateChanges()
  // emits a non-null user immediately and HomeScreen never shows a permanent spinner.
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      await auth.signInAnonymously();
    } catch (_) {}
  }

  runApp(const ProviderScope(child: HiAslApp()));
}

class HiAslApp extends StatelessWidget {
  const HiAslApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HiASL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          surface: AppColors.backgroundPrimary,
        ),
        scaffoldBackgroundColor: AppColors.backgroundPrimary,
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
