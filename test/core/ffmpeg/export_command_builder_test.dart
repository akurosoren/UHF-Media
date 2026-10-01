import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/ffmpeg/export_command_builder.dart';
import 'package:uhf_media/core/ffmpeg/export_plan.dart';
import 'package:uhf_media/core/ffmpeg/probe_result.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';

ProbeResult _probe({
  int? bitRate = 8000000,
  FieldOrder fieldOrder = FieldOrder.progressive,
  String? frameRate = '25/1',
  int bitDepth = 8,
  List<SubtitleStreamInfo> subtitles = const [],
}) =>
    ProbeResult(
      videoBitRate: bitRate,
      fieldOrder: fieldOrder,
      frameRate: frameRate,
      bitDepth: bitDepth,
      duration: const Duration(minutes: 10),
      subtitles: subtitles,
    );

const _head = ['-y', '-hide_banner', '-nostdin', '-nostats', '-progress', 'pipe:1'];

void main() {
  group('validation', () {
    test('nothing selected', () {
      expect(
        () => ExportCommandBuilder.build(
          const ExportPlan(inputPath: 'in.mp4', outputPath: 'out.mp4'),
          _probe(),
        ),
        throwsA(isA<ExportPlanException>().having((e) => e.error, 'error', ExportPlanError.noChanges)),
      );
    });
    test('trim shorter than 0.1 s', () {
      expect(
        () => ExportCommandBuilder.build(
          const ExportPlan(
            inputPath: 'in.mp4',
            outputPath: 'out.mp4',
            trim: TrimRange(Duration(seconds: 5), Duration(seconds: 5, milliseconds: 50)),
          ),
          _probe(),
        ),
        throwsA(isA<ExportPlanException>().having((e) => e.error, 'error', ExportPlanError.trimTooShort)),
      );
    });
    test('crop smaller than 2 px after interlace adjustment', () {
      expect(
        () => ExportCommandBuilder.build(
          const ExportPlan(inputPath: 'in.mkv', outputPath: 'out.mkv', crop: IntRect(0, 1, 100, 2)),
          _probe(fieldOrder: FieldOrder.tff),
        ),
        throwsA(isA<ExportPlanException>().having((e) => e.error, 'error', ExportPlanError.cropTooSmall)),
      );
    });
  });

  test('GPU, crop + rotate, known bit rate, mkv', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(
        inputPath: r'C:\v\in.mkv',
        outputPath: r'C:\v\in_crop_rot90.mkv',
        rotation: Rotation.cw90,
        crop: IntRect(384, 432, 480, 540),
        videoFfIndex: 0,
        audioFfIndex: 2,
      ),
      _probe(),
      hwEncoder: HwEncoder.nvenc,
    );
    expect(cmd.usesHardware, isTrue);
    expect(cmd.args, [
      ..._head,
      '-i', r'C:\v\in.mkv',
      '-filter:v', 'crop=480:540:384:432,transpose=1,format=yuv420p',
      '-map', '0:0', '-map', '0:2',
      '-c:v', 'h264_nvenc', '-b:v', '8000000', '-maxrate', '8000000', '-bufsize', '16000000',
      '-rc:v', 'vbr', '-preset', 'p4',
      '-pix_fmt', 'yuv420p', '-c:a', 'copy', '-map_metadata', '0',
      r'C:\v\in_crop_rot90.mkv',
    ]);
  });

  test('CPU with bit rate, 180 degrees, trim with a single input seek', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(
        inputPath: 'in.mkv',
        outputPath: 'out.mkv',
        rotation: Rotation.half,
        trim: TrimRange(Duration(minutes: 1, seconds: 2, milliseconds: 345), Duration(minutes: 2)),
      ),
      _probe(),
    );
    expect(cmd.usesHardware, isFalse);
    expect(cmd.args, [
      ..._head,
      '-ss', '62.345', '-i', 'in.mkv', '-t', '57.655',
      '-filter:v', 'hflip,vflip',
      '-map', '0:v:0', '-map', '0:a:0?',
      '-c:v', 'libx264', '-b:v', '8000000', '-minrate', '8000000', '-maxrate', '8000000',
      '-bufsize', '16000000', '-preset', 'medium',
      '-pix_fmt', 'yuv420p', '-c:a', 'copy', '-map_metadata', '0',
      'out.mkv',
    ]);
  });

  test('unknown bit rate falls back to CRF and never uses the GPU', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: 'in.mkv', outputPath: 'out.mkv', rotation: Rotation.ccw90),
      _probe(bitRate: null),
      hwEncoder: HwEncoder.qsv,
    );
    expect(cmd.usesHardware, isFalse);
    expect(cmd.args, containsAllInOrder(['-filter:v', 'transpose=2', '-c:v', 'libx264', '-crf', '16', '-preset', 'slow']));
  });

  test('10-bit source never uses the GPU', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: 'in.mkv', outputPath: 'out.mkv', rotation: Rotation.cw90),
      _probe(bitDepth: 10),
      hwEncoder: HwEncoder.amf,
    );
    expect(cmd.usesHardware, isFalse);
    expect(cmd.args, isNot(contains('format=yuv420p')));
  });

  test('interlaced without rotation keeps fields on the CPU', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: 'in.ts', outputPath: 'out.mkv', crop: IntRect(10, 33, 640, 362)),
      _probe(fieldOrder: FieldOrder.bff, frameRate: '30000/1001'),
      hwEncoder: HwEncoder.nvenc,
    );
    expect(cmd.usesHardware, isFalse);
    expect(cmd.bobDeinterlace, isFalse);
    expect(cmd.videoFilters, ['crop=640:360:10:32']);
    expect(
      cmd.args,
      containsAllInOrder([
        '-flags:v', '+ildct+ilme', '-x264opts', 'bff=1', '-r', '30000/1001', '-fps_mode', 'cfr',
        '-pix_fmt', 'yuv420p',
      ]),
    );
  });

  test('interlaced with rotation bob-deinterlaces first and may use the GPU', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: 'in.ts', outputPath: 'out.mkv', rotation: Rotation.cw90),
      _probe(fieldOrder: FieldOrder.tff),
      hwEncoder: HwEncoder.nvenc,
    );
    expect(cmd.bobDeinterlace, isTrue);
    expect(cmd.usesHardware, isTrue);
    expect(cmd.videoFilters.first, 'yadif=mode=send_field:parity=auto:deint=interlaced');
    expect(cmd.args, isNot(contains('-x264opts')));
  });

  test('mp4 family output converts text subtitles and drops image ones', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: 'in.mov', outputPath: 'out_rot90.mov', rotation: Rotation.cw90),
      _probe(subtitles: const [
        SubtitleStreamInfo(index: 2, codec: 'subrip', isText: true),
        SubtitleStreamInfo(index: 3, codec: 'hdmv_pgs_subtitle', isText: false),
      ]),
    );
    expect(cmd.args, containsAllInOrder(['-map', '0:2', '-c:s', 'mov_text']));
    expect(cmd.args, isNot(contains('0:3')));
    expect(cmd.args, isNot(contains('0:s?')));
  });

  test('mp4 output without text subtitles maps none', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: 'in.mp4', outputPath: 'out.mp4', rotation: Rotation.cw90),
      _probe(),
    );
    expect(cmd.args, isNot(contains('-c:s')));
  });

  test('paths with spaces and Turkish characters stay single arguments (review focus 1)', () {
    const input = r'C:\Vidéos\şarkı test (1).mkv';
    const output = r'C:\Vidéos\şarkı test (1)_rot90.mkv';
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: input, outputPath: output, rotation: Rotation.cw90),
      _probe(),
    );
    expect(cmd.args[cmd.args.indexOf('-i') + 1], input);
    expect(cmd.args.last, output);
    expect(cmd.args.where((a) => a.contains('"')), isEmpty);
  });

  test('missing ff-index falls back to first video and optional first audio (review focus 2)', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: 'in.mkv', outputPath: 'out.mkv', rotation: Rotation.cw90, audioFfIndex: null),
      _probe(),
    );
    expect(cmd.args, containsAllInOrder(['-map', '0:v:0', '-map', '0:a:0?']));
  });

  group('pickHwEncoder', () {
    test('prefers NVENC, then QSV, then AMF', () {
      expect(pickHwEncoder(' V....D h264_amf  AMD\n V....D h264_qsv  Intel\n V....D h264_nvenc NVIDIA'), HwEncoder.nvenc);
      expect(pickHwEncoder(' V....D h264_amf  AMD\n V....D h264_qsv  Intel'), HwEncoder.qsv);
      expect(pickHwEncoder(' V....D h264_amf  AMD'), HwEncoder.amf);
      expect(pickHwEncoder(' V....D libx264  x264'), isNull);
    });
  });

  test('mkv output copies only subtitle codecs Matroska accepts', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: 'in.ts', outputPath: 'out_rot90.mkv', rotation: Rotation.cw90),
      _probe(subtitles: const [
        SubtitleStreamInfo(index: 2, codec: 'subrip', isText: true),
        SubtitleStreamInfo(index: 3, codec: 'dvb_teletext', isText: false),
        SubtitleStreamInfo(index: 4, codec: 'hdmv_pgs_subtitle', isText: false),
      ]),
    );
    expect(cmd.args, containsAllInOrder(['-map', '0:2', '-map', '0:4', '-c:s', 'copy']));
    expect(cmd.args, isNot(contains('0:3')));
    expect(cmd.args, isNot(contains('0:s?')));
  });
}
