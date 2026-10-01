import 'package:flutter/widgets.dart';

import '../features/settings/settings_controller.dart';
import 'uhf_app.dart';

class UhfRoot extends StatelessWidget {
  const UhfRoot({super.key, required this.settings, required this.home});

  final SettingsController settings;
  final Widget home;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: settings,
        builder: (context, _) => UhfApp(locale: settings.locale, home: home),
      );
}
