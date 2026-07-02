import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool _listenerInitialized = false;
final _installAvailableController = StreamController<void>.broadcast();

void initPwaInstallListener() {
  if (_listenerInitialized) return;
  _listenerInitialized = true;

  web.window.addEventListener(
    'pwa-install-available',
    ((web.Event _) {
      _installAvailableController.add(null);
    }).toJS,
  );

  web.window.addEventListener(
    'pwa-installed',
    ((web.Event _) {
      _installAvailableController.add(null);
    }).toJS,
  );
}

Stream<void> get onPwaInstallAvailable => _installAvailableController.stream;

@JS('deferredPwaPrompt')
external JSObject? get _deferredPwaPrompt;

@JS('installPwaApp')
external JSPromise<JSBoolean?> _installPwaApp();

bool get isPwaInstallAvailable => _deferredPwaPrompt != null;

Future<bool> promptPwaInstall() async {
  final result = await _installPwaApp().toDart;
  return result?.toDart ?? false;
}

bool get isRunningAsInstalledPwa {
  return web.window.matchMedia('(display-mode: standalone)').matches ||
      web.window.matchMedia('(display-mode: minimal-ui)').matches;
}
