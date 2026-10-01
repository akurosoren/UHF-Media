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
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(UhfColors.raised),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UhfRadii.md),
          side: const BorderSide(color: UhfColors.line),
        )),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(UhfText.body),
        foregroundColor: const WidgetStatePropertyAll(UhfColors.text),
        overlayColor: WidgetStatePropertyAll(UhfColors.text.withValues(alpha: 0.06)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 30)),
        iconColor: const WidgetStatePropertyAll(UhfColors.text),
      ),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 2,
      activeTrackColor: UhfColors.text,
      inactiveTrackColor: UhfColors.line,
      thumbColor: UhfColors.text,
      overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5, elevation: 0, pressedElevation: 0),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: UhfColors.raised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UhfRadii.md),
        side: const BorderSide(color: UhfColors.line),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: UhfColors.text,
        textStyle: UhfText.label,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UhfRadii.sm)),
      ),
    ),
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
