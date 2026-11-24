import 'package:http/http.dart' as http;

/// Browser build: the browser owns connect timeouts; callers still apply
/// their own total timeout.
http.Client createHttpClient({required Duration connectTimeout}) =>
    http.Client();

/// True for a failure to reach the server at all (no route, refused, CORS).
bool isNetworkError(Object error) => error is http.ClientException;
