import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uhf_media/core/shazam/shazam_client.dart';
import 'package:uhf_media/core/shazam/signature_format.dart';

final _signature = DecodedSignature(sampleRateHz: 16000, numberSamples: 160000, peaks: const {});

ShazamClient _client(MockClientHandler handler) => ShazamClient(
      client: MockClient(handler),
      random: Random(1),
      now: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

void main() {
  test('sends the shazamio request shape', () async {
    late http.Request sent;
    final client = _client((request) async {
      sent = request;
      return http.Response('{"matches": []}', 200);
    });

    await client.recognize(_signature);

    expect(sent.method, 'POST');
    expect(sent.url.host, 'amp.shazam.com');
    expect(
      sent.url.path,
      matches(RegExp(r'^/discovery/v5/en-US/GB/iphone/-/tag/[0-9A-F-]{36}/[0-9A-F-]{36}$')),
    );
    expect(sent.url.queryParameters['shazamapiversion'], 'v3');
    expect(sent.url.queryParameters['sync'], 'true');
    expect(sent.headers['X-Shazam-Platform'], 'IPHONE');
    expect(sent.headers['X-Shazam-AppVersion'], '14.1.0');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(sent.headers['User-Agent'], startsWith('Dalvik/'));

    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['timezone'], 'Europe/Paris');
    expect(body['timestamp'], 1700000000000);
    expect(body['signature'], {'uri': _signature.toDataUri(), 'samplems': 10000});
    expect(body['context'], <String, dynamic>{});
    expect(body['geolocation'], <String, dynamic>{});
  });

  test('a track in the response is a result', () async {
    final client = _client((_) async => http.Response(
          jsonEncode({'track': {'title': 'Gülümse', 'subtitle': 'Sezen Aksu'}}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));
    final result = await client.recognize(_signature);
    expect(result!.title, 'Gülümse');
    expect(result.artist, 'Sezen Aksu');
  });

  test('no track means not found', () async {
    final client = _client((_) async => http.Response('{"matches": []}', 200));
    expect(await client.recognize(_signature), isNull);
  });

  test('missing fields fall back to Unknown', () {
    final r = ShazamClient.parseResponse({'track': <String, dynamic>{}});
    expect(r!.title, 'Unknown');
    expect(r.artist, 'Unknown Artist');
  });

  test('HTTP errors and invalid JSON are ShazamException', () async {
    await expectLater(
      _client((_) async => http.Response('oops', 503)).recognize(_signature),
      throwsA(isA<ShazamException>()),
    );
    await expectLater(
      _client((_) async => http.Response('<html>', 200)).recognize(_signature),
      throwsA(isA<ShazamException>()),
    );
  });

  test('network failure is ShazamException', () async {
    final client = _client((_) async => throw http.ClientException('offline'));
    await expectLater(client.recognize(_signature), throwsA(isA<ShazamException>()));
  });
}
