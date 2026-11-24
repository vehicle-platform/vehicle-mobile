// Platform-specific HTTP client (D-121 item 3): `dart:io` does not exist in the
// web build, so the connect-timeout client lives behind a conditional export.
export 'package:vehicle_mobile/services/http_client_web.dart'
    if (dart.library.io) 'package:vehicle_mobile/services/http_client_io.dart';
