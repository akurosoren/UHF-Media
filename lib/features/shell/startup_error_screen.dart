import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';

/// Shown instead of the player when startup fails, so the window always
/// appears and the user is not left with an invisible process (spec §9).
class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key, required this.detail});

  final String detail;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: UhfColors.ink,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).startupFailed, style: UhfText.sans(size: 15, weight: 500)),
              const SizedBox(height: 12),
              SelectableText(detail, style: UhfText.mono(size: 11, color: UhfColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
