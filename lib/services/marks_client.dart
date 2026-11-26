import 'package:http/http.dart' as http;

import 'package:vehicle_mobile/models/ride_mark.dart';
import 'package:vehicle_mobile/services/authed_json_client.dart';

const Duration marksConnectTimeout = Duration(seconds: 10);
const Duration marksTotalTimeout = Duration(seconds: 15);

enum MarkCallOutcome {
  ok,
  unauthorized,
  notFound,
  conflict,
  invalid,
  unreachable,
  failed,
}

class MarkCallResult<T> {
  const MarkCallResult(
    this.outcome, {
    this.data,
    this.statusCode,
    this.message,
  });

  final MarkCallOutcome outcome;
  final T? data;
  final int? statusCode;
  final String? message;

  bool get isSuccess => outcome == MarkCallOutcome.ok;
}

/// HTTP client for `POST /marks`, `GET /rides/{id}/marks`, and
/// `DELETE /marks/{id}` reusing [AuthedJsonClient].
class MarksClient {
  MarksClient({
    http.Client? httpClient,
    Duration totalTimeout = marksTotalTimeout,
  }) : _json = AuthedJsonClient(
          httpClient: httpClient,
          connectTimeout: marksConnectTimeout,
          totalTimeout: totalTimeout,
        );

  final AuthedJsonClient _json;

  Future<MarkCallResult<RideMark>> createMark({
    required String baseUrl,
    required String apiToken,
    required RideMark mark,
  }) async {
    final res = await _json.call<RideMark>(
      'POST',
      baseUrl,
      apiToken,
      '/marks',
      body: mark.toJson(),
      parse: RideMark.fromJson,
      okStatuses: const {200, 201},
    );
    return _map(res);
  }

  Future<MarkCallResult<List<RideMark>>> listRideMarks({
    required String baseUrl,
    required String apiToken,
    required String rideId,
  }) async {
    final res = await _json.call<List<RideMark>>(
      'GET',
      baseUrl,
      apiToken,
      '/rides/${Uri.encodeComponent(rideId)}/marks',
      parse: _parseMarkList,
    );
    return _map(res);
  }

  Future<MarkCallResult<void>> deleteMark({
    required String baseUrl,
    required String apiToken,
    required String markId,
  }) async {
    final res = await _json.call<void>(
      'DELETE',
      baseUrl,
      apiToken,
      '/marks/${Uri.encodeComponent(markId)}',
      okStatuses: const {204},
    );
    return _map(res);
  }

  static List<RideMark>? _parseMarkList(Object? json) {
    if (json is! Map) return null;
    final rawMarks = json['marks'];
    if (rawMarks is! List) return null;
    final out = <RideMark>[];
    for (final item in rawMarks) {
      final parsed = RideMark.fromJson(item);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  static MarkCallResult<T> _map<T>(AuthedResult<T> res) {
    if (res.ok) {
      return MarkCallResult(
        MarkCallOutcome.ok,
        data: res.value,
        statusCode: res.statusCode,
      );
    }
    if (res.unreachable) {
      return MarkCallResult(
        MarkCallOutcome.unreachable,
        message: res.message,
      );
    }
    final outcome = switch (res.statusCode) {
      401 || 403 => MarkCallOutcome.unauthorized,
      404 => MarkCallOutcome.notFound,
      409 => MarkCallOutcome.conflict,
      422 => MarkCallOutcome.invalid,
      _ => MarkCallOutcome.failed,
    };
    return MarkCallResult(
      outcome,
      statusCode: res.statusCode,
      message: res.message,
    );
  }
}
