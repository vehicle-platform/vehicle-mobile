import 'dart:async';

/// A warning the app reads out in fixed Turkish wording, never through the
/// LLM and never through `/chat` (D-085 item 4, D-121 item 7). Informational
/// only: it is not a safety output (invariant 3).
sealed class CriticalEvent {
  const CriticalEvent();
}

/// A chat answer's tool result said `advise_stop: true`.
class AdviseStopEvent extends CriticalEvent {
  const AdviseStopEvent();
}

/// A new high-severity fault or warning from a live source, announced once
/// per [id] with the server's own [title]. No live source feeds this yet.
class HighSeverityFaultEvent extends CriticalEvent {
  const HighSeverityFaultEvent({required this.id, required this.title});

  final String id;
  final String title;
}

/// Speaks fixed templates offline. [speak] is the voice output (it completes
/// when the sentence ended).
class CriticalAnnouncer {
  CriticalAnnouncer({required this.speak});

  /// Fixed sentence after an answer whose tool result advises stopping.
  static const String adviseStopSentence =
      'Güvenli bir yerde dur ve motoru kontrol ettir.';

  /// Template of a live high-severity entry; [title] is the server's own text.
  static String faultSentence(String title) =>
      'Yüksek öncelikli uyarı: $title. $adviseStopSentence';

  final Future<void> Function(String sentence) speak;
  final Set<String> _announcedFaults = {};

  /// Speaks [event]; a fault id already announced is not announced again.
  /// Returns whether something was spoken.
  Future<bool> announce(CriticalEvent event) async {
    switch (event) {
      case AdviseStopEvent():
        await speak(adviseStopSentence);
        return true;
      case HighSeverityFaultEvent(:final id, :final title):
        if (!_announcedFaults.add(id)) return false;
        await speak(faultSentence(title));
        return true;
    }
  }

  /// Forgets announced faults (a new ride or host).
  void reset() => _announcedFaults.clear();

  /// True when a tool result (object, list or nested) holds
  /// `advise_stop: true` anywhere.
  static bool resultAdvisesStop(Object? result) {
    if (result is Map) {
      if (result['advise_stop'] == true) return true;
      return result.values.any(resultAdvisesStop);
    }
    if (result is List) return result.any(resultAdvisesStop);
    return false;
  }
}
