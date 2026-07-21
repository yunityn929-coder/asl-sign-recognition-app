import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'core/constants/app_colors.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Ensure anonymous auth resolves before the first frame so authStateChanges()
  // emits a non-null user immediately and HomeScreen never shows a permanent spinner.
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      await auth.signInAnonymously();
    } catch (_) {}
  }

  // MYT has a fixed UTC+8 offset with no DST, so a static location lookup is safe.
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
  await NotificationService().initialize();

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
