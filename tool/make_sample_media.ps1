# Generates sample media for manual checks (requires ffmpeg on PATH).
$ErrorActionPreference = 'Stop'
$out = Join-Path $env:TEMP 'uhf_samples'
New-Item -ItemType Directory -Force $out | Out-Null

# 2 min, 1080p, two audio tracks (440 Hz left only, 880 Hz), one subtitle track.
@"
1
00:00:01,000 --> 00:00:30,000
Internal subtitle line

"@ | Set-Content -Encoding utf8 (Join-Path $out 'internal.srt')
ffmpeg -y -v error `
  -f lavfi -i "testsrc2=size=1920x1080:rate=25:duration=120" `
  -f lavfi -i "sine=frequency=440:duration=120" `
  -f lavfi -i "sine=frequency=880:duration=120" `
  -i (Join-Path $out 'internal.srt') `
  -filter_complex "[1:a]pan=stereo|c0=c0|c1=0*c0[left]" `
  -map 0:v -map "[left]" -map 2:a -map 3:s `
  -c:v libx264 -preset veryfast -c:a aac -c:s srt `
  -metadata:s:a:0 language=fre -metadata:s:a:1 language=eng -metadata:s:s:0 language=eng `
  (Join-Path $out 'multi_track.mkv')

# 30 s interlaced (TFF) MPEG-2 in TS.
ffmpeg -y -v error -f lavfi -i "testsrc=size=720x576:rate=25:duration=30" `
  -vf "tinterlace=mode=interleave_top,setfield=tff" -c:v mpeg2video -flags +ilme+ildct -top 1 `
  (Join-Path $out 'interlaced.ts')

# External subtitle to drop on the window.
@"
1
00:00:00,000 --> 00:01:00,000
External subtitle line

"@ | Set-Content -Encoding utf8 (Join-Path $out 'multi_track.fr.srt')

Get-ChildItem $out | Select-Object Name, Length
