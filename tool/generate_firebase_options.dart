import 'dart:convert';
import 'dart:io';

/// Generates lib/firebase_options.dart from android/app/google-services.json.
void main() {
  final jsonFile = File('android/app/google-services.json');
  if (!jsonFile.existsSync()) {
    stderr.writeln('Missing android/app/google-services.json — run scripts/setup_firebase.sh first.');
    exit(1);
  }

  final root = jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
  final projectInfo = root['project_info'] as Map<String, dynamic>;
  final clients = root['client'] as List<dynamic>;

  Map<String, dynamic>? androidClient;
  for (final client in clients) {
    final info = (client as Map<String, dynamic>)['client_info'] as Map<String, dynamic>;
    final androidInfo = info['android_client_info'] as Map<String, dynamic>?;
    if (androidInfo != null &&
        androidInfo['package_name'] == 'com.lifegoal.app.lifegoal_app') {
      androidClient = client;
      break;
    }
  }

  androidClient ??= clients.first as Map<String, dynamic>;

  final clientInfo = androidClient['client_info'] as Map<String, dynamic>;
  final apiKeys = androidClient['api_key'] as List<dynamic>;
  final oauthClients = androidClient['oauth_client'] as List<dynamic>? ?? [];

  final projectId = projectInfo['project_id'] as String;
  final projectNumber = projectInfo['project_number'] as String;
  final storageBucket = projectInfo['storage_bucket'] as String? ?? '$projectId.appspot.com';
  final androidAppId = clientInfo['mobilesdk_app_id'] as String;
  final androidApiKey = (apiKeys.first as Map<String, dynamic>)['current_key'] as String;

  String? webClientId;
  for (final oauth in oauthClients) {
    final map = oauth as Map<String, dynamic>;
    if (map['client_type'] == 3) {
      webClientId = map['client_id'] as String?;
      break;
    }
  }

  final webApiKey = androidApiKey;
  final webAppId = androidAppId;

  final buffer = StringBuffer()
    ..writeln("// GENERATED FILE — do not edit by hand.")
    ..writeln("// Run: dart run tool/generate_firebase_options.dart")
    ..writeln("import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;")
    ..writeln("import 'package:flutter/foundation.dart'")
    ..writeln("    show defaultTargetPlatform, kIsWeb, TargetPlatform;")
    ..writeln('')
    ..writeln('class DefaultFirebaseOptions {')
    ..writeln('  static FirebaseOptions get currentPlatform {')
    ..writeln('    if (kIsWeb) {')
    ..writeln('      return web;')
    ..writeln('    }')
    ..writeln('    switch (defaultTargetPlatform) {')
    ..writeln('      case TargetPlatform.android:')
    ..writeln('        return android;')
    ..writeln('      case TargetPlatform.iOS:')
    ..writeln('        return ios;')
    ..writeln('      default:')
    ..writeln("        throw UnsupportedError(")
    ..writeln("          'DefaultFirebaseOptions are not supported for this platform.',")
    ..writeln('        );')
    ..writeln('    }')
    ..writeln('  }')
    ..writeln('')
    ..writeln('  static const FirebaseOptions web = FirebaseOptions(')
    ..writeln("    apiKey: '$webApiKey',")
    ..writeln("    appId: '$webAppId',")
    ..writeln("    messagingSenderId: '$projectNumber',")
    ..writeln("    projectId: '$projectId',")
    ..writeln("    authDomain: '$projectId.firebaseapp.com',")
    ..writeln("    storageBucket: '$storageBucket',")
    ..writeln('  );')
    ..writeln('')
    ..writeln('  static const FirebaseOptions android = FirebaseOptions(')
    ..writeln("    apiKey: '$androidApiKey',")
    ..writeln("    appId: '$androidAppId',")
    ..writeln("    messagingSenderId: '$projectNumber',")
    ..writeln("    projectId: '$projectId',")
    ..writeln("    storageBucket: '$storageBucket',")
    ..writeln('  );')
    ..writeln('')
    ..writeln('  static const FirebaseOptions ios = FirebaseOptions(')
    ..writeln("    apiKey: '$androidApiKey',")
    ..writeln("    appId: '$androidAppId',")
    ..writeln("    messagingSenderId: '$projectNumber',")
    ..writeln("    projectId: '$projectId',")
    ..writeln("    storageBucket: '$storageBucket',")
    ..writeln("    iosBundleId: 'com.lifegoal.app.lifegoalApp',")
    ..writeln('  );')
    ..writeln('')
    ..writeln('  static bool get isConfigured {')
    ..writeln("    return android.apiKey.isNotEmpty && android.apiKey != 'your-android-api-key';")
    ..writeln('  }')
    ..writeln('')
    ..writeln('  static String? get googleWebClientId {')
    ..writeln(webClientId != null ? "    return '$webClientId';" : '    return null;')
    ..writeln('  }')
    ..writeln('}');

  File('lib/firebase_options.dart').writeAsStringSync(buffer.toString());
  stdout.writeln('Wrote lib/firebase_options.dart (project: $projectId)');
}
