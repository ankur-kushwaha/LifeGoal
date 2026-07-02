/// PWA install prompt — no-op on mobile/desktop native platforms.
bool get isPwaInstallAvailable => false;

Future<bool> promptPwaInstall() async => false;

bool get isRunningAsInstalledPwa => false;

Stream<void> get onPwaInstallAvailable => const Stream.empty();

void initPwaInstallListener() {}
