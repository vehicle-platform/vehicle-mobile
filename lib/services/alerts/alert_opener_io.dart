import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:vehicle_mobile/services/alerts/alert_http.dart';
import 'package:vehicle_mobile/services/http_client_factory.dart';

/// Streaming GET on `dart:io`. Cancelling the returned stream closes the
/// connection.
Future<Stream<List<int>>> openAlertStream(
    Uri url, Map<String, String> headers) async {
  final client = createHttpClient(connectTimeout: const Duration(seconds: 10));
  try {
    final request = http.Request('GET', url)..headers.addAll(headers);
    final response = await client.send(request);
    if (response.statusCode != 200) {
      client.close();
      throw AlertHttpException(response.statusCode);
    }
    late StreamSubscription<List<int>> sub;
    final out = StreamController<List<int>>(
      onCancel: () {
        sub.cancel();
        client.close();
      },
    );
    sub = response.stream.listen(
      out.add,
      onError: out.addError,
      onDone: () {
        out.close();
        client.close();
      },
    );
    return out.stream;
  } catch (_) {
    client.close();
    rethrow;
  }
}
