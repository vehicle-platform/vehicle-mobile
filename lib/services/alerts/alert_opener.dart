// Platform-specific streaming GET for the alert stream (D-129): the io build
// reads the response body incrementally; the web build uses `fetch` with a
// ReadableStream because XMLHttpRequest buffers and cannot stream, and
// EventSource cannot send the bearer header.
export 'package:vehicle_mobile/services/alerts/alert_opener_web.dart'
    if (dart.library.io) 'package:vehicle_mobile/services/alerts/alert_opener_io.dart';
