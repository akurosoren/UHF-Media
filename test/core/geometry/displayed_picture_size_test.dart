import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/crop_math.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';

void main() {
  const source = IntSize(1920, 1080);

  test('without a reported size, the source turned by the rotation', () {
    expect(CropMath.displayedPictureSize(null, source, Rotation.cw90), const IntSize(1080, 1920));
  });

  test('a reported size with the right orientation is kept (anamorphic included)', () {
    expect(CropMath.displayedPictureSize(const IntSize(1024, 576), const IntSize(720, 576), Rotation.none),
        const IntSize(1024, 576));
  });

  test('a reported size that ignores the rotation is turned', () {
    expect(CropMath.displayedPictureSize(const IntSize(1920, 1080), source, Rotation.ccw90), const IntSize(1080, 1920));
  });
}
