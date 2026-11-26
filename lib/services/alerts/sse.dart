import 'dart:async';
import 'dart:convert';

/// One Server-Sent Event: its `event` name (default `message`) and `data`.
class SseEvent {
  const SseEvent(this.event, this.data);

  final String event;
  final String data;
}

/// Splits a byte stream of `text/event-stream` into events. Comment lines
/// (`: heartbeat`) are dropped; an event ends at a blank line; `data` lines
/// are joined with newlines. Handles `\n`, `\r\n` and chunk boundaries inside
/// a line or a UTF-8 sequence.
Stream<SseEvent> parseSse(Stream<List<int>> bytes) async* {
  var event = 'message';
  final data = <String>[];
  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) yield SseEvent(event, data.join('\n'));
      event = 'message';
      data.clear();
    } else if (line.startsWith(':')) {
      continue;
    } else {
      final cut = line.indexOf(':');
      final field = cut < 0 ? line : line.substring(0, cut);
      var value = cut < 0 ? '' : line.substring(cut + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      if (field == 'event') {
        event = value;
      } else if (field == 'data') {
        data.add(value);
      }
    }
  }
}
