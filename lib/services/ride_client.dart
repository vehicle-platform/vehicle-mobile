import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../models/bringup_result.dart';
import '../models/ride_summary.dart';
import 'http_message.dart';

/// TCP connect limit of the default client, like the upload client.
const Duration rideConnectTimeout = Duration(seconds: 10);

/// Upper bound for one read request (connect, response).
const Duration rideTotalTimeout = Duration(seconds: 30);

/// Outcome of one read-only ride request against vehicle-server.
enum RideOutcome { ok, unauthorized, notFound, invalid, unavailable, failed, unsupported }

class RideResult<T> {
  const RideResult(this.outcome, {this.data, this.statusCode, this.message});

  final RideOutcome outcome;
  final T? data;
  final int? statusCode;
  final String? message;

  bool get isSuccess => outcome == RideOutcome.ok && data != null;
}

/// Read-only client for the vehicle-server GET routes used by the app.
///
/// The [http.Client] is injectable so this is unit-testable with
/// `package:http/testing.dart`'s `MockClient`.
class RideClient {
  RideClient({http.Client? httpClient, Duration totalTimeout = rideTotalTimeout})
      : _httpClient = httpClient ?? IOClient(HttpClient()..connectionTimeout = rideConnectTimeout),
        _totalTimeout = totalTimeout;

  final http.Client _httpClient;
  final Duration _totalTimeout;

  Future<RideResult<RidesTable>> listRides({
    required String baseUrl,
    required String apiToken,
    DateTime? from,
    DateTime? to,
    List<String>? names,
  }) {
    return _get(_ridesUri(baseUrl, from, to, names), apiToken, RidesTable.fromJson);
  }

  Future<RideResult<RideSummary>> getSummary({
    required String baseUrl,
    required String apiToken,
    required String sessionId,
  }) {
    return _get(_summaryUri(baseUrl, sessionId), apiToken, RideSummary.fromJson);
  }

  Future<RideResult<Map<String, Object?>>> getReport({
    required String baseUrl,
    required String apiToken,
    required String sessionId,
  }) {
    return _get(_reportUri(baseUrl, sessionId), apiToken, _reportObject);
  }

  Future<RideResult<BringupResult>> getBringup({
    required String baseUrl,
    required String apiToken,
    required String sessionId,
    required String gate,
  }) {
    return _get(_bringupUri(baseUrl, sessionId, gate), apiToken, BringupResult.fromJson,
        notFoundMeansUnsupported: true);
  }

  Future<RideResult<T>> _get<T>(Uri uri, String apiToken, T Function(Object? json) parse,
      {bool notFoundMeansUnsupported = false}) async {
    try {
      final response = await _httpClient.get(
        uri,
        headers: {
          'Authorization': 'Bearer $apiToken',
          'Accept': 'application/json',
        },
      ).timeout(_totalTimeout);

      switch (response.statusCode) {
        case 200:
          try {
            return RideResult(
              RideOutcome.ok,
              data: parse(jsonDecode(response.body)),
              statusCode: 200,
            );
          } on FormatException catch (error) {
            return RideResult(RideOutcome.failed, statusCode: 200, message: error.message);
          }
        case 401:
          return RideResult(
            RideOutcome.unauthorized,
            statusCode: 401,
            message: extractHttpMessage(response) ?? 'unauthorized (check the API token in Settings)',
          );
        case 404:
          final detail = extractHttpMessage(response);
          if (notFoundMeansUnsupported && detail?.trim().toLowerCase() == 'not found') {
            return RideResult(
              RideOutcome.unsupported,
              statusCode: 404,
              message: 'this server has no bring-up check',
            );
          }
          return RideResult(
            RideOutcome.notFound,
            statusCode: 404,
            message: detail ?? 'not found',
          );
        case 422:
          return RideResult(
            RideOutcome.invalid,
            statusCode: 422,
            message: extractHttpMessage(response) ?? 'invalid request',
          );
        case 503:
          return RideResult(
            RideOutcome.unavailable,
            statusCode: 503,
            message: extractHttpMessage(response) ?? 'server has no API token configured',
          );
        default:
          return RideResult(
            RideOutcome.failed,
            statusCode: response.statusCode,
            message: extractHttpMessage(response) ?? 'HTTP ${response.statusCode}',
          );
      }
    } on TimeoutException {
      return RideResult(
        RideOutcome.failed,
        message: 'timed out after ${_totalTimeout.inSeconds} s (is the server reachable from this network?)',
      );
    } on SocketException catch (error) {
      return RideResult(RideOutcome.failed, message: 'network error: ${error.message}');
    } catch (error) {
      return RideResult(RideOutcome.failed, message: error.toString());
    }
  }
}

Uri _ridesUri(String baseUrl, DateTime? from, DateTime? to, List<String>? names) {
  final query = <String, String>{};
  if (from != null) query['from'] = formatQueryDate(from);
  if (to != null) query['to'] = formatQueryDate(to);
  if (names != null && names.isNotEmpty) query['names'] = names.join(',');
  final uri = Uri.parse('${_withoutTrailingSlash(baseUrl)}/rides');
  return query.isEmpty ? uri : uri.replace(queryParameters: query);
}

Uri _summaryUri(String baseUrl, String sessionId) {
  final base = _withoutTrailingSlash(baseUrl);
  return Uri.parse('$base/sessions/${Uri.encodeComponent(sessionId)}/summary');
}

Uri _reportUri(String baseUrl, String sessionId) {
  final base = _withoutTrailingSlash(baseUrl);
  return Uri.parse('$base/sessions/${Uri.encodeComponent(sessionId)}/report');
}

Uri _bringupUri(String baseUrl, String sessionId, String gate) {
  final base = _withoutTrailingSlash(baseUrl);
  return Uri.parse('$base/sessions/${Uri.encodeComponent(sessionId)}/bringup')
      .replace(queryParameters: {'gate': gate});
}

/// `YYYY-MM-DD` of the calendar date as picked; vehicle-server reads it as
/// that whole UTC day (`/rides` `from`/`to`, inclusive).
String formatQueryDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _withoutTrailingSlash(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;

Map<String, Object?> _reportObject(Object? json) {
  if (json is! Map) throw const FormatException('report is not an object');
  final result = <String, Object?>{};
  for (final entry in json.entries) {
    if (entry.key is! String) throw const FormatException('report has a non-string key');
    result[entry.key as String] = entry.value;
  }
  return result;
}
