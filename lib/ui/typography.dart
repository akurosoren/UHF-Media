import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class UhfText {
  static TextStyle sans({
    double size = 13,
    int weight = 400,
    Color color = UhfColors.text,
  }) {
    return TextStyle(
      fontFamily: UhfFonts.sans,
      fontSize: size,
      fontWeight: weight >= 500 ? FontWeight.w500 : FontWeight.w400,
      // The bundled IBM Plex Sans is a variable font: the wght axis must be
      // set explicitly, fontWeight alone does not move it on Windows.
      fontVariations: [FontVariation('wght', weight.toDouble())],
      color: color,
      height: 1.35,
    );
  }

  static TextStyle mono({
    double size = 12,
    int weight = 400,
    Color color = UhfColors.text,
  }) {
    return TextStyle(
      fontFamily: UhfFonts.mono,
      fontSize: size,
      fontWeight: weight >= 500 ? FontWeight.w500 : FontWeight.w400,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: color,
      height: 1.35,
    );
  }

  static final TextStyle body = sans();
  static final TextStyle caption = sans(size: 11, color: UhfColors.textMuted);
  static final TextStyle label = sans(weight: 500);

  static TextTheme get textTheme => TextTheme(
        bodyLarge: body,
        bodyMedium: body,
        bodySmall: caption,
        labelLarge: label,
        labelMedium: label,
        labelSmall: caption,
        titleSmall: label,
        titleMedium: sans(size: 15, weight: 500),
      );
}
