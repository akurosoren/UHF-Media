import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/crop_drag.dart';
import 'package:uhf_media/core/geometry/geometry.dart';

// Picture of 1000 x 500 px.
RatioRect drag(RatioRect r, CropHandle h, double dx, double dy, {double? ratio}) =>
    dragCrop(r, h, dx, dy, pictureWidth: 1000, pictureHeight: 500, lockRatio: ratio);

Matcher rect(double l, double t, double w, double h) => isA<RatioRect>()
    .having((r) => r.left, 'left', closeTo(l, 1e-9))
    .having((r) => r.top, 'top', closeTo(t, 1e-9))
    .having((r) => r.width, 'width', closeTo(w, 1e-9))
    .having((r) => r.height, 'height', closeTo(h, 1e-9));

void main() {
  const base = RatioRect(0.1, 0.1, 0.5, 0.5);

  test('moving keeps the size and stops at the edges', () {
    expect(drag(base, CropHandle.move, 100, 50), rect(0.2, 0.2, 0.5, 0.5));
    expect(drag(base, CropHandle.move, 5000, -5000), rect(0.5, 0.0, 0.5, 0.5));
  });

  test('a free corner moves its two edges', () {
    expect(drag(base, CropHandle.se, 100, 50), rect(0.1, 0.1, 0.6, 0.6));
    expect(drag(base, CropHandle.se, 5000, 5000), rect(0.1, 0.1, 0.9, 0.9));
  });

  test('a free edge stops at 20 px', () {
    // Right edge at 600 px: the left edge stops at 580 px.
    expect(drag(base, CropHandle.w, 1000, 0), rect(0.58, 0.1, 0.02, 0.5));
    // Bottom edge at 300 px: the top edge stops at 280 px.
    expect(drag(base, CropHandle.n, 0, 1000), rect(0.1, 0.56, 0.5, 0.04));
  });

  // 200 x 200 px square at (100, 100).
  const square = RatioRect(0.1, 0.2, 0.2, 0.4);

  test('a locked corner keeps the ratio and the opposite corner', () {
    expect(drag(square, CropHandle.se, 100, 0, ratio: 1), rect(0.1, 0.2, 0.3, 0.6));
    expect(drag(square, CropHandle.nw, -50, 0, ratio: 1), rect(0.05, 0.1, 0.25, 0.5));
  });

  test('a locked corner shrinks to stay in the picture', () {
    // Room below the top edge: 400 px, so the square stops at 400 px.
    expect(drag(square, CropHandle.se, 5000, 0, ratio: 1), rect(0.1, 0.2, 0.4, 0.8));
  });

  test('a locked side keeps the ratio around its centre', () {
    expect(drag(square, CropHandle.e, 100, 0, ratio: 1), rect(0.1, 0.1, 0.3, 0.6));
    expect(drag(square, CropHandle.s, 0, 100, ratio: 1), rect(0.05, 0.2, 0.3, 0.6));
  });

  test('a locked corner never goes under 20 px on either side', () {
    final r = drag(square, CropHandle.se, -1000, -1000, ratio: 0.5);
    expect(r.width * 1000, closeTo(20, 1e-6));
    expect(r.height * 500, closeTo(40, 1e-6));
  });
}
