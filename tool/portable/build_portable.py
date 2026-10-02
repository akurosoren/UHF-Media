"""Builds build/release/UHF-Media-<version>-portable.exe: one file that unpacks the
Flutter release folder to %LOCALAPPDATA%/UHF-Media on first run and starts it.

Run `flutter build windows --release` and copy ffmpeg.exe / ffprobe.exe into the
Release folder first. Needs the MSYS2 MINGW64 toolchain (D:/Apps/msys64).
"""
import os
import re
import subprocess
import sys
import zipfile
import zlib
from pathlib import Path

root = Path(__file__).resolve().parents[2]
release = root / 'build' / 'windows' / 'x64' / 'runner' / 'Release'
out_dir = root / 'build' / 'release'
msys = Path('D:/Apps/msys64/mingw64/bin')
env = {**os.environ, 'PATH': str(msys) + os.pathsep + os.environ['PATH']}
version = re.search(r'^version:\s*([\d.]+)', (root / 'pubspec.yaml').read_text('utf-8'), re.M).group(1)

if not (release / 'uhf_media.exe').exists():
    sys.exit('Release build not found: run flutter build windows --release')
out_dir.mkdir(parents=True, exist_ok=True)

payload = out_dir / 'payload.zip'
with zipfile.ZipFile(payload, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for f in sorted(release.rglob('*')):
        if f.is_file():
            z.write(f, f.relative_to(release).as_posix())
tag = f'{version}-{zlib.crc32(payload.read_bytes()):08x}'

work = out_dir / 'launcher-build'
work.mkdir(exist_ok=True)
rc = work / 'launcher.rc'
rc.write_text(
    f'1 ICON "{(root / "windows/runner/resources/app_icon.ico").as_posix()}"\n'
    ' 1 VERSIONINFO FILEVERSION ' + ','.join((version.split('.') + ['0'] * 4)[:4]) + '\n'
    'BEGIN BLOCK "StringFileInfo" BEGIN BLOCK "040904b0" BEGIN\n'
    f' VALUE "FileDescription","UHF Media"\n VALUE "ProductName","UHF Media"\n VALUE "FileVersion","{version}"\n'
    'END END BLOCK "VarFileInfo" BEGIN VALUE "Translation",0x409,1200 END END\n',
    encoding='utf-8',
)
res = work / 'launcher_res.o'
subprocess.run([msys / 'windres.exe', rc, '-O', 'coff', '-o', res], check=True, env=env)
exe = out_dir / f'UHF-Media-{version}-portable.exe'
subprocess.run([
    msys / 'gcc.exe', '-Os', '-s', '-mwindows', '-municode', '-static',
    f'-DPAYLOAD_TAG=L"{tag}"', root / 'tool/portable/launcher.c', res, '-o', exe,
    '-lz', '-lshell32', '-lole32',
], check=True, env=env)
with open(exe, 'ab') as f:
    f.write(payload.read_bytes())
payload.unlink()
print(f'{exe} ({exe.stat().st_size / 1e6:.1f} MB), cache tag {tag}')
