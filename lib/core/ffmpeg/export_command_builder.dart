import '../geometry/crop_math.dart';
import '../geometry/rotation.dart';
import '../util/time_format.dart';
import '../files/output_naming.dart';
import 'export_plan.dart';
import 'probe_result.dart';

class ExportCommand {
  const ExportCommand({
    required this.args,
    required this.usesHardware,
    required this.bobDeinterlace,
    required this.videoFilters,
  });

  /// ffmpeg arguments, without the executable path.
  final List<String> args;
  final bool usesHardware;
  final bool bobDeinterlace;
  final List<String> videoFilters;
}

HwEncoder? pickHwEncoder(String encodersOutput) {
  for (final encoder in HwEncoder.values) {
    if (encodersOutput.contains(encoder.ffmpegName)) return encoder;
  }
  return null;
}

abstract final class ExportCommandBuilder {
  // Subtitle codecs the Matroska muxer stores as-is (teletext and others are dropped).
  static const _matroskaSubtitleCodecs = {
    'subrip', 'srt', 'ass', 'ssa', 'webvtt', 'text', 'hdmv_pgs_subtitle', 'dvd_subtitle', 'dvb_subtitle',
  };

  static const _minTrim = Duration(milliseconds: 100);

  // LPCM flavours the Matroska muxer refuses; re-encoded losslessly.
  static const _matroskaRejectedAudio = {'pcm_bluray', 'pcm_dvd'};

  static ExportCommand build(ExportPlan plan, ProbeResult probe, {HwEncoder? hwEncoder}) {
    final doRotate = plan.rotation != Rotation.none;
    final doCrop = plan.crop != null;
    final trim = plan.trim;
    if (!doRotate && !doCrop && trim == null) {
      throw const ExportPlanException(ExportPlanError.noChanges);
    }
    if (trim != null && trim.length < _minTrim) {
      throw const ExportPlanException(ExportPlanError.trimTooShort);
    }

    final preserveInterlace = probe.isInterlaced && !doRotate;
    final bob = probe.isInterlaced && doRotate;

    final filters = <String>[];
    if (bob) filters.add('yadif=mode=send_field:parity=auto:deint=interlaced');
    if (doCrop) {
      final crop = preserveInterlace ? CropMath.adjustForInterlace(plan.crop!) : plan.crop!;
      if (crop.width < 2 || crop.height < 2) {
        throw const ExportPlanException(ExportPlanError.cropTooSmall);
      }
      filters.add('crop=${crop.width}:${crop.height}:${crop.x}:${crop.y}');
    }
    switch (plan.rotation) {
      case Rotation.cw90:
        filters.add('transpose=1');
      case Rotation.ccw90:
        filters.add('transpose=2');
      case Rotation.half:
        filters..add('hflip')..add('vflip');
      case Rotation.none:
        break;
    }

    final bitRate = probe.videoBitRate;
    final useHw = hwEncoder != null && bitRate != null && !preserveInterlace && probe.bitDepth <= 8;
    final videoFilters = [...filters, if (useHw) 'format=yuv420p'];

    final args = <String>['-y', '-hide_banner', '-nostdin', '-nostats', '-progress', 'pipe:1'];
    if (trim != null) {
      args.addAll(['-ss', formatSeconds3(trim.start), '-i', plan.inputPath, '-t', formatSeconds3(trim.length)]);
    } else {
      args.addAll(['-i', plan.inputPath]);
    }
    if (videoFilters.isNotEmpty) args.addAll(['-filter:v', videoFilters.join(',')]);

    args.addAll(['-map', plan.videoFfIndex != null ? '0:${plan.videoFfIndex}' : '0:v:0']);
    args.addAll(['-map', plan.audioFfIndex != null ? '0:${plan.audioFfIndex}' : '0:a:0?']);
    if (isMp4Family(plan.outputPath)) {
      final textSubs = probe.subtitles.where((s) => s.isText).toList();
      for (final s in textSubs) {
        args.addAll(['-map', '0:${s.index}']);
      }
      if (textSubs.isNotEmpty) args.addAll(['-c:s', 'mov_text']);
    } else {
      final kept = probe.subtitles.where((s) => _matroskaSubtitleCodecs.contains(s.codec)).toList();
      for (final s in kept) {
        args.addAll(['-map', '0:${s.index}']);
      }
      if (kept.isNotEmpty) args.addAll(['-c:s', 'copy']);
    }

    if (useHw) {
      args.addAll([
        '-c:v', hwEncoder.ffmpegName,
        '-b:v', '$bitRate', '-maxrate', '$bitRate', '-bufsize', '${bitRate * 2}',
      ]);
      if (hwEncoder == HwEncoder.nvenc) args.addAll(['-rc:v', 'vbr', '-preset', 'p4']);
    } else if (bitRate != null) {
      args.addAll([
        '-c:v', 'libx264',
        '-b:v', '$bitRate', '-minrate', '$bitRate', '-maxrate', '$bitRate',
        '-bufsize', '${bitRate * 2}', '-preset', 'medium',
      ]);
    } else {
      args.addAll(['-c:v', 'libx264', '-crf', '16', '-preset', 'slow']);
    }

    if (preserveInterlace) {
      args.addAll([
        '-flags:v', '+ildct+ilme',
        '-x264opts', probe.fieldOrder == FieldOrder.tff ? 'tff=1' : 'bff=1',
      ]);
      if (probe.frameRate != null) args.addAll(['-r', probe.frameRate!]);
      args.addAll(['-fps_mode', 'cfr']);
    }

    final audioCodec = (plan.audioFfIndex != null
            ? probe.audioStreams.where((a) => a.index == plan.audioFfIndex).firstOrNull
            : probe.audioStreams.firstOrNull)
        ?.codec;
    // With -ss before -i, a copied audio stream starts at the keyframe before
    // the cut while the video starts exactly at the cut (checked with ffmpeg
    // 8, 2026-10-01): a trim re-encodes the audio so both start together.
    final audio = !isMp4Family(plan.outputPath) && _matroskaRejectedAudio.contains(audioCodec)
        ? 'flac'
        : trim != null
            ? 'aac'
            : 'copy';
    args.addAll([
      '-pix_fmt', 'yuv420p',
      '-c:a', audio,
      if (audio == 'aac') ...['-b:a', '256k'],
      // A subtitle event that starts before the cut has a negative time; by
      // default ffmpeg would shift every stream later to compensate.
      if (trim != null) ...['-avoid_negative_ts', 'disabled'],
      '-map_metadata', '0',
      plan.outputPath,
    ]);

    return ExportCommand(
      args: List.unmodifiable(args),
      usesHardware: useHw,
      bobDeinterlace: bob,
      videoFilters: List.unmodifiable(videoFilters),
    );
  }
}
