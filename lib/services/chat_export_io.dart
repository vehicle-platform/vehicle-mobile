import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [jsonContent] to a temporary file and opens the platform share
/// sheet. The file holds the rider's chats, so it is deleted again once the
/// share sheet is done, whatever the outcome.
Future<void> exportChatsFile(String filename, String jsonContent) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  try {
    await file.writeAsString(jsonContent, flush: true);
    await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')]);
  } finally {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort: the OS clears the temp directory too.
    }
  }
}
