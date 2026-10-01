import 'package:flutter/widgets.dart';
import 'package:uhf_media/app/uhf_app.dart';

/// Wraps [child] in the real app shell (theme, localizations, overlay).
Widget harness(Widget child, {Locale locale = const Locale('en')}) => UhfApp(locale: locale, home: child);
