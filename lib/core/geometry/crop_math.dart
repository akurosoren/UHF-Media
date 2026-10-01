import 'dart:math' as math;

import 'aspect_preset.dart';
import 'geometry.dart';
import 'rotation.dart';

abstract final class CropMath {
  static const RatioRect defaultCrop = RatioRect(0.15, 0.15, 0.7, 0.7);

  static IntSize displaySize(IntSize source, Rotation r) =>
      r.swapsAxes ? IntSize(source.height, source.width) : source;

  /// Size of the picture as drawn by the video widget. [reported] is what
  /// the engine says (aspect-corrected display size); depending on the mpv
  /// build it may or may not include the user rotation, so it is turned when
  /// its orientation contradicts [r]. Falls back to the coded size.
  static IntSize displayedPictureSize(IntSize? reported, IntSize source, Rotation r) {
    final expected = displaySize(source, r);
    if (reported == null || reported.width <= 0 || reported.height <= 0) return expected;
    final reportedLandscape = reported.width > reported.height;
    final expectedLandscape = expected.width > expected.height;
    if (reported.width == reported.height || reportedLandscape == expectedLandscape) return reported;
    return IntSize(reported.height, reported.width);
  }

  /// Where the picture is drawn inside a viewport (letterboxed, centered).
  static DRect? videoRectInViewport(IntSize source, Rotation r, double viewportWidth, double viewportHeight) {
    final display = displaySize(source, r);
    if (viewportWidth <= 0 || viewportHeight <= 0 || display.width <= 0 || display.height <= 0) {
      return null;
    }
    final scale = math.min(viewportWidth / display.width, viewportHeight / display.height);
    final w = display.width * scale;
    final h = display.height * scale;
    return DRect((viewportWidth - w) / 2, (viewportHeight - h) / 2, w, h);
  }

  /// Maps a crop drawn on the rotated picture back to unrotated source
  /// pixels, where ffmpeg's crop filter runs (before transpose).
  static IntRect displayToSource(RatioRect crop, Rotation r, IntSize source) {
    final display = displaySize(source, r);
    final rx = crop.left * display.width;
    final ry = crop.top * display.height;
    final rw = crop.width * display.width;
    final rh = crop.height * display.height;
    final w0 = source.width;
    final h0 = source.height;

    final (double x, double y, double w, double h) = switch (r) {
      Rotation.none => (rx, ry, rw, rh),
      Rotation.cw90 => (ry, h0 - rx - rw, rh, rw),
      Rotation.ccw90 => (w0 - ry - rh, rx, rh, rw),
      Rotation.half => (w0 - rx - rw, h0 - ry - rh, rw, rh),
    };

    var ix = math.max(0, x.toInt());
    var iy = math.max(0, y.toInt());
    var iw = math.min(w.toInt(), w0);
    var ih = math.min(h.toInt(), h0);
    iw -= iw % 2;
    ih -= ih % 2;
    iw = math.max(2, iw);
    ih = math.max(2, ih);
    if (ix + iw > w0) ix -= ix + iw - w0;
    if (iy + ih > h0) iy -= iy + ih - h0;
    return IntRect(math.max(0, ix), math.max(0, iy), iw, ih);
  }

  /// x264 interlaced encoding needs an even top edge (keeps field parity)
  /// and a height divisible by 4.
  static IntRect adjustForInterlace(IntRect r) {
    final y = r.y.isOdd ? r.y - 1 : r.y;
    return IntRect(r.x, y, r.width, r.height - r.height % 4);
  }

  static IntSize outputSize(IntRect sourceCrop, Rotation r) => r.swapsAxes
      ? IntSize(sourceCrop.height, sourceCrop.width)
      : IntSize(sourceCrop.width, sourceCrop.height);

  /// Largest rectangle of the preset's ratio that fits in 70 % of the
  /// displayed picture, centered.
  static RatioRect fitPreset(AspectPreset preset, IntSize display) {
    final ratio = preset.ratio;
    if (ratio == null || display.width <= 0 || display.height <= 0) return defaultCrop;
    final boxW = display.width * 0.7;
    final boxH = display.height * 0.7;
    double w;
    double h;
    if (boxW / boxH > ratio) {
      h = boxH;
      w = h * ratio;
    } else {
      w = boxW;
      h = w / ratio;
    }
    final rw = w / display.width;
    final rh = h / display.height;
    return RatioRect((1 - rw) / 2, (1 - rh) / 2, rw, rh);
  }
}
