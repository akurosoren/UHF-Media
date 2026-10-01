import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/aspect_preset.dart';
import 'package:uhf_media/core/geometry/crop_math.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';

void main() {
  const fullHd = IntSize(1920, 1080);

  group('Rotation', () {
    test('mpv degrees and axis swap', () {
      expect(Rotation.none.degrees, 0);
      expect(Rotation.cw90.degrees, 90);
      expect(Rotation.ccw90.degrees, 270);
      expect(Rotation.half.degrees, 180);
      expect(Rotation.cw90.swapsAxes, isTrue);
      expect(Rotation.half.swapsAxes, isFalse);
    });
    test('next cycles 0, 90, -90, 180', () {
      expect(Rotation.none.next, Rotation.cw90);
      expect(Rotation.cw90.next, Rotation.ccw90);
      expect(Rotation.ccw90.next, Rotation.half);
      expect(Rotation.half.next, Rotation.none);
    });
  });

  test('displaySize swaps for quarter turns', () {
    expect(CropMath.displaySize(fullHd, Rotation.cw90), const IntSize(1080, 1920));
    expect(CropMath.displaySize(fullHd, Rotation.half), fullHd);
  });

  test('videoRectInViewport letterboxes', () {
    void expectRect(DRect? r, double l, double t, double w, double h) {
      expect(r, isNotNull);
      expect(r!.left, closeTo(l, 1e-9));
      expect(r.top, closeTo(t, 1e-9));
      expect(r.width, closeTo(w, 1e-9));
      expect(r.height, closeTo(h, 1e-9));
    }

    expectRect(CropMath.videoRectInViewport(fullHd, Rotation.none, 1000, 1000), 0, 218.75, 1000, 562.5);
    expectRect(CropMath.videoRectInViewport(fullHd, Rotation.cw90, 1000, 1000), 218.75, 0, 562.5, 1000);
    expect(CropMath.videoRectInViewport(fullHd, Rotation.none, 0, 500), isNull);
  });

  group('displayToSource (values from the Python implementation)', () {
    test('no rotation', () {
      expect(
        CropMath.displayToSource(const RatioRect(0.25, 0.25, 0.5, 0.5), Rotation.none, fullHd),
        const IntRect(480, 270, 960, 540),
      );
    });
    test('90 degrees clockwise', () {
      expect(
        CropMath.displayToSource(const RatioRect(0.1, 0.2, 0.5, 0.25), Rotation.cw90, fullHd),
        const IntRect(384, 432, 480, 540),
      );
    });
    test('90 degrees counter-clockwise', () {
      expect(
        CropMath.displayToSource(const RatioRect(0.1, 0.2, 0.5, 0.25), Rotation.ccw90, fullHd),
        const IntRect(1056, 108, 480, 540),
      );
    });
    test('180 degrees', () {
      expect(
        CropMath.displayToSource(const RatioRect(0.1, 0.2, 0.5, 0.25), Rotation.half, fullHd),
        const IntRect(768, 594, 960, 270),
      );
    });
    test('odd source sizes give even dimensions', () {
      expect(
        CropMath.displayToSource(const RatioRect(0, 0, 1, 1), Rotation.none, const IntSize(1919, 1079)),
        const IntRect(0, 0, 1918, 1078),
      );
    });
    test('any crop stays inside the source, even and positive (review focus 4)', () {
      final rnd = Random(42);
      for (final source in const [IntSize(1919, 1079), IntSize(1080, 1920), IntSize(721, 481)]) {
        for (final rotation in Rotation.values) {
          for (var i = 0; i < 500; i++) {
            final w = 0.02 + rnd.nextDouble() * 0.98;
            final h = 0.02 + rnd.nextDouble() * 0.98;
            final crop = RatioRect(rnd.nextDouble() * (1 - w), rnd.nextDouble() * (1 - h), w, h);
            final r = CropMath.displayToSource(crop, rotation, source);
            expect(r.x, greaterThanOrEqualTo(0), reason: '$crop $rotation');
            expect(r.y, greaterThanOrEqualTo(0), reason: '$crop $rotation');
            expect(r.width.isEven && r.height.isEven, isTrue, reason: '$crop $rotation');
            expect(r.width, greaterThan(0));
            expect(r.height, greaterThan(0));
            expect(r.x + r.width, lessThanOrEqualTo(source.width), reason: '$crop $rotation');
            expect(r.y + r.height, lessThanOrEqualTo(source.height), reason: '$crop $rotation');
          }
        }
      }
    });
  });

  test('adjustForInterlace makes y even and height a multiple of 4', () {
    expect(CropMath.adjustForInterlace(const IntRect(10, 33, 200, 102)), const IntRect(10, 32, 200, 100));
    expect(CropMath.adjustForInterlace(const IntRect(0, 0, 200, 100)), const IntRect(0, 0, 200, 100));
  });

  test('outputSize swaps for quarter turns', () {
    expect(CropMath.outputSize(const IntRect(384, 432, 480, 540), Rotation.cw90), const IntSize(540, 480));
    expect(CropMath.outputSize(const IntRect(0, 0, 960, 270), Rotation.half), const IntSize(960, 270));
  });

  group('fitPreset', () {
    test('free returns the default 70 % crop', () {
      expect(CropMath.fitPreset(AspectPreset.free, fullHd), CropMath.defaultCrop);
    });
    test('16:9 on a 16:9 picture fills the 70 % box', () {
      final r = CropMath.fitPreset(AspectPreset.r16x9, fullHd);
      expect(r.left, closeTo(0.15, 1e-9));
      expect(r.top, closeTo(0.15, 1e-9));
      expect(r.width, closeTo(0.7, 1e-9));
      expect(r.height, closeTo(0.7, 1e-9));
    });
    test('9:16 on a 16:9 picture is height-bound and centered', () {
      final r = CropMath.fitPreset(AspectPreset.r9x16, fullHd);
      expect(r.height, closeTo(0.7, 1e-9));
      expect(r.width, closeTo(425.25 / 1920, 1e-9));
      expect(r.left, closeTo((1 - 425.25 / 1920) / 2, 1e-9));
      expect(r.width * 1920 / (r.height * 1080), closeTo(9 / 16, 1e-9));
    });
    test('1:1 on a vertical picture is width-bound', () {
      final r = CropMath.fitPreset(AspectPreset.r1x1, const IntSize(1080, 1920));
      expect(r.width, closeTo(0.7, 1e-9));
      expect(r.width * 1080, closeTo(r.height * 1920, 1e-6));
    });
  });
}
