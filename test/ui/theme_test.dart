import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/ui/theme.dart';
import 'package:uhf_media/ui/tokens.dart';
import 'package:uhf_media/ui/typography.dart';

void main() {
  test('tokens hold the exact Signal palette', () {
    expect(UhfColors.ink, const Color(0xFF0D0D0C));
    expect(UhfColors.surface, const Color(0xFF161614));
    expect(UhfColors.raised, const Color(0xFF1F1E1B));
    expect(UhfColors.line, const Color(0xFF2B2A27));
    expect(UhfColors.text, const Color(0xFFECE9E2));
    expect(UhfColors.textMuted, const Color(0xFF8C8981));
    expect(UhfColors.signal, const Color(0xFFE8412C));
    expect(UhfColors.signalYellow, const Color(0xFFF5D90A));
  });

  test('theme is dark, flat and uses IBM Plex Sans', () {
    final theme = buildUhfTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, UhfColors.ink);
    expect(theme.colorScheme.primary, UhfColors.signal);
    expect(theme.colorScheme.surface, UhfColors.surface);
    expect(theme.splashFactory, NoSplash.splashFactory);
    expect(theme.textTheme.bodyMedium!.fontFamily, UhfFonts.sans);
    expect(theme.textTheme.bodyMedium!.fontSize, 13);
  });

  test('mono style uses tabular figures', () {
    final style = UhfText.mono();
    expect(style.fontFamily, UhfFonts.mono);
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  test('sans weight 500 sets both fontWeight and the wght axis', () {
    final style = UhfText.sans(weight: 500);
    expect(style.fontWeight, FontWeight.w500);
    expect(style.fontVariations, contains(const FontVariation('wght', 500)));
  });
}
