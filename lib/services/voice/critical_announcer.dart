import 'dart:async';

import 'package:vehicle_mobile/l10n/app_localizations.dart';

/// A warning the app reads out in fixed wording of the active language, never through the
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

/// The fixed sentences of one language. The UI passes the active locale's
/// sentences in (a provider, so a language change applies at once).
class AnnouncerSentences {
  const AnnouncerSentences({required this.adviseStop, required this.fault});

  /// English wording, the default when no provider is given.
  static const AnnouncerSentences english = AnnouncerSentences(
    adviseStop: CriticalAnnouncer.adviseStopSentence,
    fault: CriticalAnnouncer.faultSentence,
  );

  factory AnnouncerSentences.fromL10n(AppLocalizations l) => AnnouncerSentences(
        adviseStop: l.garageAnnounceAdviseStop,
        fault: l.garageAnnounceFault,
      );

  final String adviseStop;

  /// Template of a live high-severity entry; the argument is the server's text.
  final String Function(String title) fault;
}

/// Speaks fixed templates offline. [speak] is the voice output (it completes
/// when the sentence ended).
class CriticalAnnouncer {
  CriticalAnnouncer({required this.speak, this.sentences});

  /// English sentence after an answer whose tool result advises stopping.
  static const String adviseStopSentence =
      'Stop in a safe place and have the engine checked.';

  /// English template of a live high-severity entry; [title] is the server's
  /// own text.
  static String faultSentence(String title) =>
      'High-priority warning: $title. $adviseStopSentence';

  final Future<void> Function(String sentence) speak;

  /// The sentences of the active language; null = English.
  final AnnouncerSentences Function()? sentences;

  AnnouncerSentences get _s => sentences?.call() ?? AnnouncerSentences.english;
  final Set<String> _announcedFaults = {};

  /// Speaks [event]; a fault id already announced is not announced again.
  /// Returns whether something was spoken.
  Future<bool> announce(CriticalEvent event) async {
    switch (event) {
      case AdviseStopEvent():
        await speak(_s.adviseStop);
        return true;
      case HighSeverityFaultEvent(:final id, :final title):
        if (!_announcedFaults.add(id)) return false;
        await speak(_s.fault(title));
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
