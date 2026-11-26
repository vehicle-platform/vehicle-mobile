import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:vehicle_mobile/services/alerts/alert_http.dart';

/// Streaming GET in the browser: `fetch` with the bearer header, the body read
/// chunk by chunk from its ReadableStream.
Future<Stream<List<int>>> openAlertStream(
    Uri url, Map<String, String> headers) async {
  final abort = web.AbortController();
  final response = await web.window
      .fetch(
        url.toString().toJS,
        web.RequestInit(
          method: 'GET',
          headers: headers.jsify() as web.HeadersInit,
          signal: abort.signal,
        ),
      )
      .toDart;
  if (response.status != 200) {
    abort.abort();
    throw AlertHttpException(response.status);
  }
  final reader = response.body!.getReader() as web.ReadableStreamDefaultReader;
  var cancelled = false;
  late StreamController<List<int>> out;
  Future<void> pump() async {
    try {
      while (!cancelled) {
        final chunk = await reader.read().toDart;
        if (chunk.done) break;
        final value = chunk.value;
        if (value != null) out.add((value as JSUint8Array).toDart);
      }
    } catch (e) {
      if (!cancelled) out.addError(e);
    }
    if (!out.isClosed) await out.close();
  }

  out = StreamController<List<int>>(
    onListen: () => unawaited(pump()),
    onCancel: () {
      cancelled = true;
      abort.abort();
    },
  );
  return out.stream.map((c) => Uint8List.fromList(c));
}
