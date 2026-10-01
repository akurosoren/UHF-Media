import 'package:path/path.dart' as p;

const videoExtensions = ['mp4', 'mkv', 'mov', 'avi', 'm4v', 'webm', 'ts', 'mts', 'm2ts', 'wmv', 'flv'];
const audioExtensions = ['mp3', 'flac', 'm4a', 'wav', 'ogg', 'opus'];
const subtitleExtensions = ['srt', 'ass', 'ssa', 'vtt'];

List<String> get mediaExtensions => const [...videoExtensions, ...audioExtensions];

String _ext(String path) {
  final e = p.windows.extension(path).toLowerCase();
  return e.isEmpty ? '' : e.substring(1);
}

bool isSubtitleFile(String path) => subtitleExtensions.contains(_ext(path));

bool isMediaFile(String path) => mediaExtensions.contains(_ext(path));

String screenshotFileName(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'UHF_${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}${two(t.second)}.png';
}
