import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

// Generated from android/app/google-services.json
// project: hiasl-5b861  |  package: com.hiasl.app
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web platform not configured for HiASL.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS not configured for HiASL.');
      default:
        throw UnsupportedError('Platform not configured for HiASL.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBpQywtIJrcnlSFEDVLI51Swi_qhjDF91g',
    appId: '1:875587847059:android:350b004c3737c21b515e66',
    messagingSenderId: '875587847059',
    projectId: 'hiasl-5b861',
    storageBucket: 'hiasl-5b861.firebasestorage.app',
  );
}
