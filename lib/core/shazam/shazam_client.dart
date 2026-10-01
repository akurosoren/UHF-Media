// Shazam recognition request, following shazamio (MIT License):
// shazamio/misc.py (ShazamUrl.SEARCH_FROM_FILE, Request.headers) and
// shazamio/converter.py (data_search). The endpoint is unofficial.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'signature_format.dart';

class RecognitionResult {
  const RecognitionResult({required this.title, required this.artist});
  final String title;
  final String artist;
}

class ShazamException implements Exception {
  const ShazamException(this.message);
  final String message;

  @override
  String toString() => 'ShazamException: $message';
}

class ShazamClient {
  ShazamClient({
    http.Client? client,
    math.Random? random,
    DateTime Function()? now,
    this.language = 'en-US',
    this.country = 'GB',
    this.timezone = 'Europe/Paris',
    this.timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _random = random ?? math.Random.secure(),
        _now = now ?? DateTime.now;

  final http.Client _client;
  final math.Random _random;
  final DateTime Function() _now;
  final String language;
  final String country;
  final String timezone;
  final Duration timeout;

  static const _userAgents = [
    'Dalvik/2.1.0 (Linux; U; Android 5.0.2; VS980 4G Build/LRX22G)',
    'Dalvik/1.6.0 (Linux; U; Android 4.4.2; SM-T210 Build/KOT49H)',
    'Dalvik/2.1.0 (Linux; U; Android 5.1.1; SM-P905V Build/LMY47X)',
    'Dalvik/1.6.0 (Linux; U; Android 4.4.4; Vodafone Smart Tab 4G Build/KTU84P)',
  ];

  Future<RecognitionResult?> recognize(DecodedSignature signature) async {
    final uri = Uri.parse(
      'https://amp.shazam.com/discovery/v5/$language/$country/iphone/-/tag/${_uuid()}/${_uuid()}'
      '?sync=true&webv3=true&sampling=true&connected=&shazamapiversion=v3&sharehub=true'
      '&hubv5minorversion=v5.1&hidelb=true&video=v3',
    );
    final body = jsonEncode({
      'timezone': timezone,
      'signature': {'uri': signature.toDataUri(), 'samplems': signature.sampleMs},
      'timestamp': _now().millisecondsSinceEpoch,
      'context': <String, Object?>{},
      'geolocation': <String, Object?>{},
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'X-Shazam-Platform': 'IPHONE',
              'X-Shazam-AppVersion': '14.1.0',
              'Accept': '*/*',
              'Accept-Language': language,
              'Content-Type': 'application/json',
              'User-Agent': _userAgents[_random.nextInt(_userAgents.length)],
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ShazamException('request timed out');
    } on http.ClientException catch (e) {
      throw ShazamException(e.message);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ShazamException('HTTP ${response.statusCode}');
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ShazamException('invalid JSON response');
    }
    return parseResponse(json);
  }

  static RecognitionResult? parseResponse(Object? json) {
    if (json is! Map<String, dynamic>) throw const ShazamException('unexpected response');
    final track = json['track'];
    if (track is! Map<String, dynamic>) return null;
    final title = track['title'];
    final artist = track['subtitle'];
    return RecognitionResult(
      title: title is String && title.isNotEmpty ? title : 'Unknown',
      artist: artist is String && artist.isNotEmpty ? artist : 'Unknown Artist',
    );
  }

  void close() => _client.close();

  String _uuid() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
