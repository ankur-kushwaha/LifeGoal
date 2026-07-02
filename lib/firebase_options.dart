// GENERATED from Firebase config — do not edit by hand.
// Re-run: dart run tool/generate_firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAS-pI1BhW-xECiyokWFMFOE8X1wIk63Hw',
    appId: '1:599945759594:web:3bc2a9ca20bd9e7be1f313',
    messagingSenderId: '599945759594',
    projectId: 'mymaps-b534f',
    authDomain: 'mymaps-b534f.firebaseapp.com',
    storageBucket: 'mymaps-b534f.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBjY4l6T1StceUty2r3DwhcGOFwN4TX0co',
    appId: '1:599945759594:android:17aa1b6d4e05f869e1f313',
    messagingSenderId: '599945759594',
    projectId: 'mymaps-b534f',
    storageBucket: 'mymaps-b534f.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBjY4l6T1StceUty2r3DwhcGOFwN4TX0co',
    appId: '1:599945759594:android:17aa1b6d4e05f869e1f313',
    messagingSenderId: '599945759594',
    projectId: 'mymaps-b534f',
    storageBucket: 'mymaps-b534f.firebasestorage.app',
    iosBundleId: 'com.lifegoal.app.lifegoalApp',
  );

  static bool get isConfigured {
    return android.apiKey.isNotEmpty && android.apiKey != 'your-android-api-key';
  }

  static String? get googleWebClientId {
    return '599945759594-avso0q2ljq9u0ge0eb1nvrrqndssm8td.apps.googleusercontent.com';
  }
}
