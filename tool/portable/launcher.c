// Single-file launcher for UHF Media: the app (a zip of the Flutter release
// folder) is appended to this exe. On first run it is extracted to
// %LOCALAPPDATA%\UHF-Media\<tag>, later runs start straight from there.
// Build with tool/portable/build_portable.py.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <zlib.h>

#ifndef PAYLOAD_TAG
#define PAYLOAD_TAG L"dev"
#endif

static void fail(const wchar_t *msg) {
  wchar_t log[MAX_PATH];
  if (GetEnvironmentVariableW(L"LOCALAPPDATA", log, MAX_PATH)) {
    wcscat(log, L"\\UHF-Media\\launcher-error.log");
    HANDLE f = CreateFileW(log, FILE_APPEND_DATA, FILE_SHARE_READ, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (f != INVALID_HANDLE_VALUE) {
      DWORD w;
      WriteFile(f, msg, (DWORD)(wcslen(msg) * sizeof(wchar_t)), &w, NULL);
      CloseHandle(f);
    }
  }
  MessageBoxW(NULL, msg, L"UHF Media", MB_OK | MB_ICONERROR);
  ExitProcess(1);
}

static uint16_t rd16(const uint8_t *p) { return p[0] | (p[1] << 8); }
static uint32_t rd32(const uint8_t *p) { return p[0] | (p[1] << 8) | (p[2] << 16) | ((uint32_t)p[3] << 24); }

static void make_dirs(wchar_t *path) {
  for (wchar_t *p = path + 3; *p; p++) {
    if (*p == L'\\') {
      *p = 0;
      CreateDirectoryW(path, NULL);
      *p = L'\\';
    }
  }
}

static int extract_all(HANDLE exe, int64_t size, const wchar_t *dest) {
  // Find the end-of-central-directory record in the last 64 KB.
  DWORD tail = size < 65557 ? (DWORD)size : 65557;
  uint8_t *buf = malloc(tail);
  LARGE_INTEGER pos;
  DWORD got;
  pos.QuadPart = size - tail;
  SetFilePointerEx(exe, pos, NULL, FILE_BEGIN);
  if (!ReadFile(exe, buf, tail, &got, NULL) || got != tail) return 0;
  int eocd = -1;
  for (int i = (int)tail - 22; i >= 0; i--) {
    if (rd32(buf + i) == 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) return 0;
  uint32_t cd_size = rd32(buf + eocd + 12), cd_off = rd32(buf + eocd + 16);
  uint16_t count = rd16(buf + eocd + 10);
  int64_t eocd_abs = size - tail + eocd;
  int64_t zip_start = eocd_abs - cd_size - cd_off;
  free(buf);

  uint8_t *cd = malloc(cd_size);
  pos.QuadPart = zip_start + cd_off;
  SetFilePointerEx(exe, pos, NULL, FILE_BEGIN);
  if (!ReadFile(exe, cd, cd_size, &got, NULL) || got != cd_size) return 0;

  uint8_t *p = cd;
  for (int n = 0; n < count; n++) {
    if (rd32(p) != 0x02014b50) return 0;
    uint16_t method = rd16(p + 10), name_len = rd16(p + 28), extra_len = rd16(p + 30), comment_len = rd16(p + 32);
    uint32_t csize = rd32(p + 20), usize = rd32(p + 24), lho = rd32(p + 42);
    char name[1024];
    if (name_len >= sizeof name) return 0;
    memcpy(name, p + 46, name_len);
    name[name_len] = 0;
    p += 46 + name_len + extra_len + comment_len;
    if (name_len && name[name_len - 1] == '/') continue;

    uint8_t lh[30];
    pos.QuadPart = zip_start + lho;
    SetFilePointerEx(exe, pos, NULL, FILE_BEGIN);
    if (!ReadFile(exe, lh, 30, &got, NULL) || got != 30 || rd32(lh) != 0x04034b50) return 0;
    int64_t data = zip_start + lho + 30 + rd16(lh + 26) + rd16(lh + 28);
    uint8_t *in = malloc(csize ? csize : 1), *out = malloc(usize ? usize : 1);
    pos.QuadPart = data;
    SetFilePointerEx(exe, pos, NULL, FILE_BEGIN);
    if (csize && (!ReadFile(exe, in, csize, &got, NULL) || got != csize)) return 0;
    if (method == 0) {
      memcpy(out, in, usize);
    } else {
      z_stream z = {0};
      z.next_in = in; z.avail_in = csize; z.next_out = out; z.avail_out = usize;
      if (inflateInit2(&z, -15) != Z_OK) return 0;
      int r = inflate(&z, Z_FINISH);
      inflateEnd(&z);
      if (r != Z_STREAM_END) return 0;
    }
    free(in);

    wchar_t rel[1024];
    if (!MultiByteToWideChar(CP_UTF8, 0, name, -1, rel, 1024)) return 0;
    for (wchar_t *c = rel; *c; c++) if (*c == L'/') *c = L'\\';
    wchar_t full[MAX_PATH * 2];
    swprintf(full, MAX_PATH * 2, L"%ls\\%ls", dest, rel);
    make_dirs(full);
    HANDLE f = CreateFileW(full, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (f == INVALID_HANDLE_VALUE) return 0;
    DWORD w;
    BOOL ok = usize == 0 || WriteFile(f, out, usize, &w, NULL);
    CloseHandle(f);
    free(out);
    if (!ok) return 0;
  }
  free(cd);
  return 1;
}

static void remove_tree(const wchar_t *dir) {
  wchar_t from[MAX_PATH + 2];
  swprintf(from, MAX_PATH + 2, L"%ls", dir);
  from[wcslen(from) + 1] = 0;
  SHFILEOPSTRUCTW op = {0};
  op.wFunc = FO_DELETE;
  op.pFrom = from;
  op.fFlags = FOF_NO_UI;
  SHFileOperationW(&op);
}

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE prev, PWSTR cmd, int show) {
  wchar_t self[MAX_PATH];
  GetModuleFileNameW(NULL, self, MAX_PATH);

  wchar_t base[MAX_PATH];
  if (!GetEnvironmentVariableW(L"LOCALAPPDATA", base, MAX_PATH)) fail(L"LOCALAPPDATA is not set.");
  wchar_t dest[MAX_PATH], app[MAX_PATH], ready[MAX_PATH];
  swprintf(dest, MAX_PATH, L"%ls\\UHF-Media\\%ls", base, PAYLOAD_TAG);
  swprintf(app, MAX_PATH, L"%ls\\uhf_media.exe", dest);
  swprintf(ready, MAX_PATH, L"%ls\\.ready", dest);

  if (GetFileAttributesW(ready) == INVALID_FILE_ATTRIBUTES) {
    HANDLE mutex = CreateMutexW(NULL, FALSE, L"Local\\UHFMediaExtract");
    WaitForSingleObject(mutex, 120000);
    if (GetFileAttributesW(ready) == INVALID_FILE_ATTRIBUTES) {
      HANDLE exe = CreateFileW(self, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
      LARGE_INTEGER size;
      if (exe == INVALID_HANDLE_VALUE || !GetFileSizeEx(exe, &size)) fail(L"Cannot read the program file.");
      remove_tree(dest);
      make_dirs(dest);
      CreateDirectoryW(dest, NULL);
      if (!extract_all(exe, size.QuadPart, dest)) fail(L"Cannot unpack UHF Media (disk full or access denied?).");
      CloseHandle(exe);
      // Written last: a half-extracted folder is redone on the next start.
      HANDLE marker = CreateFileW(ready, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
      if (marker != INVALID_HANDLE_VALUE) CloseHandle(marker);
    }
    ReleaseMutex(mutex);
    CloseHandle(mutex);
  }

  wchar_t cmdline[32768];
  swprintf(cmdline, 32768, L"\"%ls\" %ls", app, cmd);
  STARTUPINFOW si = {sizeof si};
  PROCESS_INFORMATION pi;
  if (!CreateProcessW(app, cmdline, NULL, NULL, FALSE, 0, NULL, dest, &si, &pi)) fail(L"Cannot start UHF Media.");
  CloseHandle(pi.hThread);
  CloseHandle(pi.hProcess);
  return 0;
}
