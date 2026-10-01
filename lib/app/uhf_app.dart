import 'package:flutter/material.dart';

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
      home: Scaffold(body: home ?? const SizedBox.expand()),
    );
  }
}
