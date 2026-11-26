import 'package:vehicle_mobile/services/chat_export_io.dart'
    if (dart.library.js_interop) 'package:vehicle_mobile/services/chat_export_web.dart'
    as impl;

/// Function signature for exporting chat JSON; injectable for tests.
typedef ChatExporter = Future<void> Function(
    String filename, String jsonContent);

/// Downloads [jsonContent] as [filename] on web, or opens the system share
/// sheet on phone/desktop.
Future<void> exportChatsFile(String filename, String jsonContent) =>
    impl.exportChatsFile(filename, jsonContent);
