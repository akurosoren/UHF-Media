import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData buildUhfTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: UhfColors.signal,
    onPrimary: UhfColors.ink,
    secondary: UhfColors.text,
    onSecondary: UhfColors.ink,
    error: UhfColors.signal,
    onError: UhfColors.ink,
    surface: UhfColors.surface,
    onSurface: UhfColors.text,
    onSurfaceVariant: UhfColors.textMuted,
    outline: UhfColors.line,
    outlineVariant: UhfColors.line,
    surfaceContainerHighest: UhfColors.raised,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: UhfColors.ink,
    canvasColor: UhfColors.ink,
    fontFamily: UhfFonts.sans,
    textTheme: UhfText.textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: UhfColors.text.withValues(alpha: 0.06),
    focusColor: Colors.transparent,
    visualDensity: VisualDensity.compact,
    dividerColor: UhfColors.line,
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: UhfColors.raised,
        borderRadius: BorderRadius.circular(UhfRadii.sm),
        border: Border.all(color: UhfColors.line),
      ),
      textStyle: UhfText.sans(size: 11),
    ),
  );
}
