import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [jsonContent] to a temporary file and opens the platform share sheet.
Future<void> exportChatsFile(String filename, String jsonContent) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(jsonContent, flush: true);
  await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')]);
}
