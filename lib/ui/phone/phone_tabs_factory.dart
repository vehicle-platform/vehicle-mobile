// `dart:io`-free selection of the phone-only tabs (D-121 item 3): the web
// build gets the stub, every other build the real implementation.
export 'package:vehicle_mobile/ui/phone/phone_tabs_stub.dart'
    if (dart.library.io) 'package:vehicle_mobile/ui/phone/phone_tabs_io.dart';
