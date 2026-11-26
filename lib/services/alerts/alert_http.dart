/// Opens the alert stream: completes with the body bytes once the server
/// answered 200, throws [AlertHttpException] for another status.
typedef AlertOpener = Future<Stream<List<int>>> Function(
    Uri url, Map<String, String> headers);

class AlertHttpException implements Exception {
  const AlertHttpException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'AlertHttpException($statusCode)';
}
