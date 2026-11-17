import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vehicle_mobile/services/ride_client.dart';
import 'package:vehicle_mobile/services/token_guard.dart';
import 'package:vehicle_mobile/services/upload_client.dart';

void main() {
  group('tokenSendRefusal', () {
    test('allows https anywhere', () {
      expect(tokenSendRefusal('https://vehicle.example.com'), isNull);
      expect(tokenSendRefusal('HTTPS://8.8.8.8'), isNull);
    });

    test('allows http only on loopback, private, link-local and .local hosts', () {
      for (final url in [
        'http://localhost:8000',
        'http://127.0.0.1:8000',
        'http://10.0.2.2:8000',
        'http://192.168.43.193:8000',
        'http://172.16.0.5',
        'http://169.254.10.1',
        'http://vehicle-laptop.local:8000',
      ]) {
        expect(tokenSendRefusal(url), isNull, reason: url);
      }
    });

    test('refuses http to public hosts, bare names and bad URLs', () {
      for (final url in [
        'http://8.8.8.8',
        'http://192.169.1.1',
        'http://172.32.0.1',
        'http://vehicle.example.com',
        'http://vehicle-laptop',
        'ftp://192.168.1.2',
        '',
        'not a url',
      ]) {
        expect(tokenSendRefusal(url), isNotNull, reason: url);
      }
      expect(tokenSendRefusal(null), isNotNull);
    });
  });

  group('clients refuse before any request', () {
    test('UploadClient never sends the token over http to a public host', () async {
      var sent = false;
      final client = UploadClient(httpClient: MockClient((request) async {
        sent = true;
        return http.Response('', 201);
      }));
      final result = await client.uploadSession(
        baseUrl: 'http://203.0.113.9:8000',
        apiToken: 'secret',
        sessionId: 's',
        archiveBytes: const [1],
      );
      expect(result.outcome, UploadOutcome.failed);
      expect(result.message, contains('plain http://'));
      expect(sent, isFalse);
    });

    test('RideClient never sends the token over http to a public host', () async {
      var sent = false;
      final client = RideClient(httpClient: MockClient((request) async {
        sent = true;
        return http.Response('{}', 200);
      }));
      final result = await client.listRides(baseUrl: 'http://203.0.113.9:8000', apiToken: 'secret');
      expect(result.outcome, RideOutcome.failed);
      expect(sent, isFalse);
    });
  });
}
