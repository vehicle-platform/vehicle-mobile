import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Client whose TCP connect gives up after [connectTimeout] (an unreachable
/// server drops the SYN silently and the OS would retry for minutes).
http.Client createHttpClient({required Duration connectTimeout}) =>
    IOClient(HttpClient()..connectionTimeout = connectTimeout);

/// True for a failure to reach the server at all (no route, refused, DNS).
bool isNetworkError(Object error) =>
    error is SocketException || error is http.ClientException;
