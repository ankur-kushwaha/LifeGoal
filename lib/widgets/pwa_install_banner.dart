import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/pwa_install.dart';

/// Shows an install banner on supported browsers when the PWA can be added to the home screen.
class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  bool _visible = false;
  bool _installing = false;
  bool _dismissed = false;
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb || isRunningAsInstalledPwa) return;

    initPwaInstallListener();
    _refreshVisibility();
    _subscription = onPwaInstallAvailable.listen((_) => _refreshVisibility());
  }

  void _refreshVisibility() {
    if (!mounted || _dismissed) return;
    setState(() => _visible = isPwaInstallAvailable);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _install() async {
    setState(() => _installing = true);
    final accepted = await promptPwaInstall();
    if (!mounted) return;
    setState(() {
      _installing = false;
      if (accepted) _visible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_visible || isRunningAsInstalledPwa) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kMoneyGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMoneyGreen.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.install_mobile, color: kMoneyGreen, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Install LifeGoal AI',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Add to your home screen for quick access.',
                  style: TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ),
          if (_installing)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: kMoneyGreen),
            )
          else ...[
            TextButton(
              onPressed: _install,
              child: const Text('Install', style: TextStyle(color: kMoneyGreen, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.black38),
              onPressed: () => setState(() {
                _dismissed = true;
                _visible = false;
              }),
            ),
          ],
        ],
      ),
    );
  }
}
