import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Triggers a browser download of [jsonContent] as [filename].
Future<void> exportChatsFile(String filename, String jsonContent) async {
  final blob = web.Blob(
    <JSAny>[jsonContent.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
