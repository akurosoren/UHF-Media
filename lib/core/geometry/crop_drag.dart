import 'dart:math' as math;

import 'geometry.dart';

enum CropHandle { move, n, s, e, w, ne, nw, se, sw }

extension on CropHandle {
  bool get west => this == CropHandle.w || this == CropHandle.nw || this == CropHandle.sw;
  bool get east => this == CropHandle.e || this == CropHandle.ne || this == CropHandle.se;
  bool get north => this == CropHandle.n || this == CropHandle.nw || this == CropHandle.ne;
  bool get south => this == CropHandle.s || this == CropHandle.sw || this == CropHandle.se;
  bool get corner => (west || east) && (north || south);
}

/// New crop after dragging [handle] by ([dx], [dy]) pixels from [start].
/// [lockRatio] is width / height in displayed pixels (null: free).
RatioRect dragCrop(
  RatioRect start,
  CropHandle handle,
  double dx,
  double dy, {
  required double pictureWidth,
  required double pictureHeight,
  double? lockRatio,
  double minSize = 20,
}) {
  final pw = pictureWidth;
  final ph = pictureHeight;
  if (pw <= 0 || ph <= 0) return start;
  final minW = math.min(minSize, pw);
  final minH = math.min(minSize, ph);
  var l = start.left * pw;
  var t = start.top * ph;
  var r = (start.left + start.width) * pw;
  var b = (start.top + start.height) * ph;

  RatioRect result(double left, double top, double width, double height) =>
      RatioRect(left / pw, top / ph, width / pw, height / ph);

  if (handle == CropHandle.move) {
    final w = r - l;
    final h = b - t;
    return result((l + dx).clamp(0.0, pw - w), (t + dy).clamp(0.0, ph - h), w, h);
  }

  final ratio = lockRatio;
  if (ratio == null) {
    if (handle.west) l = (l + dx).clamp(0.0, r - minW);
    if (handle.east) r = (r + dx).clamp(l + minW, pw);
    if (handle.north) t = (t + dy).clamp(0.0, b - minH);
    if (handle.south) b = (b + dy).clamp(t + minH, ph);
    return result(l, t, r - l, b - t);
  }

  // Smallest width that keeps both sides at least minSize.
  final minWidth = math.max(minW, minH * ratio);

  if (handle.corner) {
    final ax = handle.west ? r : l;
    final ay = handle.north ? b : t;
    final proposedW = handle.west ? r - (l + dx) : r + dx - l;
    final proposedH = handle.north ? b - (t + dy) : b + dy - t;
    final maxW = math.min(handle.west ? ax : pw - ax, (handle.north ? ay : ph - ay) * ratio);
    final w = math.max(proposedW, proposedH * ratio).clamp(math.min(minWidth, maxW), maxW).toDouble();
    final h = w / ratio;
    return result(handle.west ? ax - w : ax, handle.north ? ay - h : ay, w, h);
  }

  if (handle.west || handle.east) {
    final ax = handle.west ? r : l;
    final cy = (t + b) / 2;
    final proposedW = handle.west ? r - (l + dx) : r + dx - l;
    final maxW = math.min(handle.west ? ax : pw - ax, 2 * math.min(cy, ph - cy) * ratio);
    final w = proposedW.clamp(math.min(minWidth, maxW), maxW).toDouble();
    final h = w / ratio;
    return result(handle.west ? ax - w : ax, cy - h / 2, w, h);
  }

  final ay = handle.north ? b : t;
  final cx = (l + r) / 2;
  final proposedH = handle.north ? b - (t + dy) : b + dy - t;
  final maxH = math.min(handle.north ? ay : ph - ay, 2 * math.min(cx, pw - cx) / ratio);
  final h = proposedH.clamp(math.min(minWidth / ratio, maxH), maxH).toDouble();
  final w = h * ratio;
  return result(cx - w / 2, handle.north ? ay - h : ay, w, h);
}
