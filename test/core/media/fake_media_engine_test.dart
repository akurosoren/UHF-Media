import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/rotation.dart';
import 'package:uhf_media/core/media/media_engine.dart';
import 'package:uhf_media/core/media/pan_mode.dart';

import '../../support/fake_media_engine.dart';

void main() {
  test('fake engine records calls in mpv terms', () async {
    final MediaEngine engine = FakeMediaEngine();
    await engine.open(r'C:\v\a.mkv');
    await engine.selectSubtitle(null);
    await engine.selectAudio(2);
    await engine.setPan(PanMode.left);
    await engine.setRotation(Rotation.cw90);
    await engine.setSubtitleScale(140);
    expect((engine as FakeMediaEngine).calls, [
      r'open C:\v\a.mkv',
      'sid no',
      'aid 2',
      'af lavfi=[pan=stereo|c0=c0|c1=c0]',
      'video-rotate 90',
      'sub-scale 140',
    ]);
  });

  test('fake engine streams deliver emitted values', () async {
    final engine = FakeMediaEngine();
    final seen = <Duration>[];
    engine.position.listen(seen.add);
    engine.emitPosition(const Duration(seconds: 3));
    await Future<void>.delayed(Duration.zero);
    expect(seen, [const Duration(seconds: 3)]);
  });
}
