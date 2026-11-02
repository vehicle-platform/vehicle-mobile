import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error message of vehicle-server's JSON error body (`message`, `detail` or
/// `error`), falling back to a short raw-body excerpt.
String? extractHttpMessage(http.Response response) {
  if (response.body.isEmpty) return null;
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      final message = decoded['message'] ?? decoded['detail'] ?? decoded['error'];
      if (message is String && message.isNotEmpty) return message;
    }
  } catch (_) {
    // Not JSON: fall through to the raw body.
  }
  return response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body;
}
