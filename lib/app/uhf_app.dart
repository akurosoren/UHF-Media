import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../ui/theme.dart';

class UhfApp extends StatelessWidget {
  const UhfApp({super.key, this.home, this.locale});

  final Widget? home;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UHF Media',
      theme: buildUhfTheme(),
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (device, supported) {
        if (device == null) return const Locale('en');
        for (final locale in supported) {
          if (locale.languageCode == device.languageCode) return locale;
        }
        return const Locale('en');
      },
      home: Scaffold(body: home ?? const SizedBox.expand()),
    );
  }
}
