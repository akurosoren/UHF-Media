import 'dart:ui';

abstract final class UhfColors {
  static const ink = Color(0xFF0D0D0C);
  static const surface = Color(0xFF161614);
  static const raised = Color(0xFF1F1E1B);
  static const line = Color(0xFF2B2A27);
  static const text = Color(0xFFECE9E2);
  static const textMuted = Color(0xFF8C8981);
  static const signal = Color(0xFFE8412C);
  static const signalYellow = Color(0xFFF5D90A);
}

abstract final class UhfRadii {
  static const sm = 2.0;
  static const md = 3.0;
}

abstract final class UhfDurations {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 160);
  static const controlsHide = Duration(milliseconds: 2500);
  static const toast = Duration(seconds: 4);
  static const toastWithAction = Duration(seconds: 8);
  static const idleBlink = Duration(milliseconds: 500);
}

abstract final class UhfFonts {
  static const sans = 'IBMPlexSans';
  static const mono = 'IBMPlexMono';
}
