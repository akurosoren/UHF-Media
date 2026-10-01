import 'package:flutter/material.dart';

abstract final class UhfColors {
  static const ink = Color(0xFF09090A);
  static const base = Color(0xFF0E0E10);
  static const surface = Color(0xFF141416);
  static const raised = Color(0xFF1B1B1E);
  static const line = Color(0x1AFFFFFF);
  static const lineStrong = Color(0x2EFFFFFF);
  static const text = Color(0xFFF2EFE8);
  static const textMuted = Color(0xFF9A968D);
  static const signal = Color(0xFFFF4A2E);
  static const signalSoft = Color(0x29FF4A2E);
  static const signalYellow = Color(0xFFF5D90A);

  /// The pixel "UHF" of the start screen keeps its original red.
  static const logoRed = Color(0xFFE8412C);

  /// Smoked glass behind the floating controls, cards and toasts.
  static const glass = Color(0xA8121214);
}

abstract final class UhfRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 18.0;
  static const pill = 999.0;
}

abstract final class UhfCurves {
  static const ease = Cubic(0.22, 1, 0.36, 1);
  static const spring = Cubic(0.34, 1.56, 0.64, 1);
}

abstract final class UhfDurations {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 450);
  static const controlsHide = Duration(milliseconds: 2500);
  static const toast = Duration(seconds: 4);
  static const toastWithAction = Duration(seconds: 8);
  static const idleBlink = Duration(milliseconds: 500);
}

abstract final class UhfShadows {
  static const floating = [
    BoxShadow(color: Color(0x73000000), blurRadius: 40, offset: Offset(0, 14)),
  ];
}

abstract final class UhfFonts {
  static const sans = 'IBMPlexSans';
  static const mono = 'IBMPlexMono';
}
