#!/usr/bin/env bash
# Builds a minimal static ffmpeg.exe + ffprobe.exe with only what UHF Media runs:
# probe, trim/crop/rotate/deinterlace export (x264 or NVENC/QSV/AMF, AAC/FLAC,
# mp4/mov/mkv) and 10 s of audio decoded to PCM for music identification.
#
# Run inside the MSYS2 MINGW64 shell, with these packages installed:
#   pacman -S make diffutils tar xz mingw-w64-x86_64-{gcc,pkgconf,nasm,x264,
#     ffnvcodec-headers,amf-headers,libvpl,zlib}
# Usage: tool/build_ffmpeg.sh <ffmpeg-source-dir> <output-dir>
set -euo pipefail
src=${1:?ffmpeg source dir}
out=${2:?output dir}
mkdir -p "$out"
cd "$src"

./configure \
  --prefix="$out/install" \
  --target-os=mingw32 --arch=x86_64 \
  --enable-gpl --enable-static --disable-shared \
  --pkg-config-flags=--static --extra-ldflags=-static --extra-libs=-lstdc++ \
  --disable-autodetect --disable-doc --disable-debug --disable-ffplay \
  --disable-network --disable-hwaccels \
  --enable-zlib --enable-libx264 --enable-ffnvcodec --enable-nvenc --enable-amf --enable-libvpl \
  --disable-encoders \
  --enable-encoder=libx264,h264_nvenc,h264_qsv,h264_amf,aac,flac,movtext,pcm_s16le \
  --disable-muxers \
  --enable-muxer=mp4,mov,ipod,matroska,null,pcm_s16le \
  --disable-filters \
  --enable-filter=crop,transpose,hflip,vflip,yadif,format,scale,fps,setpts,trim,null \
  --enable-filter=aresample,aformat,asetpts,atrim,anull,color,buffer,buffersink,abuffer,abuffersink \
  --disable-protocols --enable-protocol=file,pipe \
  --disable-indevs --disable-outdevs --enable-indev=lavfi

make -j"$(nproc)"
mkdir -p "$out/bin"
strip -o "$out/bin/ffmpeg.exe" ffmpeg.exe
strip -o "$out/bin/ffprobe.exe" ffprobe.exe
ls -la "$out/bin"
